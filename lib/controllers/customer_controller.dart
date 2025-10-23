// customer_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';

class CustomerController extends ValueNotifier<Customer?> {

  CustomerController() : super(null);

  // --- Método existente, agora com pequena alteração para ser mais explícito ---
  void setCustomer(Customer? customer) {
    value = customer; // Atualiza o ValueNotifier
    if (customer != null) {
      _saveCustomerToPrefs(customer); // Chama o método privado de salvamento
    } else {
      _clearCustomerPrefs(); // Limpa se o customer for nulo
    }
  }


  Customer? get customer => value;

  void clearCustomer() {
    value = null;
    _clearCustomerPrefs(); // Garante que também é limpo das preferências
  }

  Future<void> loadCustomerFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('customer');
    if (json != null) {
      value = Customer.fromJson(jsonDecode(json)); // Atualiza o ValueNotifier diretamente
      print('Cliente carregado das preferências: ${value?.name}, ${value?.phone}');
    }
  }

  // --- Mude para método privado, pois `setCustomer` já o usa ---
  Future<void> _saveCustomerToPrefs(Customer customer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customer', jsonEncode(customer.toJson()));
    print('Cliente salvo nas preferências: ${customer.name}, ${customer.phone}');
  }

  // --- Mude para método privado, pois `setCustomer` e `clearCustomer` já o usam ---
  Future<void> _clearCustomerPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer');
    print('Cliente removido das preferências.');
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
      setCustomer(updatedCustomer); // Isso vai atualizar o `value` e salvar nas preferências
      print('Telefone atualizado localmente para: $newPhone');
    }
  }

  // --- NOVO: Método para atualizar APENAS o nome localmente e persistir ---
  Future<void> updateCustomerNameLocally(String newName) async {
    if (value != null) {
      final updatedCustomer = value!.copyWith(name: newName);
      setCustomer(updatedCustomer);
      print('Nome atualizado localmente para: $newName');
    }
  }
}