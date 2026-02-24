import 'package:totem/models/customer_address.dart';
import 'package:totem/models/order.dart';

class Customer {
  final int? id;
  final String name;
  final String email;
  final String? phone;
  final String? photo;
  final String? cpf; // ✅ ADICIONADO

  Customer({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photo,
    this.cpf,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    phone: json['phone'],
    photo: json['photo'],
    cpf: json['cpf'] ?? json['tax_id'], // Aceita cpf ou tax_id
  );


  Customer copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? photo,
    String? cpf,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photo: photo ?? this.photo,
      cpf: cpf ?? this.cpf,
    );
  }




  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "email": email,
    "phone": phone,
    "photo": photo,
    "cpf": cpf,
  };



}

/// ✅ OTIMIZAÇÃO: Resposta completa do login incluindo addresses e orders
/// Evita chamadas HTTP separadas após o login
class LoginResponse {
  final Customer customer;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final List<CustomerAddress> addresses;
  final List<Order> orders;

  LoginResponse({
    required this.customer,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.addresses,
    required this.orders,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Parse customer data
    final customer = Customer.fromJson(json);
    
    // Parse addresses
    final addressesList = (json['addresses'] as List<dynamic>?) ?? [];
    final addresses = addressesList
        .map((addr) => CustomerAddress.fromJson(addr as Map<String, dynamic>))
        .toList();
    
    // Parse orders
    final ordersList = (json['orders'] as List<dynamic>?) ?? [];
    final orders = <Order>[];
    for (final orderJson in ordersList) {
      try {
        orders.add(Order.fromJson(orderJson as Map<String, dynamic>));
      } catch (e) {
        print('⚠️ [LoginResponse] Erro ao parsear order: $e');
      }
    }
    
    return LoginResponse(
      customer: customer,
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 1800,
      addresses: addresses,
      orders: orders,
    );
  }
}
