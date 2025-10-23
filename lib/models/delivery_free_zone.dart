class DeliveryFeeZone {
  final int? cityId;
  final int? neighborhoodId;
  final double fee;

  DeliveryFeeZone({
    this.cityId,
    this.neighborhoodId,
    required this.fee,
  });

  factory DeliveryFeeZone.fromJson(Map<String, dynamic> json) => DeliveryFeeZone(
    cityId: json['city_id'],
    neighborhoodId: json['neighborhood_id'],
    fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
  );
}
