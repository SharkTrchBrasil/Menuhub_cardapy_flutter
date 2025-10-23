// lib/models/flavor_price.dart

class FlavorPrice {
  final int sizeOptionId;
  final int price; // Em centavos

  FlavorPrice({
    required this.sizeOptionId,
    required this.price,
  });

  factory FlavorPrice.fromJson(Map<String, dynamic> json) {
    return FlavorPrice(
      sizeOptionId: json['size_option_id'] ?? 0,
      price: json['price'] ?? 0,
    );
  }
}