import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:totem/models/product.dart';

class Coupon extends Equatable {
  const Coupon(
     {
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.maxUses,
    required this.used,
    this.maxUsesPerCustomer,
    this.minOrderValue,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.onlyFirstPurchase,
    this.product,



      });

  final int id;
  final String code;
  final String discountType; // 'percentage' ou 'fixed'
  final int discountValue; // percentual ou valor fixo em centavos
  final int? maxUses;
  final int used;
  final int? maxUsesPerCustomer;
  final int? minOrderValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool onlyFirstPurchase;
  final Product? product;

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      discountType: json['discount_type'] as String? ?? 'percentage',
      discountValue: json['discount_value'] as int? ?? 0,
      maxUses: json['max_uses'] as int?,
      used: json['used'] as int? ?? 0,
      maxUsesPerCustomer: json['max_uses_per_customer'] as int?,
      minOrderValue: json['min_order_value'] as int?,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      isActive: json['is_active'] as bool? ?? true,
      onlyFirstPurchase: json['only_first_purchase'] as bool? ?? false,
      product: json['product'] != null ? Product.fromJson(json['product']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discount_type': discountType,
      'discount_value': discountValue,
      'max_uses': maxUses,
      'used': used,
      'max_uses_per_customer': maxUsesPerCustomer,
      'min_order_value': minOrderValue,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      'only_first_purchase': onlyFirstPurchase,
      'product_id': product?.id,
    };
  }

  /// Aplica o desconto com base no tipo
  int apply(int price) {
    if (discountType == 'percentage') {
      return price - (price * discountValue ~/ 100);
    } else if (discountType == 'fixed') {
      return max(0, price - discountValue);
    }
    return price;
  }

  @override
  List<Object?> get props => [id];
}
