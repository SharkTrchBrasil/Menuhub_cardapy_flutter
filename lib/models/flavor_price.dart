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
    // Handle price being int or double (if backend sends decimals)
    final num? priceNum = json['price'];
    int priceInCents = 0;
    if (priceNum != null) {
      if (priceNum is double) {
        // If it's a large double (e.g. 4550.0), assume it's already cents
        if (priceNum > 1000) {
          priceInCents = priceNum.round();
        } else {
          // Small double (e.g. 45.50), assume Reais -> convert to cents
          priceInCents = (priceNum * 100).round();
        }
      } else {
        // If it's int, assume it's already cents
        priceInCents = priceNum.toInt();
      }
    }

    // Handle is_available being bool or int (0/1)
    bool available = true;
    if (json['is_available'] != null) {
      if (json['is_available'] is bool) {
        available = json['is_available'];
      } else if (json['is_available'] is int) {
        available = json['is_available'] == 1;
      }
    }

    return FlavorPrice(
      id: json['id'],
      sizeOptionId: json['size_option_id'],
      price: priceInCents,
      isAvailable: available,
      posCode: json['pos_code'],
    );
  }

  const FlavorPrice.empty()
      : id = null,
        sizeOptionId = 0,
        price = 0,
        isAvailable = true,
        posCode = null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size_option_id': sizeOptionId,
      'price': price,
      'is_available': isAvailable,
      'pos_code': posCode,
    };
  }

  @override
  List<Object?> get props => [id, sizeOptionId, price, isAvailable, posCode];
}