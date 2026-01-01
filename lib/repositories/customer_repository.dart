// repositories/customer_repository.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart'; // Certifique-se de que está importado
import 'package:totem/models/customer.dart';
import 'package:totem/models/customer_address.dart';

import '../controllers/customer_controller.dart';
import '../core/di.dart';

class CustomerRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  // ✅ Chaves de armazenamento para tokens de customer
  static const String _keyCustomerAccessToken = 'customer_access_token';
  static const String _keyCustomerRefreshToken = 'customer_refresh_token';
  static const String _keyCustomerTokenExpiration = 'customer_token_expiration';

  CustomerRepository(this._dio) : _secureStorage = const FlutterSecureStorage();

  // Método adaptado para receber o User do Firebase
  // ✅ OTIMIZAÇÃO: Retorna LoginResponse com addresses e orders
  Future<Either<String, LoginResponse>> processGoogleSignInCustomer({
    required User firebaseUser, // Recebe o User diretamente
  }) async {
    try {
      final response = await _dio.post(
        '/customer/google', // Seu endpoint de backend para autenticação Google
        data: {

          'name': firebaseUser.displayName,
          'email': firebaseUser.email,
          'photo': firebaseUser.photoURL,

          'addresses': [], // Pode ser um array vazio inicialmente
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ OTIMIZAÇÃO: Usa LoginResponse que inclui addresses e orders
        final loginResponse = LoginResponse.fromJson(response.data);
        
        // Salva o cliente localmente
        getIt<CustomerController>().setCustomer(loginResponse.customer);
        
        // ✅ Salva tokens de customer retornados pelo backend
        final responseData = response.data as Map<String, dynamic>;
        final customerAccessToken = responseData['access_token'] as String?;
        final customerRefreshToken = responseData['refresh_token'] as String?;
        final expiresIn = responseData['expires_in'] as int? ?? 1800;
        
        if (customerAccessToken != null) {
          print('✅ [CUSTOMER_REPO] Salvando tokens de customer...');
          final customerExpiration = DateTime.now().add(Duration(seconds: expiresIn));
          
          // Salva tokens em chaves separadas (não sobrescreve tokens de menu)
          await _secureStorage.write(key: _keyCustomerAccessToken, value: customerAccessToken);
          print('   ✅ Customer access token salvo');
          
          if (customerRefreshToken != null) {
            await _secureStorage.write(key: _keyCustomerRefreshToken, value: customerRefreshToken);
            print('   ✅ Customer refresh token salvo');
          }
          
          await _secureStorage.write(key: _keyCustomerTokenExpiration, value: customerExpiration.toIso8601String());
          print('   ✅ Customer expiração salva: ${customerExpiration.toIso8601String()}');
          print('✅ [CUSTOMER_REPO] Tokens de customer salvos com sucesso (expira em ${expiresIn}s)');
          print('✅ [CUSTOMER_REPO] Login incluiu ${loginResponse.addresses.length} endereços e ${loginResponse.orders.length} pedidos');
        } else {
          print('⚠️ [CUSTOMER_REPO] Backend não retornou access_token de customer');
        }
        
        return Right(loginResponse);
      } else {
        print('Erro na API ao processar cliente Google: ${response.statusCode} - ${response.data}');
        return Left('Erro no servidor: ${response.data['message'] ?? 'Detalhes desconhecidos'}');
      }
    } on DioException catch (e) {
      print('Erro Dio ao processar cliente Google: ${e.message}');
      print('Status: ${e.response?.statusCode}');
      print('URL: ${e.requestOptions.uri}');
      print('Data enviado: ${e.requestOptions.data}');
      print('Resposta: ${e.response?.data}');
      String errorMessage = 'Erro de conexão ou no servidor.';
      if (e.response?.data != null && e.response?.data['message'] != null) {
        errorMessage = e.response!.data['message'];
      }
      return Left(errorMessage);
    } catch (e) {
      print('Erro inesperado ao processar cliente Google: $e');
      return Left('Um erro inesperado ocorreu: ${e.toString()}');
    }
  }

  Future<Either<String, Customer>> updateCustomerInfo(
    int customerId,
    String name,
    String phone, {
    String? email,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'phone': phone,
      };
      if (email != null && email.isNotEmpty) {
        data['email'] = email;
      }

      final response = await _dio.patch('/customer/$customerId', data: data);

      final updatedCustomer = Customer.fromJson(response.data);
      print('Cliente atualizado no backend: ${updatedCustomer.name}, ${updatedCustomer.phone}');
      return Right(updatedCustomer);
    } on DioException catch (e) {
      final errorMessage = e.response?.data['detail'] ?? 
                          e.response?.data['message'] ?? 
                          'Erro desconhecido ao atualizar cliente.';
      print('Erro ao atualizar cliente: $errorMessage');
      return Left(errorMessage);
    } catch (e) {
      print('Erro inesperado ao atualizar cliente: $e');
      return Left('Erro inesperado: $e');
    }
  }

  Future<Either<String, Customer>> uploadCustomerPhoto(
    int customerId,
    XFile imageFile,
  ) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.name,
        ),
      });

      final response = await _dio.post(
        '/customer/$customerId/photo',
        data: formData,
      );

      final updatedCustomer = Customer.fromJson(response.data);
      return Right(updatedCustomer);
    } on DioException catch (e) {
      final errorMessage = e.response?.data['detail'] ?? 
                          e.response?.data['message'] ?? 
                          'Erro ao fazer upload da foto.';
      return Left(errorMessage);
    } catch (e) {
      return Left('Erro inesperado: $e');
    }
  }

  /// Atualiza um endereço existente do cliente
  Future<Either<void, CustomerAddress>> updateCustomerAddress({
    required int customerId,
    required CustomerAddress address, // O endereço precisa ter o ID preenchido
  }) async {
    // Verifica se o ID do endereço está presente. É crucial para a atualização.
    if (address.id == null) {
      print('Erro: O ID do endereço é obrigatório para atualização.');
      return Left(null); // Retorna um erro se o ID não estiver presente
    }

    try {
      final response = await _dio.put( // Usamos PUT para atualização
        '/customer/$customerId/addresses/${address.id}', // Inclui o ID do endereço na URL
        data: address.toJson(), // Envia o objeto CustomerAddress completo
      );
      return Right(CustomerAddress.fromJson(response.data));
    } on DioException catch (e) {
      print('Erro ao atualizar endereço: ${e.message}');
      return Left(null);
    }
  }
  /// Adiciona um novo endereço para o cliente
  Future<Either<void, CustomerAddress>> addCustomerAddress({
    required int customerId,
    required CustomerAddress address,
  }) async {
    try {
      final response = await _dio.post(
        '/customer/$customerId/addresses',
        data: address.toJson(),
      );
      return Right(CustomerAddress.fromJson(response.data));
    } on DioException catch (e) {
      print('Erro ao adicionar endereço: ${e.message}');
      return Left(null);
    }
  }

  /// Deleta um endereço do cliente
  Future<bool> deleteCustomerAddress(
    int customerId,
     int addressId,
  ) async {
    try {
      await _dio.delete('/customer/$customerId/addresses/$addressId');
      return true;
    } on DioException catch (e) {
      print('Erro ao deletar endereço: ${e.message}');
      return false;
    }
  }



  Future<Either<void, CustomerAddress>> getCustomerAddress(int customerId, int addressId) async {
    try {
      final response = await _dio.get('/customer/$customerId/addresses/$addressId');
      // Assuming the API returns a single JSON object for a specific checkout ID
      return Right(CustomerAddress.fromJson(response.data));
    } catch (e, s) {
      debugPrint('Error getting customer checkout: $e $s');
      return const Left(null);
    }
  }



  Future<Either<void, List<CustomerAddress>>> getCustomerAddresses(int customerId) async {
    try {
      final response = await _dio.get('/customer/$customerId/addresses');
      final data = response.data as List;
      final addresses = data.map((json) => CustomerAddress.fromJson(json)).toList();
      return Right(addresses);
    } on DioException catch (e) {
      print('Erro ao buscar todos os endereços: ${e.message}');
      return Left(null);
    }
  }
}