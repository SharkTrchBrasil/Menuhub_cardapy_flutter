// lib/models/product_category_link.dart

class ProductCategoryLink {
  final int categoryId;
  final int price; // Em centavos
  final bool isOnPromotion;
  final int? promotionalPrice; // Em centavos

  ProductCategoryLink({
    required this.categoryId,
    required this.price,
    required this.isOnPromotion,
    this.promotionalPrice,
  });

  factory ProductCategoryLink.fromJson(Map<String, dynamic> json) {
    return ProductCategoryLink(
      // O backend usa category_id
      categoryId: json['category_id'] ?? 0,
      price: json['price'] ?? 0,
      isOnPromotion: json['is_on_promotion'] ?? false,
      promotionalPrice: json['promotional_price'],
    );
  }
}