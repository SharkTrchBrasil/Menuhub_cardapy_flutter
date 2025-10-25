// lib/models/flavor_price.dart

import 'package:equatable/equatable.dart';

class FlavorPrice extends Equatable {
  final int? id;
  final int sizeOptionId; // ID do OptionItem que representa o tamanho
  final int price;
  final bool isAvailable;
  final String? posCode;

  const FlavorPrice({
    this.id,
    required this.sizeOptionId,
    required this.price,
    this.isAvailable = true,
    this.posCode,
  });

  factory FlavorPrice.fromJson(Map<String, dynamic> json) {
    return FlavorPrice(
      id: json['id'],
      sizeOptionId: json['size_option_id'],
      price: json['price'],
      isAvailable: json['is_available'] ?? true,
      posCode: json['pos_code'],
    );
  }

  const FlavorPrice.empty()
      : id = null,
        sizeOptionId = 0,
        price = 0,
        isAvailable = true,
        posCode = null;

  @override
  List<Object?> get props => [id, sizeOptionId, price, isAvailable, posCode];
}