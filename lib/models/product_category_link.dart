// lib/models/product_category_link.dart

import 'package:equatable/equatable.dart';

class ProductCategoryLink extends Equatable {
  final int productId;
  final int categoryId;
  final int price;
  final bool isAvailable;
  final bool isOnPromotion;
  final int? promotionalPrice;

  const ProductCategoryLink({
    required this.productId,
    required this.categoryId,
    required this.price,
    this.isAvailable = true,
    this.isOnPromotion = false,
    this.promotionalPrice,
  });

  factory ProductCategoryLink.fromJson(Map<String, dynamic> json) {
    return ProductCategoryLink(
      productId: json['product_id'],
      categoryId: json['category_id'],
      price: json['price'] ?? 0,
      isAvailable: json['is_available'] ?? true,
      isOnPromotion: json['is_on_promotion'] ?? false,
      promotionalPrice: json['promotional_price'],
    );
  }

  @override
  List<Object?> get props => [
    productId,
    categoryId,
    price,
    isAvailable,
    isOnPromotion,
    promotionalPrice
  ];
}