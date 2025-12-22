// lib/models/menu/menu_item.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/menu/menu_choice.dart';
import 'package:totem/models/menu/product_info.dart';
import 'package:totem/models/menu/product_tag.dart';

/// Item do menu (produto) no novo formato
class MenuItem extends Equatable {
  final String id; // UUID
  final String code; // UUID
  final String description; // Nome do produto
  final String? details; // Descrição detalhada
  final String? logoUrl;
  final bool needChoices;
  final List<MenuChoice>? choices;
  final double unitPrice;
  final double unitMinPrice;
  final ProductInfo? productInfo;
  final List<ProductTag>? productTags;
  final int? linkedProductId; // ID do produto real vinculado ao tamanho (Pizza)

  const MenuItem({
    required this.id,
    required this.code,
    required this.description,
    this.details,
    this.logoUrl,
    required this.needChoices,
    this.choices,
    required this.unitPrice,
    required this.unitMinPrice,
    this.productInfo,
    this.productTags,
    this.linkedProductId,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final logoUrl = json['logoUrl'] as String?;
    final linkedProductId = json['linkedProductId'] != null 
        ? (json['linkedProductId'] is int 
            ? json['linkedProductId'] as int 
            : int.tryParse(json['linkedProductId'].toString()))
        : null;
    
    return MenuItem(
      id: json['id'] as String,
      code: json['code'] as String,
      description: json['description'] as String,
      details: json['details'] as String?,
      logoUrl: json['logoUrl'] as String?,
      needChoices: json['needChoices'] as bool? ?? false,
      choices: json['choices'] != null
          ? (json['choices'] as List<dynamic>)
              .map((choice) => MenuChoice.fromJson(choice as Map<String, dynamic>))
              .toList()
          : null,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      unitMinPrice: (json['unitMinPrice'] as num?)?.toDouble() ?? 0.0,
      productInfo: json['productInfo'] != null
          ? ProductInfo.fromJson(json['productInfo'] as Map<String, dynamic>)
          : null,
      productTags: json['productTags'] != null
          ? (json['productTags'] as List<dynamic>)
              .map((tag) => ProductTag.fromJson(tag as Map<String, dynamic>))
              .toList()
          : null,
      linkedProductId: linkedProductId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'description': description,
      if (details != null) 'details': details,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'needChoices': needChoices,
      if (choices != null) 'choices': choices!.map((c) => c.toJson()).toList(),
      'unitPrice': unitPrice,
      'unitMinPrice': unitMinPrice,
      if (productInfo != null) 'productInfo': productInfo!.toJson(),
      if (productTags != null) 'productTags': productTags!.map((t) => t.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        code,
        description,
        details,
        logoUrl,
        needChoices,
        choices,
        unitPrice,
        unitMinPrice,
        productInfo,
        productTags,
      ];
}







