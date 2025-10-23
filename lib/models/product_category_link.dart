// lib/models/product_category_link.dart

import 'package:totem/models/category.dart';

/// Representa o vínculo entre um produto e uma categoria,
/// permitindo preços diferentes por categoria.
///
/// Exemplo: Uma pizza pode custar R$ 45 na categoria "Pizzas Tradicionais"
/// e R$ 52 na categoria "Pizzas Premium".
class ProductCategoryLink {
  final int? id;
  final int productId;
  final int categoryId;
  final int price;
  final bool available;
  final int? priority;
  final Category? category; // Opcional: dados completos da categoria

  ProductCategoryLink({
    this.id,
    required this.productId,
    required this.categoryId,
    required this.price,
    this.available = true,
    this.priority,
    this.category,
  });

  // ✅ FACTORY CONSTRUCTOR VAZIO
  factory ProductCategoryLink.empty() {
    return ProductCategoryLink(
      id: null,
      productId: 0,
      categoryId: 0,
      price: 0,
      available: true,
      priority: null,
      category: null,
    );
  }

  // ✅ FROM JSON
  factory ProductCategoryLink.fromJson(Map<String, dynamic> json) {
    return ProductCategoryLink(
      id: json['id'] as int?,
      productId: json['product_id'] as int? ?? 0,
      categoryId: json['category_id'] as int? ?? 0,
      price: json['price'] as int? ?? 0,
      available: json['available'] as bool? ?? true,
      priority: json['priority'] as int?,
      category: json['category'] != null
          ? Category.fromJson(json['category'] as Map<String, dynamic>)
          : null,
    );
  }

  // ✅ TO JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'category_id': categoryId,
      'price': price,
      'available': available,
      'priority': priority,
      // Não incluímos 'category' aqui pois é apenas para leitura
    };
  }

  // ✅ COPYWITH
  ProductCategoryLink copyWith({
    int? id,
    int? productId,
    int? categoryId,
    int? price,
    bool? available,
    int? priority,
    Category? category,
  }) {
    return ProductCategoryLink(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      available: available ?? this.available,
      priority: priority ?? this.priority,
      category: category ?? this.category,
    );
  }

  // ✅ HELPER: Formata o preço
  String get formattedPrice {
    return 'R\$ ${(price / 100).toStringAsFixed(2)}';
  }

  @override
  String toString() {
    return 'ProductCategoryLink(id: $id, productId: $productId, categoryId: $categoryId, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductCategoryLink &&
        other.id == id &&
        other.productId == productId &&
        other.categoryId == categoryId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ productId.hashCode ^ categoryId.hashCode;
  }
}