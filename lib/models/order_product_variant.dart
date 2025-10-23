import 'package:totem/models/order_product_variant_option.dart';

class OrderProductVariant {

  OrderProductVariant({
    required this.id,
    required this.name,
    required this.options,
  });

  final int id;
  final String name;
  final List<OrderProductVariantOption> options;

  factory OrderProductVariant.fromJson(Map<String, dynamic> map) {
    return OrderProductVariant(
      id: map['id'] as int,
      name: map['name'] as String,
      options: map['options'].map<OrderProductVariantOption>((c) => OrderProductVariantOption.fromJson(c)).toList(),
    );
  }

}