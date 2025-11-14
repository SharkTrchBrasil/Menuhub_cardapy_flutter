import '../widgets/app_selection_form_field.dart';

class StoreNeighborhood  implements SelectableItem {
  const StoreNeighborhood({
    this.id,
    required this.name,
    this.cityId,
    this.deliveryFee = 0,
    this.freeDelivery = false,
    this.isActive = true,
    this.latitude,
    this.longitude,
  });

  final int? id;
  final String name;
  final int? cityId;
  final double deliveryFee;
  final bool freeDelivery;
  final bool isActive;
  final double? latitude;
  final double? longitude;

  factory StoreNeighborhood.fromJson(Map<String, dynamic> json) {
    // delivery_fee pode ser int ou double, converter para double
    final fee = json['delivery_fee'];
    double deliveryFeeDouble = 0;
    if (fee is int) {
      deliveryFeeDouble = fee.toDouble();
    } else if (fee is double) {
      deliveryFeeDouble = fee;
    }

    return StoreNeighborhood(
      id: json['id'] as int?,
      name: json['name'] as String,
      cityId: json['city_id'] as int?,
      deliveryFee: deliveryFeeDouble,
      freeDelivery: json['free_delivery'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'city_id': cityId,
      'delivery_fee': deliveryFee,
      'free_delivery': freeDelivery,
      'is_active': isActive,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  StoreNeighborhood copyWith({
    int? id,
    String? name,
    int? cityId,
    double? deliveryFee,
    bool? freeDelivery,
    bool? isActive,
    double? Function()? latitude,
    double? Function()? longitude,
  }) {
    return StoreNeighborhood(
      id: id ?? this.id,
      name: name ?? this.name,
      cityId: cityId ?? this.cityId,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      freeDelivery: freeDelivery ?? this.freeDelivery,
      isActive: isActive ?? this.isActive,
      latitude: latitude != null ? latitude() : this.latitude,
      longitude: longitude != null ? longitude() : this.longitude,
    );
  }

  @override
  String toString() {
    return 'StoreNeighborhood(id: $id, name: $name, deliveryFee: $deliveryFee, freeDelivery: $freeDelivery, isActive: $isActive, cityId: $cityId, latitude: $latitude, longitude: $longitude)';
  }

  @override
  String get title => name;
}
