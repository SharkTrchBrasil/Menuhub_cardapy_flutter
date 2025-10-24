// lib/models/kit_component.dart

import 'package:totem/models/product.dart';

class KitComponent {
  final int? id;
  final int productId;
  final int quantity;
  final Product? component;

  KitComponent({
    this.id,
    required this.productId,
    required this.quantity,
    this.component,
  });

  factory KitComponent.empty() {
    return KitComponent(
      id: null,
      productId: 0,
      quantity: 1,
      component: null,
    );
  }

  factory KitComponent.fromJson(Map<String, dynamic> json) {
    return KitComponent(
      id: json['id'] as int?,
      productId: json['product_id'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      component: json['component'] != null
          ? Product.fromJson(json['component'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
    };
  }

  KitComponent copyWith({
    int? id,
    int? productId,
    int? quantity,
    Product? component,
  }) {
    return KitComponent(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      component: component ?? this.component,
    );
  }
}