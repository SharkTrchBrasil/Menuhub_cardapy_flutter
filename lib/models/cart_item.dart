// lib/models/cart_item.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/product.dart';
import 'package:totem/core/extensions.dart'; // Para o helper .toCurrency

class CartItemVariantOption extends Equatable {
  // ✅ NULLABLE: Para pizzas, variant_option_id é null
  final int? variantOptionId;
  // ✅ NOVO: Para pizzas, armazena ID real do OptionItem (sabor, massa, borda)
  final int? optionItemId;
  final int quantity;
  final String name;
  final int price;

  const CartItemVariantOption({
    this.variantOptionId,
    this.optionItemId,
    required this.quantity,
    required this.name,
    required this.price,
  });

  factory CartItemVariantOption.fromJson(Map<String, dynamic> json) {
    return CartItemVariantOption(
      variantOptionId: json['variant_option_id'],
      optionItemId: json['option_item_id'],
      quantity: json['quantity'] ?? 1,
      name: json['name'] ?? '',
      price: _parseMoney(json['price']),
    );
  }

  static int _parseMoney(dynamic value) {
    if (value is int) return value;
    if (value is Map) {
      if (value.containsKey('value')) return (value['value'] as num).toInt();
      if (value.containsKey('amount')) return (value['amount'] as num).toInt();
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'variant_option_id': variantOptionId,
    'option_item_id': optionItemId,
    'quantity': quantity,
    'name': name,
    'price': price,
  };

  // ✅ Helper: Retorna o ID efetivo (variantOptionId ou optionItemId)
  int get effectiveId => variantOptionId ?? optionItemId ?? 0;

  @override
  List<Object?> get props => [
    variantOptionId,
    optionItemId,
    quantity,
    name,
    price,
  ];

  // ✅ IMPORTANTE: toString() retorna o nome para exibição correta
  @override
  String toString() => name;
}

class CartItemVariant extends Equatable {
  // ✅ NULLABLE: Para pizzas, variant_id é null
  final int? variantId;
  // ✅ NOVO: Para pizzas, armazena ID do OptionGroup
  final int? optionGroupId;
  // ✅ NOVO: Armazena o tipo do grupo (TOPPING, CRUST, EDGE, etc)
  final String? groupType;
  final String name;
  final List<CartItemVariantOption> options;

  const CartItemVariant({
    this.variantId,
    this.optionGroupId,
    this.groupType,
    required this.name,
    required this.options,
  });

  factory CartItemVariant.fromJson(Map<String, dynamic> json) {
    return CartItemVariant(
      variantId: json['variant_id'],
      optionGroupId: json['option_group_id'],
      groupType: json['group_type'],
      name: json['name'] ?? '',
      options:
          (json['options'] as List? ?? [])
              .map((optionJson) => CartItemVariantOption.fromJson(optionJson))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'variant_id': variantId,
    'option_group_id': optionGroupId,
    'group_type': groupType,
    'name': name,
    'options': options.map((o) => o.toJson()).toList(),
  };

  // ✅ Helper: Retorna o ID efetivo (variantId ou optionGroupId)
  int get effectiveId => variantId ?? optionGroupId ?? 0;

  @override
  List<Object?> get props => [
    variantId,
    optionGroupId,
    groupType,
    name,
    options,
  ];
}

class CartItem extends Equatable {
  final int id;
  final Product product;
  final int quantity;
  final String? note;
  final List<CartItemVariant> variants;
  final int unitPrice;
  final int totalPrice;
  final String?
  sizeName; // ✅ Para exibir o tamanho escolhido (ex: "Pizza Grande")
  final String? sizeImageUrl; // ✅ NOVO: Imagem do tamanho escolhido

  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    this.note,
    required this.variants,
    required this.unitPrice,
    required this.totalPrice,
    this.sizeName,
    this.sizeImageUrl, // ✅ NOVO
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      product: Product.fromJson(json['product']),
      quantity: json['quantity'],
      note: json['note'],
      variants:
          (json['variants'] as List)
              .map((variantJson) => CartItemVariant.fromJson(variantJson))
              .toList(),
      unitPrice: _parseMoney(json['unit_price']),
      totalPrice: _parseMoney(json['total_price']),
      sizeName: json['size_name'],
      sizeImageUrl: json['size_image_url'],
    );
  }

  static int _parseMoney(dynamic value) {
    if (value is int) return value;
    if (value is Map) {
      if (value.containsKey('value')) return (value['value'] as num).toInt();
      if (value.containsKey('amount')) return (value['amount'] as num).toInt();
    }
    return 0;
  }

  // ✅ CORRIGIDO: Não tenta mais serializar o objeto 'product' inteiro.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': product.id,
      'quantity': quantity,
      'note': note,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'variants': variants.map((variant) => variant.toJson()).toList(),
      'size_name': sizeName,
      'size_image_url': sizeImageUrl, // ✅ NOVO
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
    String? sizeImageUrl,
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
      sizeImageUrl: sizeImageUrl ?? this.sizeImageUrl,
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
      sizeName = null,
      sizeImageUrl = null;

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
  List<Object?> get props => [
    id,
    product,
    quantity,
    note,
    variants,
    unitPrice,
    totalPrice,
    sizeName,
    sizeImageUrl,
  ];

  @override
  String toString() {
    return 'CartItem(id: $id, product: ${product.name}, quantity: $quantity, total: $formattedTotalPrice)';
  }
}
