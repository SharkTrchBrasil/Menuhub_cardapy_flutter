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
  
  // ✅ Metadados ocultos para reconstruir IDs de combos (Pizza)
  final int? crustId;
  final int? edgeId;
  final String? crustName;
  final String? edgeName;
  final double? crustPrice; // Em reais
  final double? edgePrice; // Em reais

  const GarnishItem({
    required this.id,
    required this.code,
    required this.description,
    this.details,
    this.logoUrl,
    required this.unitPrice,
    this.crustId,
    this.edgeId,
    this.crustName,
    this.edgeName,
    this.crustPrice,
    this.edgePrice,
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
      // ✅ Lê IDs ocultos enviados pelo backend
      crustId: json['_crust_id'] as int?,
      edgeId: json['_edge_id'] as int?,
      crustName: json['_crust_name'] as String?,
      edgeName: json['_edge_name'] as String?,
      crustPrice: (json['_crust_price'] as num?)?.toDouble(),
      edgePrice: (json['_edge_price'] as num?)?.toDouble(),
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
      if (crustId != null) '_crust_id': crustId,
      if (edgeId != null) '_edge_id': edgeId,
      if (crustName != null) '_crust_name': crustName,
      if (edgeName != null) '_edge_name': edgeName,
      if (crustPrice != null) '_crust_price': crustPrice,
      if (edgePrice != null) '_edge_price': edgePrice,
    };
  }

  @override
  List<Object?> get props => [id, code, description, details, logoUrl, unitPrice];
}







