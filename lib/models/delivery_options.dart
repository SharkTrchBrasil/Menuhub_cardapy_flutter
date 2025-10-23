class DeliveryOptionsModel {
  final int? id;

  // DELIVERY
  final bool deliveryEnabled;
  final int deliveryEstimatedMin;
  final int deliveryEstimatedMax;
  final double freeShippingMinOrder;
  final double deliveryMinOrder;
  final String?  deliveryScope;

  // PICKUP
  final bool pickupEnabled;
  final int pickupEstimatedMin;
  final int pickupEstimatedMax;

  DeliveryOptionsModel({
    this.id,
    required this.deliveryEnabled,
    required this.deliveryEstimatedMin,
    required this.deliveryEstimatedMax,
    required this.freeShippingMinOrder,
    required this.deliveryMinOrder,
    required this.pickupEnabled,
    this.deliveryScope,
    required this.pickupEstimatedMin,
    required this.pickupEstimatedMax,
  });

  factory DeliveryOptionsModel.fromJson(Map<String, dynamic> json) {
    return DeliveryOptionsModel(
      id: json['id'],
      deliveryEnabled: json['delivery_enabled'] ?? false,
      deliveryEstimatedMin: json['delivery_estimated_min'] ?? 30,
      deliveryEstimatedMax: json['delivery_estimated_max'] ?? 45,
      deliveryScope: json['delivery_scope'],
      freeShippingMinOrder: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      deliveryMinOrder: (json['delivery_min_order'] as num?)?.toDouble() ?? 0.0,
      pickupEnabled: json['pickup_enabled'] ?? false,
      pickupEstimatedMin: json['pickup_estimated_min'] ?? 5,
      pickupEstimatedMax: json['pickup_estimated_max'] ?? 15,
    );
  }
}
