// lib/models/menu/product_info.dart

import 'package:equatable/equatable.dart';

/// Informações adicionais do produto
class ProductInfo extends Equatable {
  final String id; // UUID
  final String? packaging;
  final int? sequence;
  final int quantity;
  final String unit; // "g", "kg", "L", etc.

  const ProductInfo({
    required this.id,
    this.packaging,
    this.sequence,
    required this.quantity,
    required this.unit,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      id: json['id'] as String,
      packaging: json['packaging'] as String?,
      sequence: json['sequence'] as int?,
      quantity: json['quantity'] as int? ?? 0,
      unit: json['unit'] as String? ?? 'g',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (packaging != null) 'packaging': packaging,
      if (sequence != null) 'sequence': sequence,
      'quantity': quantity,
      'unit': unit,
    };
  }

  @override
  List<Object?> get props => [id, packaging, sequence, quantity, unit];
}












