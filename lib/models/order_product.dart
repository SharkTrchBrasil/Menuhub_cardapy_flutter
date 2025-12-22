
import 'package:totem/models/order_product_ticket.dart';
import 'package:totem/models/order_product_variant.dart';

class OrderProductOption {
  final int? id;
  final String name;
  final int quantity;
  final int price;

  OrderProductOption({
    this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderProductOption.fromJson(Map<String, dynamic> map) {
    return OrderProductOption(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 1,
      price: map['price'] as int? ?? 0,
    );
  }
}

class OrderProduct {

  OrderProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.variants,
    required this.discountedPrice,
    this.imageUrl,
    this.options,
    this.observations,
  });

  final int id;
  final String name;
  final int quantity;
  final List<OrderProductVariant> variants;
  final int discountedPrice;
  
  // ✅ NOVOS CAMPOS
  final String? imageUrl;
  final List<OrderProductOption>? options;
  final String? observations;
  
  /// Preço total do produto (alias para discountedPrice)
  int get price => discountedPrice;

  factory OrderProduct.fromJson(Map<String, dynamic> map) {
    // Parse options de diferentes fontes
    List<OrderProductOption>? parsedOptions;
    
    // Tenta pegar de 'options' ou de 'variants'
    if (map['options'] != null && map['options'] is List) {
      parsedOptions = (map['options'] as List)
          .map<OrderProductOption>((c) => OrderProductOption.fromJson(c))
          .toList();
    }
    
    return OrderProduct(
      id: map['id'] as int,
      name: map['name'] as String,
      quantity: map['quantity'] as int,
      variants: map['variants'] != null 
          ? (map['variants'] as List).map<OrderProductVariant>((c) => OrderProductVariant.fromJson(c)).toList()
          : [],
      discountedPrice: map['price'] ?? map['discounted_price'] ?? 0,
      imageUrl: map['image_url'] as String? ?? map['image'] as String?,
      options: parsedOptions,
      observations: map['observations'] as String? ?? map['notes'] as String?,
    );
  }

}