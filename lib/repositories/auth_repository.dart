// lib/repositories/auth_repository.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:totem/models/totem_auth.dart';
import 'package:uuid/uuid.dart';
import '../controllers/customer_controller.dart';
import '../core/di.dart';
import '../models/customer.dart';

class AuthRepository {
  AuthRepository(this._dio, this._secureStorage);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  
  // ✅ Dio separado para refresh token (sem interceptor de autenticação)
  Dio? _refreshDio;
  
  // ✅ Lock para evitar múltiplas renovações simultâneas
  bool _isRefreshing = false;
  String? _pendingToken;

  // ✅ Chaves de armazenamento
  static const String _keyTotemToken = 'totem_token';
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyTokenExpiration = 'token_expiration';
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

  /// ✅ Obtém o access token válido (renova se necessário)
  Future<String?> getValidAccessToken() async {
    // ✅ Se já está renovando, aguarda o token pendente
    if (_isRefreshing && _pendingToken != null) {
      print('⏳ Aguardando renovação de token em andamento...');
      // Aguarda até 5 segundos
      int attempts = 0;
      while (_isRefreshing && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_pendingToken != null) {
        return _pendingToken;
      }
    }
    
    final accessToken = await _secureStorage.read(key: _keyAccessToken);
    final expirationStr = await _secureStorage.read(key: _keyTokenExpiration);

    if (accessToken == null || expirationStr == null) {
      print('⚠️ Nenhum token de acesso encontrado');
      return null;
    }

    final expiration = DateTime.parse(expirationStr);
    final now = DateTime.now();

    // Se faltar menos de 5 minutos para expirar, renova
    if (expiration.isBefore(now.add(const Duration(minutes: 5)))) {
      // ✅ Evita múltiplas renovações simultâneas
      if (_isRefreshing) {
        print('⏳ Renovação já em andamento, aguardando...');
        int attempts = 0;
        while (_isRefreshing && attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        final newToken = await _secureStorage.read(key: _keyAccessToken);
        return newToken;
      }
      
      print('🔄 Token expirando, renovando...');
      final refreshed = await _refreshAccessToken();
      if (refreshed.isRight) {
        return refreshed.right;
      } else {
        print('❌ Falha ao renovar token');
        return null;
      }
    }

    return accessToken;
  }

  /// ✅ Renova o access token usando o refresh token
  Future<Either<String, String>> _refreshAccessToken() async {
    // ✅ Lock para evitar múltiplas renovações simultâneas
    if (_isRefreshing) {
      print('⚠️ Renovação já em andamento, aguardando...');
      int attempts = 0;
      while (_isRefreshing && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      final token = await _secureStorage.read(key: _keyAccessToken);
      return token != null ? Right(token) : const Left('Token não disponível após renovação');
    }
    
    _isRefreshing = true;
    _pendingToken = null;
    
    try {
      // ✅ Usa Dio separado sem interceptor
      final refreshDio = _getRefreshDio();
      
      final refreshToken = await _secureStorage.read(key: _keyRefreshToken);

      if (refreshToken == null) {
        _isRefreshing = false;
        return const Left('Refresh token não encontrado');
      }

      // ✅ Usa refreshDio (sem interceptor) para evitar loop
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String;
      final expiresIn = response.data['expires_in'] as int;
      final newExpiration = DateTime.now().add(Duration(seconds: expiresIn));

      // Salva novo access token
      await _secureStorage.write(key: _keyAccessToken, value: newAccessToken);
      await _secureStorage.write(key: _keyTokenExpiration, value: newExpiration.toIso8601String());

      _pendingToken = newAccessToken;
      _isRefreshing = false;
      
      print('✅ Token renovado com sucesso');
      return Right(newAccessToken);
    } on DioException catch (e) {
      _isRefreshing = false;
      _pendingToken = null;
      print('❌ Erro ao renovar token: ${e.message}');
      print('❌ Status: ${e.response?.statusCode}');
      print('❌ Response: ${e.response?.data}');
      return Left(e.message ?? 'Erro desconhecido');
    } catch (e) {
      _isRefreshing = false;
      _pendingToken = null;
      print('❌ Erro inesperado ao renovar token: $e');
      return Left('Erro inesperado');
    }
  }

  /// ✅ Autentica no backend e obtém JWT tokens
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

  /// ✅ Salva dados de autenticação no secure storage
  Future<void> _saveAuthData(TotemAuth auth) async {
    await Future.wait([
      _secureStorage.write(key: _keyAccessToken, value: auth.accessToken),
      _secureStorage.write(key: _keyRefreshToken, value: auth.refreshToken),
      _secureStorage.write(key: _keyTokenExpiration, value: auth.expirationTime.toIso8601String()),
      _secureStorage.write(key: _keyStoreId, value: auth.storeId.toString()),
      _secureStorage.write(key: _keyStoreUrl, value: auth.storeUrl),
      _secureStorage.write(key: _keyStoreName, value: auth.storeName),
    ]);
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
    await Future.wait([
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