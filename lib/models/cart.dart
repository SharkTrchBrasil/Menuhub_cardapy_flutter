// Em: lib/models/cart.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/product.dart';

import 'cart_item.dart';


class CartItemVariantOption extends Equatable {
  final int variantOptionId;
  final int quantity;
  // ✅ Adicione estes campos para exibição na UI
  final String name;
  final int price;

  const CartItemVariantOption({
    required this.variantOptionId,
    required this.quantity,
    required this.name, // ✅
    required this.price, // ✅
  });

  factory CartItemVariantOption.fromJson(Map<String, dynamic> json) {
    return CartItemVariantOption(
      variantOptionId: json['variant_option_id'],
      quantity: json['quantity'],
      name: json['name'] ?? '', // ✅
      price: json['price'] ?? 0, // ✅
    );
  }

  Map<String, dynamic> toJson() => {
    'variant_option_id': variantOptionId,
    'quantity': quantity,
  };

  @override
  List<Object> get props => [variantOptionId, quantity];
}

class CartItemVariant extends Equatable {
  final int variantId;
  final String name; // ✅ Adicione o nome do grupo
  final List<CartItemVariantOption> options;

  const CartItemVariant({
    required this.variantId,
    required this.name, // ✅
    required this.options,
  });

  factory CartItemVariant.fromJson(Map<String, dynamic> json) {
    return CartItemVariant(
      variantId: json['variant_id'],
      name: json['name'] ?? '', // ✅
      options: (json['options'] as List)
          .map((optionJson) => CartItemVariantOption.fromJson(optionJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'variant_id': variantId,
    'options': options.map((o) => o.toJson()).toList(),
  };

  @override
  List<Object> get props => [variantId, options];
}





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
      subtotal: json['subtotal'],
      discount: json['discount'],
      total: json['total'],
    );
  }



  @override
  List<Object?> get props => [id, status, couponCode, observation, items, subtotal, discount, total];
}