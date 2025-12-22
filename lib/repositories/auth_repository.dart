import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../controllers/customer_controller.dart';
import '../core/di.dart';
import '../models/customer.dart';
import '../models/totem_auth.dart';

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  Dio? _refreshDio;

  AuthRepository(this._dio, this._secureStorage);

  // Chaves de armazenamento - TOKENS DE MENU/TOTEM
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyTokenExpiration = 'token_expiration';
  static const String _keyTotemToken = 'totem_token';
  static const String _keyStoreId = 'store_id';
  static const String _keyStoreUrl = 'store_url';
  static const String _keyStoreName = 'store_name';
  
  // ✅ NOVO: Chaves de armazenamento - TOKENS DE CUSTOMER (separados)
  static const String _keyCustomerAccessToken = 'customer_access_token';
  static const String _keyCustomerRefreshToken = 'customer_refresh_token';
  static const String _keyCustomerTokenExpiration = 'customer_token_expiration';

  /// ✅ Inicializa Dio separado para refresh (sem interceptor)
  Dio _getRefreshDio() {
    if (_refreshDio != null) return _refreshDio!;

    // Usa a mesma base URL mas sem interceptores de autenticação
    final apiUrl = _dio.options.baseUrl.replaceAll('/app', '');
    _refreshDio = Dio(BaseOptions(
      baseUrl: '$apiUrl/app',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ));
    return _refreshDio!;
  }

  /// ✅ MÉTODO PRINCIPAL: Autentica na loja via subdomínio
  Future<Either<String, TotemAuth>> getToken(String storeSlug) async {
    try {
      final totemToken = await getTotemToken();

      print('🔐 Autenticando com store_url: $storeSlug');

      final response = await _dio.post(
        '/auth/subdomain',
        data: {
          'store_url': storeSlug,
          'totem_token': totemToken,
        },
      );

      final TotemAuth totemAuth = TotemAuth.fromJson(response.data);

      // ✅ Salva todos os tokens e metadados
      await _saveAuthData(totemAuth);

      print('✅ Autenticação bem-sucedida para loja: ${totemAuth.storeName}');
      return Right(totemAuth);
    } on DioException catch (e) {
      print('❌ Erro ao buscar token: ${e.response?.data ?? e.message}');
      return Left(e.response?.data?['detail'] ?? 'Erro ao autenticar');
    } catch (e) {
      print('❌ Erro inesperado: $e');
      return Left('Erro inesperado ao autenticar');
    }
  }

  /// Handles Google Sign-In process
  Future<User?> signInWithGoogle() async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider(),
      );
      return userCredential.user;
    } catch (e) {
      print('❌ Error signing in with Google: $e');
      return null;
    }
  }

  /// ✅ Salva dados de autenticação no secure storage
  Future<void> _saveAuthData(TotemAuth auth) async {
    await Future.wait(<Future<void>>[
      _secureStorage.write(key: _keyAccessToken, value: auth.accessToken),
      _secureStorage.write(key: _keyRefreshToken, value: auth.refreshToken),
      _secureStorage.write(key: _keyTokenExpiration, value: auth.expirationTime.toIso8601String()),
      _secureStorage.write(key: _keyStoreId, value: auth.storeId.toString()),
      _secureStorage.write(key: _keyStoreUrl, value: auth.storeUrl),
      _secureStorage.write(key: _keyStoreName, value: auth.storeName),
    ]);
  }

  /// ✅ Obtém token de acesso válido (renova se necessário) - TOKEN DE MENU/TOTEM
  Future<String?> getValidAccessToken() async {
    final accessToken = await _secureStorage.read(key: _keyAccessToken);
    final expirationStr = await _secureStorage.read(key: _keyTokenExpiration);

    if (accessToken == null || expirationStr == null) {
      return null;
    }

    final expiration = DateTime.tryParse(expirationStr);
    if (expiration == null) {
      return null;
    }

    // Se expirou ou vai expirar em menos de 1 minuto, renova
    if (expiration.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      print('⏰ Token expirando, renovando...');
      return await _refreshAccessToken();
    }

    return accessToken;
  }
  
  /// ✅ NOVO: Obtém token de acesso válido do CUSTOMER (renova se necessário)
  Future<String?> getValidCustomerAccessToken() async {
    final accessToken = await _secureStorage.read(key: _keyCustomerAccessToken);
    final expirationStr = await _secureStorage.read(key: _keyCustomerTokenExpiration);

    if (accessToken == null || expirationStr == null) {
      return null;
    }

    final expiration = DateTime.tryParse(expirationStr);
    if (expiration == null) {
      return null;
    }

    // Se expirou ou vai expirar em menos de 1 minuto, renova
    if (expiration.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      print('⏰ Token de customer expirando, renovando...');
      return await _refreshCustomerAccessToken();
    }

    return accessToken;
  }

  /// ✅ Renova o token de acesso usando refresh token
  Future<String?> _refreshAccessToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _keyRefreshToken);
      if (refreshToken == null) {
        print('❌ Refresh token não encontrado');
        return null;
      }

      final refreshDio = _getRefreshDio();
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String;
      final newExpiration = DateTime.now().add(const Duration(minutes: 30));

      await _secureStorage.write(key: _keyAccessToken, value: newAccessToken);
      await _secureStorage.write(key: _keyTokenExpiration, value: newExpiration.toIso8601String());

      print('✅ Token renovado com sucesso');
      return newAccessToken;
    } catch (e) {
      print('❌ Erro ao renovar token: $e');
      return null;
    }
  }

  /// ✅ NOVO: Força renovação do token (usado quando recebe 401) - TOKEN DE MENU
  /// Ignora cache e força chamada ao backend
  Future<String?> forceRefreshToken() async {
    print('🔄 Forçando renovação de token de menu...');
    return await _refreshAccessToken();
  }
  
  /// ✅ NOVO: Força renovação do token de CUSTOMER (usado quando recebe 401)
  /// Ignora cache e força chamada ao backend
  Future<String?> forceRefreshCustomerToken() async {
    print('🔄 Forçando renovação de token de customer...');
    return await _refreshCustomerAccessToken();
  }
  
  /// ✅ NOVO: Renova o token de acesso do CUSTOMER usando refresh token
  Future<String?> _refreshCustomerAccessToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _keyCustomerRefreshToken);
      if (refreshToken == null) {
        print('❌ Refresh token de customer não encontrado');
        return null;
      }

      final refreshDio = _getRefreshDio();
      // ✅ CORREÇÃO: Usa endpoint específico para refresh de customer
      final response = await refreshDio.post(
        '/customer/refresh',
        data: {'refresh_token': refreshToken},
      );

      // ✅ CORREÇÃO: Converte response.data para Map antes de acessar
      final responseData = response.data as Map<String, dynamic>;
      final newAccessToken = responseData['access_token'] as String;
      final newRefreshToken = responseData['refresh_token'] as String?;
      final expiresIn = (responseData['expires_in'] as num?)?.toInt() ?? 1800;
      final newExpiration = DateTime.now().add(Duration(seconds: expiresIn));

      await _secureStorage.write(key: _keyCustomerAccessToken, value: newAccessToken);
      await _secureStorage.write(key: _keyCustomerTokenExpiration, value: newExpiration.toIso8601String());
      
      // Se o backend retornou um novo refresh token, salva também
      if (newRefreshToken != null) {
        await _secureStorage.write(key: _keyCustomerRefreshToken, value: newRefreshToken);
      }

      print('✅ Token de customer renovado com sucesso');
      return newAccessToken;
    } catch (e) {
      print('❌ Erro ao renovar token de customer: $e');
      return null;
    }
  }

  /// ✅ Verifica se há autenticação válida
  Future<bool> isAuthenticated() async {
    final accessToken = await getValidAccessToken();
    return accessToken != null;
  }

  /// ✅ Obtém ou gera totem token único
  Future<String> getTotemToken() async {
    String? token = await _secureStorage.read(key: _keyTotemToken);

    if (token != null && token.isNotEmpty) {
      print('✅ Token existente encontrado');
      return token;
    }

    // Gera novo token único
    token = const Uuid().v4();
    await _secureStorage.write(key: _keyTotemToken, value: token);
    print('🆕 Novo totem token gerado: $token');

    return token;
  }

  /// ✅ Faz logout e limpa tokens de MENU
  Future<void> logout() async {
    await Future.wait(<Future<void>>[
      _secureStorage.delete(key: _keyAccessToken),
      _secureStorage.delete(key: _keyRefreshToken),
      _secureStorage.delete(key: _keyTokenExpiration),
      _secureStorage.delete(key: _keyStoreId),
      _secureStorage.delete(key: _keyStoreUrl),
      _secureStorage.delete(key: _keyStoreName),
    ]);
    print('🚪 Logout de menu realizado com sucesso');
  }
  
  /// ✅ NOVO: Faz logout de CUSTOMER e limpa tokens de customer
  Future<void> logoutCustomer() async {
    await Future.wait(<Future<void>>[
      _secureStorage.delete(key: _keyCustomerAccessToken),
      _secureStorage.delete(key: _keyCustomerRefreshToken),
      _secureStorage.delete(key: _keyCustomerTokenExpiration),
    ]);
    print('🚪 Logout de customer realizado com sucesso');
  }

  /// ✅ Obtém informações da loja atual
  Future<Map<String, String>> getStoreInfo() async {
    final storeId = await _secureStorage.read(key: _keyStoreId);
    final storeUrl = await _secureStorage.read(key: _keyStoreUrl);
    final storeName = await _secureStorage.read(key: _keyStoreName);

    return {
      'store_id': storeId ?? '',
      'store_url': storeUrl ?? '',
      'store_name': storeName ?? '',
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
      print('🔍 [AUTH] Enviando requisição /customer/google...');
      
      final response = await _dio.post(
        '/customer/google',
        data: {
          'name': name,
          'email': email,
          'photo': photo,
          'addresses': [],
        },
      );

      print('🔍 [AUTH] Resposta recebida do backend');
      print('🔍 [AUTH] response.data type: ${response.data.runtimeType}');
      print('🔍 [AUTH] response.data: ${response.data}');

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
      print('🔍 [AUTH] refresh_token presente: ${customerRefreshToken != null}');
      
      if (customerAccessToken != null) {
        print('✅ [AUTH] Salvando token de CLIENTE em chaves separadas...');
        final customerExpiration = DateTime.now().add(Duration(seconds: expiresIn));
        
        // ✅ CORREÇÃO: Salva em chaves SEPARADAS (não sobrescreve tokens de menu)
        await _secureStorage.write(key: _keyCustomerAccessToken, value: customerAccessToken);
        print('   ✅ Customer access token salvo');
        
        // Salva refresh token se presente
        if (customerRefreshToken != null) {
          await _secureStorage.write(key: _keyCustomerRefreshToken, value: customerRefreshToken);
          print('   ✅ Customer refresh token salvo');
        }
        
        // Salva expiração
        await _secureStorage.write(key: _keyCustomerTokenExpiration, value: customerExpiration.toIso8601String());
        print('   ✅ Customer expiração salva: ${customerExpiration.toIso8601String()}');
        
        print('✅ [AUTH] Token de CLIENTE salvo com sucesso (expira em ${expiresIn}s)');
        print('✅ [AUTH] Tokens de menu NÃO foram sobrescritos');
      } else {
        print('⚠️ [AUTH] Backend não retornou access_token de cliente');
      }

      return Right(customer);
    } on DioException catch (e) {
      print('❌ Erro Dio: ${e.message}');
      print('Status: ${e.response?.statusCode}');
      print('Resposta: ${e.response?.data}');
      return Left(e.response?.data?['detail'] ?? 'Erro ao salvar cliente');
    } catch (e) {
      print('❌ Erro inesperado: $e');
      return Left('Erro inesperado');
    }
  }
}
