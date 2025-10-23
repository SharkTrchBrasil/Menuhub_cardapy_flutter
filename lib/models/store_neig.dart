import '../widgets/app_selection_form_field.dart';

class StoreNeighborhood  implements SelectableItem {
  const StoreNeighborhood({
    this.id,
    required this.name,
    this.cityId,
    this.deliveryFee = 0,
    this.freeDelivery = false,
    this.isActive = true,
  });

  final int? id;
  final String name;
  final int? cityId;
  final double deliveryFee;
  final bool freeDelivery;
  final bool isActive;

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
    };
  }



  StoreNeighborhood copyWith({
    int? id,
    String? name,
    int? cityId,
    double? deliveryFee,
    bool? freeDelivery,
    bool? isActive,
  }) {
    return StoreNeighborhood(
      id: id ?? this.id,
      name: name ?? this.name,
      cityId: cityId ?? this.cityId,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      freeDelivery: freeDelivery ?? this.freeDelivery,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'StoreNeighborhood(id: $id, name: $name, deliveryFee: $deliveryFee, freeDelivery: $freeDelivery, isActive: $isActive, cityId: $cityId)';
  }


  @override
  String get title => name;
}
