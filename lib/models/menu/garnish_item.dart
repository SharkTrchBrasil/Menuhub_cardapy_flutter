// lib/models/menu/garnish_item.dart

import 'package:equatable/equatable.dart';

/// Item de escolha (opção) dentro de um grupo (ex: "1/2 Catupiry", "Massa Tradicional + Borda Cheddar")
class GarnishItem extends Equatable {
  final String id; // UUID
  final String code; // UUID
  final String description; // Nome da opção
  final String? details; // Descrição detalhada
  final String? logoUrl; // Caminho da imagem (file_key)
  final double unitPrice; // Preço adicional (em reais)

  const GarnishItem({
    required this.id,
    required this.code,
    required this.description,
    this.details,
    this.logoUrl,
    required this.unitPrice,
  });

  factory GarnishItem.fromJson(Map<String, dynamic> json) {
    final unitPrice = (json['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final description = json['description'] as String;
    
    return GarnishItem(
      id: json['id'] as String,
      code: json['code'] as String,
      description: description,
      details: json['details'] as String?,
      logoUrl: json['logoUrl'] as String?,
      unitPrice: unitPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'description': description,
      if (details != null) 'details': details,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'unitPrice': unitPrice,
    };
  }

  @override
  List<Object?> get props => [id, code, description, details, logoUrl, unitPrice];
}







