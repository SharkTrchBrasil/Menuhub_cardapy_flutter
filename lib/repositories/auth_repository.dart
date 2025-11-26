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

  // Chaves de armazenamento
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyTokenExpiration = 'token_expiration';
  static const String _keyTotemToken = 'totem_token';
  static const String _keyStoreId = 'store_id';
  static const String _keyStoreUrl = 'store_url';
  static const String _keyStoreName = 'store_name';

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

  /// ✅ Obtém token de acesso válido (renova se necessário)
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

  /// ✅ Faz logout e limpa tokens
  Future<void> logout() async {
    await Future.wait(<Future<void>>[
      _secureStorage.delete(key: _keyAccessToken),
      _secureStorage.delete(key: _keyRefreshToken),
      _secureStorage.delete(key: _keyTokenExpiration),
      _secureStorage.delete(key: _keyStoreId),
      _secureStorage.delete(key: _keyStoreUrl),
      _secureStorage.delete(key: _keyStoreName),
    ]);
    print('🚪 Logout realizado com sucesso');
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
  Future<Either<String, Customer>> signInAndSaveCustomerWithGoogle(
    String? name,
    String? email,
    String? photo,
  ) async {
    try {
      final response = await _dio.post(
        '/customer/google',
        data: {
          'name': name,
          'email': email,
          'photo': photo,
          'addresses': [],
        },
      );

      final customer = Customer.fromJson(response.data);
      getIt<CustomerController>().setCustomer(customer);

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
