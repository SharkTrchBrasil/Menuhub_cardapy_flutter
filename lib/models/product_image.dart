// lib/models/product_image.dart

class ProductImage {
  final int id;
  final String imageUrl;
  final int displayOrder;

  ProductImage({
    required this.id,
    required this.imageUrl,
    required this.displayOrder,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] ?? 0,
      // ✅ O backend envia a URL completa no campo 'image_url'
      imageUrl: json['image_url'] ?? '',
      displayOrder: json['display_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'display_order': displayOrder,
    };
  }
}