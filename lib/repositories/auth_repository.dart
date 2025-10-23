import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:totem/models/totem_auth.dart';
import 'package:uuid/uuid.dart';

import '../controllers/customer_controller.dart';
import '../core/di.dart';
import '../models/customer.dart';
import '../models/customer_address.dart';
import 'package:shared_preferences/shared_preferences.dart';





class AuthRepository {
  AuthRepository(this._dio, this._secureStorage);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;


  /// Handles Google Sign-In process.
// In AuthRepository
  Future<User?> signInWithGoogle() async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider(),
      );
      return userCredential.user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }


  Future<Either<void, TotemAuth>> checkToken() async {
    try {
      final token = await getTotemToken();
      if (token.isEmpty) {
        return Left(null);
      }

      final response = await _dio.post(
        '/auth/check-token',
        data: {'totem_token': token},
      );

      return Right(TotemAuth.fromJson(response.data));
    } catch (e) {
      print('Error in checkToken: $e');
      return Left(null);
    }
  }


// lib/repositories/auth_repository.dart

  Future<Either<void, TotemAuth>> getToken(String storeSlug) async {
    try {
      final token = await getTotemToken(); // Gera ou recupera token único

      final response = await _dio.post(
        '/auth/subdomain',
        data: {
          'store_url': storeSlug,
          'totem_token': token,
        },
      );

      final TotemAuth totemAuth = TotemAuth.fromJson(response.data);

      // ✅ Salva o token no storage seguro
      await _secureStorage.write(key: 'totem_token', value: totemAuth.token);

      return Right(totemAuth);
    } catch (e) {
      print('❌ Erro ao buscar token: $e');
      return Left(null);
    }
  }

  Future<String> getTotemToken() async {
    String? token = await _secureStorage.read(key: 'totem_token');

    if (token != null && token.isNotEmpty) {
      print('✅ Token existente encontrado');
      return token;
    }

    // Gera novo token único
    token = const Uuid().v4();
    await _secureStorage.write(key: 'totem_token', value: token);
    print('🆕 Novo token gerado: $token');

    return token;
  }







  Future<Either<void, Customer>> signInAndSaveCustomerWithGoogle(String? name, String? email, String? photo) async {
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
      print('Erro Dio: ${e.message}');
      print('Status: ${e.response?.statusCode}');
      print('URL: ${e.requestOptions.uri}');
      print('Data enviado: ${e.requestOptions.data}');
      print('Resposta: ${e.response?.data}');
      return Left(null);
    } catch (e) {
      print('Erro inesperado: $e');
      return Left(null);
    }

  }



















}
