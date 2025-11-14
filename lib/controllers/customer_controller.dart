// customer_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/customer.dart';

class CustomerController extends ValueNotifier<Customer?> {
  // ✅ Usando FlutterSecureStorage ao invés de SharedPreferences
  static FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  CustomerController() : super(null);

  // --- Método existente, agora com pequeña alteração para ser mais explícito ---
  void setCustomer(Customer? customer) {
    value = customer; // Atualiza o ValueNotifier
    if (customer != null) {
      _saveCustomerToSecureStorage(customer); // Chama o método privado de salvamento
    } else {
      _clearCustomerSecureStorage(); // Limpa se o customer for nulo
    }
  }


  Customer? get customer => value;

  void clearCustomer() {
    value = null;
    _clearCustomerSecureStorage(); // Garante que também é limpo do armazenamento seguro
  }

  Future<void> loadCustomerFromSecureStorage() async {
    try {
      // ✅ Usando FlutterSecureStorage ao invés de SharedPreferences
      final json = await _secureStorage.read(key: 'customer');
      if (json != null) {
        value = Customer.fromJson(jsonDecode(json)); // Atualiza o ValueNotifier diretamente
        print('✅ Cliente carregado do armazenamento seguro: ${value?.name}, ${value?.phone}');
      } else {
        print('ℹ️ Nenhum cliente encontrado no armazenamento seguro');
      }
    } catch (e) {
      print('❌ Erro ao carregar cliente do armazenamento seguro: $e');
    }
  }

  // --- Mude para método privado, pois `setCustomer` já o usa ---
  Future<void> _saveCustomerToSecureStorage(Customer customer) async {
    try {
      // ✅ Usando FlutterSecureStorage ao invés de SharedPreferences
      await _secureStorage.write(
        key: 'customer',
        value: jsonEncode(customer.toJson()),
      );
      print('✅ Cliente salvo no armazenamento seguro: ${customer.name}, ${customer.phone}');
    } catch (e) {
      print('❌ Erro ao salvar cliente no armazenamento seguro: $e');
    }
  }

  // --- Mude para método privado, pois `setCustomer` e `clearCustomer` já o usam ---
  Future<void> _clearCustomerSecureStorage() async {
    try {
      // ✅ Usando FlutterSecureStorage ao invés de SharedPreferences
      await _secureStorage.delete(key: 'customer');
      print('✅ Cliente removido do armazenamento seguro.');
    } catch (e) {
      print('❌ Erro ao remover cliente do armazenamento seguro: $e');
    }
  }

  // --- NOVO: Método para lidar com o sucesso do login do Google ---
  // Este método será chamado pelo AddressFormPage após o Firebase/Backend retornar o Customer.
  Future<void> handleGoogleSignInSuccess(Customer customer) async {
    // Define o cliente, o que irá automaticamente atualizar o `value`
    // e salvá-lo nas shared_preferences através de `setCustomer`.
    setCustomer(customer);
    print('Login Google processado com sucesso para: ${customer.name}');
  }

  // --- NOVO: Método para atualizar APENAS o telefone localmente e persistir ---
  Future<void> updateCustomerPhoneLocally(String newPhone) async {
    if (value != null) {
      final updatedCustomer = value!.copyWith(phone: newPhone);
      setCustomer(updatedCustomer); // Isso vai atualizar o `value` e salvar no armazenamento seguro
      print('✅ Telefone atualizado localmente para: $newPhone');
    }
  }

  // --- NOVO: Método para atualizar APENAS o nome localmente e persistir ---
  Future<void> updateCustomerNameLocally(String newName) async {
    if (value != null) {
      final updatedCustomer = value!.copyWith(name: newName);
      setCustomer(updatedCustomer);
      print('✅ Nome atualizado localmente para: $newName');
    }
  }

  // ✅ NOVO: Método para limpar TODOS os dados do cliente (logout)
  Future<void> completeLogout() async {
    try {
      clearCustomer();
      // Aqui você pode adicionar limpeza de outros dados sensíveis se necessário
      print('✅ Logout completo realizado. Dados sensíveis removidos.');
    } catch (e) {
      print('❌ Erro durante logout: $e');
    }
  }

}