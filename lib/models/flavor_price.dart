// lib/models/flavor_price.dart

import 'package:equatable/equatable.dart';

class FlavorPrice extends Equatable {
  final int? id;
  final int sizeOptionId; // ID do OptionItem que representa o tamanho
  final String? sizeOptionName; // Nome do tamanho (ex: "Pequena", "Média", "Grande")
  final String? sizeOptionImagePath; // Imagem do tamanho
  final int price;
  final bool isAvailable;
  final String? posCode;
  // ✅ CAMPOS ADICIONAIS DE ALTA PRIORIDADE (alinhados com APIs externas)
  final List<Map<String, dynamic>>? statusByCatalog; // Status por catálogo
  final List<Map<String, dynamic>>? priceByCatalog; // Preços por catálogo
  final List<Map<String, dynamic>>? externalCodeByCatalog; // Códigos externos por catálogo

  const FlavorPrice({
    this.id,
    required this.sizeOptionId,
    this.sizeOptionName,
    this.sizeOptionImagePath,
    required this.price,
    this.isAvailable = true,
    this.posCode,
    // ✅ CAMPOS ADICIONAIS
    this.statusByCatalog,
    this.priceByCatalog,
    this.externalCodeByCatalog,
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
      sizeOptionName: json['size_option_name'],
      sizeOptionImagePath: json['size_option_image_path'],
      price: priceInCents,
      isAvailable: available,
      posCode: json['pos_code'],
      // ✅ CAMPOS ADICIONAIS DO CATÁLOGO
      statusByCatalog: json['status_by_catalog'] != null
          ? (json['status_by_catalog'] as List<dynamic>)
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : null,
      priceByCatalog: json['price_by_catalog'] != null
          ? (json['price_by_catalog'] as List<dynamic>)
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : null,
      externalCodeByCatalog: json['external_code_by_catalog'] != null
          ? (json['external_code_by_catalog'] as List<dynamic>)
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : null,
    );
  }

  const FlavorPrice.empty()
      : id = null,
        sizeOptionId = 0,
        sizeOptionName = null,
        sizeOptionImagePath = null,
        price = 0,
        isAvailable = true,
        posCode = null,
        statusByCatalog = null,
        priceByCatalog = null,
        externalCodeByCatalog = null;

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
  List<Object?> get props => [
    id, sizeOptionId, sizeOptionName, sizeOptionImagePath, price, isAvailable, posCode,
    statusByCatalog, priceByCatalog, externalCodeByCatalog, // ✅ NOVO
  ];
}