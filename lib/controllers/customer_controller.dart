import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/customer.dart';
import '../services/encrypted_storage_service.dart';

class CustomerController extends ValueNotifier<Customer?> {
  final EncryptedStorageService _storage;

  // ✅ Instância temporária para migração
  final _oldStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  CustomerController(this._storage) : super(null);

  void setCustomer(Customer? customer) {
    value = customer;
    if (customer != null) {
      _saveCustomerToSecureStorage(customer);
    } else {
      _clearCustomerSecureStorage();
    }
  }

  Customer? get customer => value;

  Future<void> clearCustomer() async {
    value = null;
    await _clearCustomerSecureStorage();
  }

  Future<void> loadCustomerFromSecureStorage() async {
    try {
      // 1. Tenta carregar do novo armazenamento (AES-256)
      String? json = await _storage.read(key: 'customer');

      if (json != null) {
        value = Customer.fromJson(jsonDecode(json));
        print(
          '✅ Cliente carregado do armazenamento seguro (AES-256): ${value?.name}',
        );
        return;
      }

      // 2. 🔄 MIGAÇÃO: Tenta carregar do armazenamento antigo se o novo estiver vazio
      print('🔄 Tentando migração de dados do armazenamento antigo...');
      json = await _oldStorage.read(key: 'customer');

      if (json != null) {
        final oldCustomer = Customer.fromJson(jsonDecode(json));
        value = oldCustomer;

        // Salva no novo formato imediatamente
        await _saveCustomerToSecureStorage(oldCustomer);

        // Verificar se a escrita realmente persistiu antes de deletar a fonte
        final verification = await _storage.read(key: 'customer');
        if (verification != null) {
          await _oldStorage.delete(key: 'customer');
          print('✅ Migração concluída e dado original removido.');
        } else {
          print(
            '⚠️ Escrita no novo storage não verificada — mantendo dado original por segurança.',
          );
        }

        print('✅ Cliente migrado com sucesso para AES-256: ${value?.name}');
      } else {
        print('ℹ️ Nenhum cliente encontrado para migração.');
      }
    } catch (e) {
      print('❌ Erro ao carregar/migrar cliente: $e');
    }
  }

  Future<void> _saveCustomerToSecureStorage(Customer customer) async {
    try {
      await _storage.write(
        key: 'customer',
        value: jsonEncode(customer.toJson()),
      );
      print(
        '✅ Cliente salvo no armazenamento seguro (AES-256): ${customer.name}',
      );
    } catch (e) {
      print('❌ Erro ao salvar cliente no armazenamento seguro: $e');
    }
  }

  Future<void> _clearCustomerSecureStorage() async {
    try {
      await _storage.delete(key: 'customer');
      await _oldStorage.delete(
        key: 'customer',
      ); // Limpa também o antigo por segurança
      print('✅ Cliente removido de todos os armazenamentos.');
    } catch (e) {
      print('❌ Erro ao remover cliente: $e');
    }
  }

  Future<void> handleGoogleSignInSuccess(Customer customer) async {
    setCustomer(customer);
    print('Login Google processado com sucesso para: ${customer.name}');
  }

  Future<void> updateCustomerPhoneLocally(String newPhone) async {
    if (value != null) {
      final updatedCustomer = value!.copyWith(phone: newPhone);
      setCustomer(updatedCustomer);
      print('✅ Telefone atualizado localmente para: $newPhone');
    }
  }

  Future<void> updateCustomerNameLocally(String newName) async {
    if (value != null) {
      final updatedCustomer = value!.copyWith(name: newName);
      setCustomer(updatedCustomer);
      print('✅ Nome atualizado localmente para: $newName');
    }
  }

  Future<void> completeLogout() async {
    try {
      clearCustomer();
      print('✅ Logout completo realizado. Dados sensíveis removidos.');
    } catch (e) {
      print('❌ Erro durante logout: $e');
    }
  }
}
