import 'charge.dart';
import 'order_product.dart';







class Order {
  Order({
    required this.id,
    required this.sequentialId,
    required this.publicId,
    required this.storeId,

    required this.orderType,
    required this.deliveryType,

    required this.paymentStatus,
    required this.orderStatus,
    required this.charge,
    required this.totemId,
    required this.needsChange,
    required this.changeAmount,

    required this.products,

  });

  final int id;
  final int sequentialId;
  final String publicId;
  final int storeId;


  final String orderType;
  final String deliveryType;
  final String paymentStatus;
  final String orderStatus;
  final Charge? charge;
  final int? totemId;
  final bool needsChange;
  final int? changeAmount;

  final List<OrderProduct> products;


  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      sequentialId: json['sequential_id'],
      publicId: json['public_id'],
      storeId: json['store_id'],


      orderType: json['order_type'],
      deliveryType: json['delivery_type'],
      paymentStatus: json['payment_status'],
      orderStatus: json['order_status'],
      charge: json['charge'] != null ? Charge.fromJson(json['charge']) : null,
      totemId: json['totem_id'],
      needsChange: json['needs_change'] ?? false,
      changeAmount: json['change_amount'],
     // nullable
      products: (json['products'] as List<dynamic>?)
          ?.map<OrderProduct>((c) => OrderProduct.fromJson(c))
          .toList() ?? [],

    );
  }
}
