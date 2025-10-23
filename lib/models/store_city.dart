import 'package:totem/models/store_neig.dart';
import '../widgets/app_selection_form_field.dart';

class StoreCity implements SelectableItem {
  const StoreCity({
    required this.id,
    required this.name,
    required this.deliveryFee,
    required this.isActive,
    this.neighborhoods = const [],
  });

  final int id;
  final String name;
  final int deliveryFee;
  final bool isActive;
  final List<StoreNeighborhood> neighborhoods;

  factory StoreCity.fromJson(Map<String, dynamic> json) {
    return StoreCity(
      id: json['id'] as int,
      name: json['name'] as String,
      deliveryFee: json['delivery_fee'] as int,
      isActive: json['is_active'] as bool? ?? true,
      neighborhoods: (json['neighborhoods'] as List<dynamic>?)
          ?.map((e) => StoreNeighborhood.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }



  @override
  String toString() {
    return 'StoreCity(id: $id, name: $name, deliveryFee: $deliveryFee, isActive: $isActive, neighborhoods: $neighborhoods)';
  }

  @override
  String get title => name;
}
