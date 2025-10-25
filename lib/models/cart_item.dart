// lib/models/cart_item.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/product.dart';
import 'package:totem/core/extensions.dart'; // Para o helper .toCurrency

class CartItemVariantOption extends Equatable {
  final int variantOptionId;
  final int quantity;
  final String name;
  final int price;

  const CartItemVariantOption({
    required this.variantOptionId,
    required this.quantity,
    required this.name,
    required this.price,
  });

  factory CartItemVariantOption.fromJson(Map<String, dynamic> json) {
    return CartItemVariantOption(
      variantOptionId: json['variant_option_id'],
      quantity: json['quantity'],
      name: json['name'] ?? '',
      price: json['price'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'variant_option_id': variantOptionId,
    'quantity': quantity,
    'name': name,
    'price': price,
  };

  @override
  List<Object> get props => [variantOptionId, quantity, name, price];
}

class CartItemVariant extends Equatable {
  final int variantId;
  final String name;
  final List<CartItemVariantOption> options;

  const CartItemVariant({
    required this.variantId,
    required this.name,
    required this.options,
  });

  factory CartItemVariant.fromJson(Map<String, dynamic> json) {
    return CartItemVariant(
      variantId: json['variant_id'],
      name: json['name'] ?? '',
      options: (json['options'] as List)
          .map((optionJson) => CartItemVariantOption.fromJson(optionJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'variant_id': variantId,
    'name': name,
    'options': options.map((o) => o.toJson()).toList(),
  };

  @override
  List<Object> get props => [variantId, name, options];
}

class CartItem extends Equatable {
  final int id;
  final Product product;
  final int quantity;
  final String? note;
  final List<CartItemVariant> variants;
  final int unitPrice;
  final int totalPrice;
  final String? sizeName; // ✅ NOVO: Para exibir o tamanho escolhido (ex: "Pizza Grande")

  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    this.note,
    required this.variants,
    required this.unitPrice,
    required this.totalPrice,
    this.sizeName, // ✅ NOVO
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      product: Product.fromJson(json['product']),
      quantity: json['quantity'],
      note: json['note'],
      variants: (json['variants'] as List)
          .map((variantJson) => CartItemVariant.fromJson(variantJson))
          .toList(),
      unitPrice: json['unit_price'],
      totalPrice: json['total_price'],
      sizeName: json['size_name'], // ✅ NOVO
    );
  }

  // ✅ CORRIGIDO: Não tenta mais serializar o objeto 'product' inteiro.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': product.id,
      // 'product': product.toJson(), // REMOVIDO - CAUSAVA O ERRO
      'quantity': quantity,
      'note': note,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'variants': variants.map((variant) => variant.toJson()).toList(),
      'size_name': sizeName,
    };
  }

  // ✅ MÉTODO TOJSONFORORDER (formato específico para criar pedido)
  // Este método já estava correto, pois só envia o ID.
  Map<String, dynamic> toJsonForOrder() {
    return {
      'product_id': product.id,
      'quantity': quantity,
      'note': note,
      'price': unitPrice, // O backend recalcula, mas enviamos como referência
      'variants': variants.map((variant) => variant.toJson()).toList(),
      'size_name': sizeName,
    };
  }

  CartItem copyWith({
    int? id,
    Product? product,
    int? quantity,
    String? note,
    List<CartItemVariant>? variants,
    int? unitPrice,
    int? totalPrice,
    String? sizeName,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      variants: variants ?? this.variants,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      sizeName: sizeName ?? this.sizeName,
    );
  }

  const CartItem.empty()
      : id = 0,
        product = const Product.empty(),
        quantity = 1,
        note = null,
        variants = const [],
        unitPrice = 0,
        totalPrice = 0,
        sizeName = null;

  String get formattedUnitPrice => unitPrice.toCurrency;
  String get formattedTotalPrice => totalPrice.toCurrency;

  String get variantsDescription {
    if (variants.isEmpty) return sizeName ?? '';
    final descriptions = <String>[];
    if (sizeName != null) {
      descriptions.add(sizeName!);
    }
    for (final variant in variants) {
      for (final option in variant.options) {
        if (option.quantity > 1) {
          descriptions.add('${option.quantity}x ${option.name}');
        } else {
          descriptions.add(option.name);
        }
      }
    }
    return descriptions.join(', ');
  }

  bool get hasVariants => variants.isNotEmpty;

  @override
  List<Object?> get props => [id, product, quantity, note, variants, unitPrice, totalPrice, sizeName];

  @override
  String toString() {
    return 'CartItem(id: $id, product: ${product.name}, quantity: $quantity, total: $formattedTotalPrice)';
  }
}