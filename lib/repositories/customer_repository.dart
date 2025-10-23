// repositories/customer_repository.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:nb_utils/nb_utils.dart'; // Certifique-se de que está importado
import 'package:totem/models/customer.dart';
import 'package:totem/models/customer_address.dart';

import '../controllers/customer_controller.dart';
import '../core/di.dart';

class CustomerRepository {
  final Dio _dio;

  CustomerRepository(this._dio);

  // Método adaptado para receber o User do Firebase
  Future<Either<String, Customer>> processGoogleSignInCustomer({
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
        final customer = Customer.fromJson(response.data);
        // Salva o cliente localmente
        getIt<CustomerController>().setCustomer(customer);
        return Right(customer);
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

  Future<Either<String, Customer>> updateCustomerInfo(int customerId, String name, String phone) async {
    try {
      final response = await _dio.patch('/customer/$customerId', data: {
        'name': name,
        'phone': phone,
      });

      // Assuming your API returns the updated customer data directly in response.data
      final updatedCustomer = Customer.fromJson(response.data);
      print('Cliente atualizado no backend: ${updatedCustomer.name}, ${updatedCustomer.phone}');
      return Right(updatedCustomer); // Return the updated customer wrapped in Right
    } on DioException catch (e) {
      // Extract a meaningful error message from the DioException
      final errorMessage = e.response?.data['message'] ?? 'Erro desconhecido ao atualizar cliente.';
      print('Erro ao atualizar cliente: $errorMessage');
      return Left(errorMessage); // Return the error message wrapped in Left
    } catch (e) {
      // Catch any other unexpected errors
      print('Erro inesperado ao atualizar cliente: $e');
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