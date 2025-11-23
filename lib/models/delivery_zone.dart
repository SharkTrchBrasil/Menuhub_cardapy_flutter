/// Modelo de Zona de Entrega (versão simplificada para Totem)
class DeliveryZoneCheckResponse {
  final int? zoneId;
  final String? zoneName;
  final double baseFee;
  final double? freeDeliveryThreshold;
  final int estimatedMinMinutes;
  final int estimatedMaxMinutes;
  final bool isAvailable;
  final String? message;

  DeliveryZoneCheckResponse({
    this.zoneId,
    this.zoneName,
    this.baseFee = 0.0,
    this.freeDeliveryThreshold,
    this.estimatedMinMinutes = 30,
    this.estimatedMaxMinutes = 60,
    this.isAvailable = false,
    this.message,
  });

  factory DeliveryZoneCheckResponse.fromJson(Map<String, dynamic> json) {
    return DeliveryZoneCheckResponse(
      zoneId: json['zone_id'] as int?,
      zoneName: json['zone_name'] as String?,
      baseFee: (json['base_fee_reais'] as num?)?.toDouble() ?? 0.0,
      freeDeliveryThreshold:
          (json['free_delivery_threshold_reais'] as num?)?.toDouble(),
      estimatedMinMinutes: json['estimated_min_minutes'] as int? ?? 30,
      estimatedMaxMinutes: json['estimated_max_minutes'] as int? ?? 60,
      isAvailable: json['is_available'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  String get estimatedTimeRange =>
      '$estimatedMinMinutes-$estimatedMaxMinutes min';
  
  String get baseFeeFormatted => 'R\$ ${baseFee.toStringAsFixed(2)}';
  
  String get freeDeliveryMessage => freeDeliveryThreshold != null
      ? 'Frete grátis acima de R\$ ${freeDeliveryThreshold!.toStringAsFixed(2)}'
      : '';

  bool isFreeDelivery(double orderTotal) {
    if (freeDeliveryThreshold == null) return false;
    return orderTotal >= freeDeliveryThreshold!;
  }

  double calculateFee(double orderTotal) {
    return isFreeDelivery(orderTotal) ? 0.0 : baseFee;
  }
}
