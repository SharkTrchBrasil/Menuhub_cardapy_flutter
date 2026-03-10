class DeliveryOptionsModel {
  final int? id;

  // DELIVERY
  final bool deliveryEnabled;
  final int deliveryPrepMin;
  final int deliveryPrepMax;
  final double freeDeliveryThreshold;
  final double minOrderValue;
  final String? deliveryScope;

  // PICKUP
  final bool pickupEnabled;
  final int pickupEstimatedMin;
  final int pickupEstimatedMax;

  static double _parseMoney(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is Map) {
      final raw = value['value'] ?? value['amount'];
      if (raw is num) {
        return raw.toDouble() / 100.0;
      }
    }
    return 0.0;
  }

  DeliveryOptionsModel({
    this.id,
    required this.deliveryEnabled,
    required this.deliveryPrepMin,
    required this.deliveryPrepMax,
    required this.freeDeliveryThreshold,
    required this.minOrderValue,
    required this.pickupEnabled,
    this.deliveryScope,
    required this.pickupEstimatedMin,
    required this.pickupEstimatedMax,
  });

  factory DeliveryOptionsModel.fromJson(Map<String, dynamic> json) {
    return DeliveryOptionsModel(
      id: json['id'],
      deliveryEnabled: json['delivery_enabled'] ?? false,
      deliveryPrepMin: json['delivery_prep_min'] ?? 30,
      deliveryPrepMax: json['delivery_prep_max'] ?? 45,
      deliveryScope: json['delivery_scope'],
      freeDeliveryThreshold: _parseMoney(json['free_delivery_threshold']),
      minOrderValue: _parseMoney(json['min_order_value']),
      pickupEnabled: json['pickup_enabled'] ?? false,
      pickupEstimatedMin: json['pickup_estimated_min'] ?? 5,
      pickupEstimatedMax: json['pickup_estimated_max'] ?? 15,
    );
  }
}
