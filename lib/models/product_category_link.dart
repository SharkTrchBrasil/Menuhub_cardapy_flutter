// lib/models/product_category_link.dart
// Modelo ProductCategoryLink para o Totem (somente leitura/exibição)
// Alinhado com Backend e Admin

import 'package:equatable/equatable.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/models/availability_model.dart';

class ProductCategoryLink extends Equatable {
  final int? productId;
  final int categoryId;

  // Preços
  final int price;
  final int? costPrice;
  final bool isOnPromotion;
  final int? promotionalPrice;

  // Disponibilidade
  final bool isAvailable;
  final bool isFeatured;
  final int displayOrder;
  final String? posCode;

  // Disponibilidade por horário
  final AvailabilityType availabilityType;
  final List<ScheduleRule> schedules;

  const ProductCategoryLink({
    this.productId,
    required this.categoryId,
    required this.price,
    this.costPrice,
    this.isOnPromotion = false,
    this.promotionalPrice,
    this.isAvailable = true,
    this.isFeatured = false,
    this.displayOrder = 0,
    this.posCode,
    this.availabilityType = AvailabilityType.always,
    this.schedules = const [],
  });

  /// ✅ Verifica se o produto está em promoção (flag E preço promocional menor que original)
  bool get hasPromotion {
    return isOnPromotion &&
        promotionalPrice != null &&
        promotionalPrice! > 0 &&
        promotionalPrice! < price;
  }

  /// ✅ Retorna o preço efetivo (promocional ou normal)
  int get effectivePrice {
    if (hasPromotion) {
      return promotionalPrice!; // preço com desconto
    }
    return price; // preço original sem desconto
  }

  /// ✅ Retorna o preço original (quando há promoção)
  int? get originalPrice {
    return hasPromotion ? price : null;
  }

  /// ✅ Calcula percentual de desconto
  double? get discountPercentage {
    if (!hasPromotion) return null;
    return ((price - promotionalPrice!) / price) * 100;
  }

  static int _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is Map) {
      final amount = value['amount'] ?? value['value'];
      if (amount is num) return amount.toInt();
      if (amount is String) {
        return double.tryParse(amount)?.toInt() ?? 0;
      }
    }
    if (value is String) return double.tryParse(value)?.toInt() ?? 0;
    return 0;
  }

  factory ProductCategoryLink.fromJson(Map<String, dynamic> json) {
    return ProductCategoryLink(
      productId: json['product_id'],
      categoryId: json['category_id'] ?? 0,
      price: _parsePrice(json['price']),
      costPrice:
          json['cost_price'] != null ? _parsePrice(json['cost_price']) : null,
      isOnPromotion: json['is_on_promotion'] ?? false,
      promotionalPrice:
          json['promotional_price'] != null
              ? _parsePrice(json['promotional_price'])
              : null,
      isAvailable: json['is_available'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      displayOrder: json['display_order'] ?? 0,
      posCode: json['pos_code'],
      availabilityType:
          json['availability_type'] != null
              ? AvailabilityType.values.firstWhere(
                (e) =>
                    e.toString().split('.').last.toUpperCase() ==
                    (json['availability_type'] as String).toUpperCase(),
                orElse: () => AvailabilityType.always,
              )
              : AvailabilityType.always,
      schedules:
          json['schedules'] != null
              ? (json['schedules'] as List<dynamic>)
                  .map((s) => ScheduleRule.fromJson(s as Map<String, dynamic>))
                  .toList()
              : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'category_id': categoryId,
      'price': price,
      'cost_price': costPrice,
      'is_on_promotion': isOnPromotion,
      'promotional_price': promotionalPrice,
      'is_available': isAvailable,
      'is_featured': isFeatured,
      'display_order': displayOrder,
      'pos_code': posCode,
      'availability_type': availabilityType.toString().split('.').last,
      'schedules': schedules.map((s) => s.toJson()).toList(),
    };
  }

  ProductCategoryLink copyWith({
    int? productId,
    int? categoryId,
    int? price,
    int? costPrice,
    bool? isOnPromotion,
    int? promotionalPrice,
    bool? isAvailable,
    bool? isFeatured,
    int? displayOrder,
    String? posCode,
    AvailabilityType? availabilityType,
    List<ScheduleRule>? schedules,
  }) {
    return ProductCategoryLink(
      productId: productId ?? this.productId,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      isOnPromotion: isOnPromotion ?? this.isOnPromotion,
      promotionalPrice: promotionalPrice ?? this.promotionalPrice,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      displayOrder: displayOrder ?? this.displayOrder,
      posCode: posCode ?? this.posCode,
      availabilityType: availabilityType ?? this.availabilityType,
      schedules: schedules ?? this.schedules,
    );
  }

  @override
  List<Object?> get props => [
    productId,
    categoryId,
    price,
    costPrice,
    isOnPromotion,
    promotionalPrice,
    isAvailable,
    isFeatured,
    displayOrder,
    posCode,
    availabilityType,
    schedules,
  ];

  @override
  String toString() =>
      'ProductCategoryLink(productId: $productId, categoryId: $categoryId, price: $price)';
}
