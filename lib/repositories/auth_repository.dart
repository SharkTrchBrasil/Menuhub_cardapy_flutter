import 'dart:async';

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../controllers/customer_controller.dart';
import '../core/di.dart';
import '../core/session/in_memory_session_store.dart';
import '../core/utils/app_logger.dart';
import '../models/customer.dart';
import '../models/totem_auth.dart';

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  Dio? _refreshDio;

  static Completer<String?>? _customerRefreshCompleter;
  static Completer<String?>? _menuRefreshCompleter;

  AuthRepository(this._dio, this._secureStorage);

  // ✅ STATELESS: Sessão de loja em memória (não persiste em storage)
  final InMemorySessionStore _session = InMemorySessionStore.instance;

  // Chaves de armazenamento - TOKENS DE CUSTOMER (persistem em storage para login Google)
  static const String _keyCustomerAccessToken = 'customer_access_token';
  static const String _keyCustomerRefreshToken = 'customer_refresh_token';
  static const String _keyCustomerTokenExpiration = 'customer_token_expiration';

  /// ✅ Inicializa Dio separado para refresh (sem interceptor)
  Dio _getRefreshDio() {
    if (_refreshDio != null) return _refreshDio!;

    // Usa a mesma base URL mas sem interceptores de autenticação
    final apiUrl = _dio.options.baseUrl.replaceAll('/app', '');
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: '$apiUrl/app',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return _refreshDio!;
  }

  /// ✅ PERF: Inicializa sessão a partir de dados pre-fetched do index.html JS.
  /// Evita chamada duplicada ao /auth/subdomain (~1000ms economizados).
  TotemAuth initFromPreFetchedData(Map<String, dynamic> json) {
    final totemAuth = TotemAuth.fromJson(json);
    _session.setStoreSession(
      accessToken: totemAuth.accessToken,
      refreshToken: totemAuth.refreshToken,
      expiresIn: totemAuth.expiresIn,
      storeUrl: totemAuth.storeUrl,
      storeName: totemAuth.storeName,
      storeId: totemAuth.storeId,
      connectionToken: totemAuth.connectionToken,
    );
    return totemAuth;
  }

  /// ✅ STATELESS: Autentica na loja via subdomínio (URL é o único requisito)
  /// NÃO depende de localStorage, sessionStorage ou cookies.
  /// Tokens são armazenados APENAS em memória (InMemorySessionStore).
  /// Retry automático para lidar com cold start do backend (Redis/DB race condition)
  Future<Either<String, TotemAuth>> getToken(String storeSlug) async {
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        AppLogger.i(
          '🔐 Autenticando com store_url: $storeSlug (tentativa ${attempt + 1}/$maxRetries)',
          tag: 'AUTH',
        );

        // ✅ STATELESS: Envia APENAS store_url. Backend gera totem_token server-side.
        // Não lê nem depende de nenhum token salvo no navegador.
        final response = await _dio.post(
          '/auth/subdomain',
          data: {'store_url': storeSlug},
        );

        final TotemAuth totemAuth = TotemAuth.fromJson(response.data);

        // ✅ STATELESS: Salva tokens APENAS em memória (variáveis Dart)
        _session.setStoreSession(
          accessToken: totemAuth.accessToken,
          refreshToken: totemAuth.refreshToken,
          expiresIn: totemAuth.expiresIn,
          storeUrl: totemAuth.storeUrl,
          storeName: totemAuth.storeName,
          storeId: totemAuth.storeId,
          connectionToken: totemAuth.connectionToken,
        );

        AppLogger.i(
          '✅ Autenticação bem-sucedida para loja: ${totemAuth.storeName} (sessão em memória)',
          tag: 'AUTH',
        );
        return Right(totemAuth);
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;

        // ✅ RETRY: 404 e 503 são retryable (cold start do backend — Redis/DB race condition)
        if ((statusCode == 404 || statusCode == 503) &&
            attempt < maxRetries - 1) {
          final delay = baseDelay * (attempt + 1);
          AppLogger.w(
            '⚠️ Auth falhou ($statusCode), retry em ${delay.inSeconds}s... '
            '(tentativa ${attempt + 1}/$maxRetries)',
            tag: 'AUTH',
          );
          await Future.delayed(delay);
          continue;
        }

        AppLogger.e(
          '❌ Erro ao buscar token: ${e.response?.data ?? e.message}',
          tag: 'AUTH',
        );
        return Left(e.response?.data?['detail'] ?? 'Erro ao autenticar');
      } catch (e) {
        AppLogger.e('❌ Erro inesperado: $e', tag: 'AUTH');
        return Left('Erro inesperado ao autenticar');
      }
    }

    return const Left('Erro ao autenticar após múltiplas tentativas');
  }

  /// Handles Google Sign-In process
  Future<User?> signInWithGoogle() async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithPopup(GoogleAuthProvider());
      return userCredential.user;
    } catch (e) {
      AppLogger.e('❌ Error signing in with Google: $e', tag: 'AUTH');
      return null;
    }
  }

  /// ✅ STATELESS: Obtém token de acesso válido da MEMÓRIA (renova se necessário)
  Future<String?> getValidAccessToken() async {
    // Lê diretamente da memória — NUNCA do localStorage
    if (_session.hasValidStoreToken) {
      return _session.accessToken;
    }

    // Token expirado ou ausente — tenta refresh
    if (_session.refreshToken == null) {
      return null;
    }

    // Token expirando — serializa o refresh com mutex
    if (_menuRefreshCompleter != null) {
      return _menuRefreshCompleter!.future;
    }

    _menuRefreshCompleter = Completer<String?>();
    try {
      final token = await _refreshAccessToken();
      _menuRefreshCompleter!.complete(token);
      return token;
    } catch (e) {
      _menuRefreshCompleter!.complete(null);
      rethrow;
    } finally {
      _menuRefreshCompleter = null;
    }
  }

  /// ✅ Obtém token de acesso válido do CUSTOMER (renova se necessário)
  /// Tenta memória primeiro, depois fallback para storage (para persistir login Google)
  Future<String?> getValidCustomerAccessToken() async {
    // 1. Tenta da memória primeiro (sessão atual)
    if (_session.hasValidCustomerToken) {
      return _session.customerAccessToken;
    }

    // 2. Fallback: tenta do storage (login Google persistido)
    final accessToken = await _secureStorage.read(key: _keyCustomerAccessToken);
    final expirationStr = await _secureStorage.read(
      key: _keyCustomerTokenExpiration,
    );

    if (accessToken != null && expirationStr != null) {
      final expiration = DateTime.tryParse(expirationStr);
      if (expiration != null &&
          expiration.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        // Carrega do storage para memória para próximas chamadas
        final refreshToken = await _secureStorage.read(
          key: _keyCustomerRefreshToken,
        );
        _session.setCustomerSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresIn: expiration.difference(DateTime.now()).inSeconds,
        );
        return accessToken;
      }
    }

    // 3. Token expirado — tenta refresh
    final refreshToken =
        _session.customerRefreshToken ??
        await _secureStorage.read(key: _keyCustomerRefreshToken);
    if (refreshToken == null) {
      return null;
    }

    // Token expirando — serializa o refresh com mutex
    if (_customerRefreshCompleter != null) {
      return _customerRefreshCompleter!.future;
    }

    _customerRefreshCompleter = Completer<String?>();
    try {
      final token = await _refreshCustomerAccessToken();
      _customerRefreshCompleter!.complete(token);
      return token;
    } catch (e) {
      _customerRefreshCompleter!.complete(null);
      rethrow;
    } finally {
      _customerRefreshCompleter = null;
    }
  }

  /// ✅ STATELESS: Renova o token de acesso usando refresh token da memória
  Future<String?> _refreshAccessToken() async {
    try {
      final refreshToken = _session.refreshToken;
      if (refreshToken == null) {
        AppLogger.w(
          '❌ Refresh token não encontrado na sessão em memória',
          tag: 'AUTH',
        );
        return null;
      }

      final refreshDio = _getRefreshDio();
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final responseData = response.data as Map<String, dynamic>;
      final newAccessToken = responseData['access_token'] as String;
      final newRefreshToken = responseData['refresh_token'] as String?;
      final expiresIn = (responseData['expires_in'] as num?)?.toInt() ?? 1800;

      // ✅ STATELESS: Atualiza tokens APENAS em memória
      _session.updateStoreTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresIn: expiresIn,
      );

      AppLogger.i(
        '✅ Token de menu renovado com sucesso (em memória)',
        tag: 'AUTH',
      );
      return newAccessToken;
    } catch (e) {
      AppLogger.e('❌ Erro ao renovar token: $e', tag: 'AUTH');
      return null;
    }
  }

  /// ✅ NOVO: Força renovação do token (usado quando recebe 401) - TOKEN DE MENU
  /// Ignora cache e força chamada ao backend
  Future<String?> forceRefreshToken() async {
    AppLogger.i('🔄 Forçando renovação de token de menu...', tag: 'AUTH');
    return await _refreshAccessToken();
  }

  /// ✅ NOVO: Força renovação do token de CUSTOMER (usado quando recebe 401)
  /// Ignora cache e força chamada ao backend
  Future<String?> forceRefreshCustomerToken() async {
    AppLogger.i('🔄 Forçando renovação de token de customer...', tag: 'AUTH');
    return await _refreshCustomerAccessToken();
  }

  /// ✅ Renova o token de acesso do CUSTOMER usando refresh token
  /// Atualiza tanto memória quanto storage (para persistir login Google)
  Future<String?> _refreshCustomerAccessToken() async {
    try {
      // Tenta refresh token da memória primeiro, depois do storage
      final refreshToken =
          _session.customerRefreshToken ??
          await _secureStorage.read(key: _keyCustomerRefreshToken);
      if (refreshToken == null) {
        AppLogger.w('❌ Refresh token de customer não encontrado', tag: 'AUTH');
        return null;
      }

      final refreshDio = _getRefreshDio();
      final response = await refreshDio.post(
        '/customer/refresh',
        data: {'refresh_token': refreshToken},
      );

      final responseData = response.data as Map<String, dynamic>;
      final newAccessToken = responseData['access_token'] as String;
      final newRefreshToken = responseData['refresh_token'] as String?;
      final expiresIn = (responseData['expires_in'] as num?)?.toInt() ?? 1800;
      final newExpiration = DateTime.now().add(Duration(seconds: expiresIn));

      // ✅ Atualiza memória
      _session.updateCustomerTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresIn: expiresIn,
      );

      // ✅ Persiste em storage (para sobreviver a refresh da página)
      await _secureStorage.write(
        key: _keyCustomerAccessToken,
        value: newAccessToken,
      );
      await _secureStorage.write(
        key: _keyCustomerTokenExpiration,
        value: newExpiration.toIso8601String(),
      );
      if (newRefreshToken != null) {
        await _secureStorage.write(
          key: _keyCustomerRefreshToken,
          value: newRefreshToken,
        );
      }

      AppLogger.i(
        '✅ Token de customer renovado com sucesso (memória + storage)',
        tag: 'AUTH',
      );
      return newAccessToken;
    } catch (e) {
      AppLogger.e('❌ Erro ao renovar token de customer: $e', tag: 'AUTH');
      return null;
    }
  }

  /// ✅ STATELESS: Verifica se há autenticação válida (da memória)
  Future<bool> isAuthenticated() async {
    return _session.hasValidStoreToken;
  }

  /// ✅ STATELESS: Faz logout e limpa tokens de MENU (da memória)
  Future<void> logout() async {
    _session.clearStoreSession();
    AppLogger.i(
      '🚪 Logout de menu realizado (sessão em memória limpa)',
      tag: 'AUTH',
    );
  }

  /// ✅ Faz logout de CUSTOMER e limpa tokens (memória + storage)
  Future<void> logoutCustomer() async {
    _session.clearCustomerSession();
    await Future.wait(<Future<void>>[
      _secureStorage.delete(key: _keyCustomerAccessToken),
      _secureStorage.delete(key: _keyCustomerRefreshToken),
      _secureStorage.delete(key: _keyCustomerTokenExpiration),
    ]);
    AppLogger.i('🚪 Logout de customer realizado com sucesso', tag: 'AUTH');
  }

  /// ✅ STATELESS: Obtém informações da loja atual (da memória)
  Map<String, String> getStoreInfo() {
    return {
      'store_id': _session.storeId?.toString() ?? '',
      'store_url': _session.storeUrl ?? '',
      'store_name': _session.storeName ?? '',
    };
  }

  /// Autentica cliente com Google e salva no backend
  /// ✅ ATUALIZADO: Salva tokens de cliente retornados
  Future<Either<String, Customer>> signInAndSaveCustomerWithGoogle(
    String? name,
    String? email,
    String? photo,
  ) async {
    try {
      AppLogger.d(
        '🔍 [AUTH] Enviando requisição /customer/google...',
        tag: 'AUTH',
      );

      final response = await _dio.post(
        '/customer/google',
        data: {'name': name, 'email': email, 'photo': photo, 'addresses': []},
      );

      AppLogger.d('🔍 [AUTH] Resposta recebida do backend', tag: 'AUTH');
      AppLogger.d('🔍 [AUTH] response.data: ${response.data}', tag: 'AUTH');

      final customer = Customer.fromJson(response.data);
      getIt<CustomerController>().setCustomer(customer);

      // ✅ CORREÇÃO CRÍTICA: Salva tokens de CLIENTE em chaves SEPARADAS
      // Esses tokens são diferentes dos tokens de menu e são usados
      // para operações autenticadas como adicionar endereços, fazer pedidos, etc.
      // NÃO sobrescreve os tokens de menu!
      final responseData = response.data as Map<String, dynamic>;

      print('🔍 [AUTH] Response data keys: ${responseData.keys.toList()}');

      final customerAccessToken = responseData['access_token'] as String?;
      final customerRefreshToken = responseData['refresh_token'] as String?;
      final expiresIn = responseData['expires_in'] as int? ?? 1800;

      print('🔍 [AUTH] access_token presente: ${customerAccessToken != null}');
      print(
        '🔍 [AUTH] refresh_token presente: ${customerRefreshToken != null}',
      );

      if (customerAccessToken != null) {
        // ✅ Salva tokens de customer em memória + storage (para persistir login Google)
        _session.setCustomerSession(
          accessToken: customerAccessToken,
          refreshToken: customerRefreshToken,
          expiresIn: expiresIn,
        );

        // ✅ Também persiste em storage para sobreviver a refresh da página
        final customerExpiration = DateTime.now().add(
          Duration(seconds: expiresIn),
        );
        await _secureStorage.write(
          key: _keyCustomerAccessToken,
          value: customerAccessToken,
        );
        if (customerRefreshToken != null) {
          await _secureStorage.write(
            key: _keyCustomerRefreshToken,
            value: customerRefreshToken,
          );
        }
        await _secureStorage.write(
          key: _keyCustomerTokenExpiration,
          value: customerExpiration.toIso8601String(),
        );

        AppLogger.i(
          '✅ [AUTH] Token de CLIENTE salvo (memória + storage, expira em ${expiresIn}s)',
          tag: 'AUTH',
        );
      } else {
        AppLogger.w(
          '⚠️ [AUTH] Backend não retornou access_token de cliente',
          tag: 'AUTH',
        );
      }

      return Right(customer);
    } on DioException catch (e) {
      AppLogger.e('❌ Erro Dio: ${e.message}', error: e, tag: 'AUTH');
      return Left(e.response?.data?['detail'] ?? 'Erro ao salvar cliente');
    } catch (e) {
      AppLogger.e('❌ Erro inesperado: $e', error: e, tag: 'AUTH');
      return Left('Erro inesperado');
    }
  }
}
