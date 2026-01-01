// lib/models/option_item.dart
// Modelo OptionItem para o Totem (somente leitura/exibição)
// Alinhado com Backend e Admin

import 'package:equatable/equatable.dart';
import 'package:totem/models/image_model.dart';

class OptionItem extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final int price;
  final bool isActive;
  final int? priority;
  final String? externalCode;
  final int? slices;
  final int? maxFlavors;
  final List<String> tags;
  final ImageModel? image;
  
  // Referência ao OptionItem pai (ex: tamanho)
  final int? parentCustomizationOptionId;
  
  // Preços por tamanho {nome_do_tamanho: preco_em_centavos}
  final Map<String, int>? pricesBySize;
  
  // Campos adicionais
  final bool isIndustrialized;
  final bool? isShared;
  final String? externalProductId;
  
  // ✅ NOVO: Product real vinculado (para tamanhos de pizza - igual ao iFood)
  // No carrinho, este ID deve ser usado como product_id
  final int? linkedProductId;
  
  // ✅ CAMPOS ADICIONAIS DO CATÁLOGO (alinhados com estrutura completa)
  final List<Map<String, dynamic>>? customizationModifiers; // Preços do sabor por tamanho
  final List<Map<String, dynamic>>? statusByCatalog; // Status por catálogo
  final List<Map<String, dynamic>>? priceByCatalog; // Preços por catálogo
  final List<Map<String, dynamic>>? externalCodes; // Códigos externos por catálogo
  final List<int>? fractions; // Número de sabores permitidos (ex: [2] = 2 sabores)
  
  // ✅ IDs reais para combos de pizza (Massa + Borda)
  final int? crustId;
  final int? edgeId;
  final String? crustName;
  final String? edgeName;
  final int? crustPrice; // Centavos
  final int? edgePrice; // Centavos

  const OptionItem({
    this.id,
    required this.name,
    this.description,
    this.price = 0,
    this.isActive = true,
    this.priority,
    this.externalCode,
    this.slices,
    this.maxFlavors,
    this.tags = const [],
    this.image,
    this.parentCustomizationOptionId,
    this.pricesBySize,
    this.isIndustrialized = false,
    this.isShared,
    this.externalProductId,

    this.linkedProductId, // ✅ NOVO
    // ✅ CAMPOS ADICIONAIS DO CATÁLOGO
    this.customizationModifiers,
    this.statusByCatalog,
    this.priceByCatalog,
    this.externalCodes,
    this.fractions,
    this.crustId,
    this.edgeId,
    this.crustName,
    this.edgeName,
    this.crustPrice,
    this.edgePrice,
  });

  /// Retorna o preço para um tamanho específico
  /// Aceita tanto nome (String) quanto ID (int convertido para string)
  int? getPriceForSize(dynamic sizeIdentifier) {
    if (sizeIdentifier == null || pricesBySize == null) {
      return null;
    }
    final key = sizeIdentifier is String ? sizeIdentifier : sizeIdentifier.toString();
    return pricesBySize![key];
  }

  factory OptionItem.fromJson(Map<String, dynamic> json) {
    // Parse de prices_by_size
    Map<String, int>? pricesBySize;
    if (json['prices_by_size'] != null) {
      if (json['prices_by_size'] is Map) {
        pricesBySize = (json['prices_by_size'] as Map).map(
          (key, value) => MapEntry(
            key.toString(),
            value is int ? value : (value as num).toInt(),
          ),
        );
      } else if (json['prices_by_size'] is List) {
        // Formato alternativo: lista de objetos
        pricesBySize = {};
        for (var item in (json['prices_by_size'] as List)) {
          if (item is Map) {
            final sizeName = item['parent_option_name'] as String?;
            final priceValue = item['price'] as int?;
            if (sizeName != null && priceValue != null) {
              pricesBySize[sizeName] = priceValue;
            }
          }
        }
      }
    }

    return OptionItem(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      // Preço pode vir em reais (float) ou centavos (int)
      price: _parsePrice(json['price']),
      isActive: json['is_active'] ?? true,
      priority: json['priority'],
      externalCode: json['external_code'],
      slices: json['slices'],
      maxFlavors: json['max_flavors'],
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((tag) => tag.toString())
          .toList(),
      image: json['image_path'] != null 
          ? ImageModel(url: json['image_path']) 
          : null,
      parentCustomizationOptionId: json['parent_customization_option_id'],
      pricesBySize: pricesBySize,
      isIndustrialized: json['is_industrialized'] ?? false,
      isShared: json['is_shared'],
      externalProductId: json['external_product_id'] ?? json['ifood_product_id'], // Compatibilidade

      linkedProductId: json['linked_product_id'], // ✅ NOVO
      // ✅ CAMPOS ADICIONAIS DO CATÁLOGO
      customizationModifiers: json['customization_modifiers'] != null
          ? (json['customization_modifiers'] as List<dynamic>)
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : null,
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
      externalCodes: json['external_codes'] != null
          ? (json['external_codes'] as List<dynamic>)
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : null,
      fractions: json['fractions'] != null
          ? (json['fractions'] as List<dynamic>)
              .map((item) => item is int ? item : (item as num).toInt())
              .toList()
          : null,
      crustId: json['crust_id'],
      edgeId: json['edge_id'],
      crustName: json['crust_name'],
      edgeName: json['edge_name'],
      crustPrice: json['crust_price'],
      edgePrice: json['edge_price'],
    );
  }

  /// Helper para parsear preço (pode vir em reais ou centavos)
  static int _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) {
      // Se for menor que 1000, provavelmente está em reais
      if (value < 1000) {
        return (value * 100).round();
      }
      return value.round();
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'is_active': isActive,
      'priority': priority,
      'external_code': externalCode,
      'slices': slices,
      'max_flavors': maxFlavors,
      'tags': tags,
      'parent_customization_option_id': parentCustomizationOptionId,
      'prices_by_size': pricesBySize,
      'is_industrialized': isIndustrialized,
      'is_shared': isShared,
      'external_product_id': externalProductId,
      'external_product_id': externalProductId,
      'linked_product_id': linkedProductId, // ✅ NOVO
      'crust_id': crustId,
      'edge_id': edgeId,
      'crust_name': crustName,
      'edge_name': edgeName,
      'crust_price': crustPrice,
      'edge_price': edgePrice,
    };
  }

  OptionItem copyWith({
    int? id,
    String? name,
    String? description,
    int? price,
    bool? isActive,
    int? priority,
    String? externalCode,
    int? slices,
    int? maxFlavors,
    List<String>? tags,
    ImageModel? image,
    bool forceImageToNull = false,
    int? parentCustomizationOptionId,
    Map<String, int>? pricesBySize,
    bool? isIndustrialized,
    bool? isShared,
    String? externalProductId,

    int? linkedProductId, // ✅ NOVO
  }) {
    return OptionItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      externalCode: externalCode ?? this.externalCode,
      slices: slices ?? this.slices,
      maxFlavors: maxFlavors ?? this.maxFlavors,
      tags: tags ?? this.tags,
      image: forceImageToNull ? null : (image ?? this.image),
      parentCustomizationOptionId: parentCustomizationOptionId ?? this.parentCustomizationOptionId,
      pricesBySize: pricesBySize ?? this.pricesBySize,
      isIndustrialized: isIndustrialized ?? this.isIndustrialized,
      isShared: isShared ?? this.isShared,
      externalProductId: externalProductId ?? this.externalProductId,

      linkedProductId: linkedProductId ?? this.linkedProductId, // ✅ NOVO
      // ✅ CAMPOS ADICIONAIS DO CATÁLOGO
      customizationModifiers: customizationModifiers ?? this.customizationModifiers,
      statusByCatalog: statusByCatalog ?? this.statusByCatalog,
      priceByCatalog: priceByCatalog ?? this.priceByCatalog,
      externalCodes: externalCodes ?? this.externalCodes,
      fractions: fractions ?? this.fractions,
      crustId: crustId ?? this.crustId,
      edgeId: edgeId ?? this.edgeId,
      crustName: crustName ?? this.crustName,
      edgeName: edgeName ?? this.edgeName,
      crustPrice: crustPrice ?? this.crustPrice,
      edgePrice: edgePrice ?? this.edgePrice,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    price,
    isActive,
    priority,
    externalCode,
    slices,
    maxFlavors,
    tags,
    image,
    parentCustomizationOptionId,
    pricesBySize,
    isIndustrialized,
    isShared,
    externalProductId,
    isShared,
    externalProductId,
    linkedProductId, // ✅ NOVO
    customizationModifiers,
    statusByCatalog,
    priceByCatalog,
    externalCodes,
    fractions,
    crustId,
    edgeId,
    crustName,
    edgeName,
    crustPrice,
    edgePrice,
  ];

  @override
  String toString() => 'OptionItem(id: $id, name: $name, price: $price, isActive: $isActive)';
}
