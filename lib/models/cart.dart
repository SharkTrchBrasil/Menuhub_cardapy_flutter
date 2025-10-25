// Em: lib/models/cart.dart

import 'package:equatable/equatable.dart';
import 'cart_item.dart';

class Cart extends Equatable {
  final int id;
  final String status;
  final String? couponCode;
  final String? observation;
  final List<CartItem> items;

  // Campos calculados pelo backend
  final int subtotal;
  final int discount;
  final int total;

  const Cart({
    required this.id,
    required this.status,
    this.couponCode,
    this.observation,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  // Um construtor 'vazio' é útil para o estado inicial
  const Cart.empty()
      : id = 0,
        status = 'empty',
        couponCode = null,
        observation = null,
        items = const [],
        subtotal = 0,
        discount = 0,
        total = 0;

  bool get isEmpty => id == 0 || items.isEmpty;

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'],
      status: json['status'],
      couponCode: json['coupon_code'],
      observation: json['observation'],
      items: (json['items'] as List)
          .map((itemJson) => CartItem.fromJson(itemJson))
          .toList(),
      subtotal: json['subtotal'] ?? 0,
      discount: json['discount'] ?? 0,
      total: json['total'] ?? 0,
    );
  }

  Cart copyWith({
    int? id,
    String? status,
    String? couponCode,
    String? observation,
    List<CartItem>? items,
    int? subtotal,
    int? discount,
    int? total,
  }) {
    return Cart(
      id: id ?? this.id,
      status: status ?? this.status,
      couponCode: couponCode ?? this.couponCode,
      observation: observation ?? this.observation,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
    );
  }

  @override
  List<Object?> get props =>
      [id, status, couponCode, observation, items, subtotal, discount, total];
}