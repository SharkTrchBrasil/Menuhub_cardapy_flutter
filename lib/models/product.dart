// lib/models/product.dart
// Modelo Product simplificado para o Totem (somente leitura/exibição)
// Alinhado com Backend e Admin

import 'package:equatable/equatable.dart';
import 'package:totem/models/product_variant_link.dart';
import 'package:totem/models/flavor_price.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/models/availability_model.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/helpers/enums/product_status.dart';
import 'package:totem/helpers/enums/product_type.dart';
import 'package:totem/models/product_category_link.dart';

/// Enum para unidade de medida do produto
enum ProductUnit {
  /// Unidade padrão (quantidade inteira)
  UNIT,
  /// Quilograma (peso decimal)
  KG,
  /// Litro (volume decimal)
  L,
  /// Grama
  G,
  /// Mililitro
  ML;

  /// Converte string da API para ProductUnit
  static ProductUnit fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'KG':
        return ProductUnit.KG;
      case 'L':
        return ProductUnit.L;
      case 'G':
        return ProductUnit.G;
      case 'ML':
        return ProductUnit.ML;
      case 'UNIT':
      case 'UNIDADE':
      default:
        return ProductUnit.UNIT;
    }
  }

  /// Retorna o nome de exibição da unidade
  String get displayName {
    switch (this) {
      case ProductUnit.UNIT:
        return 'un';
      case ProductUnit.KG:
        return 'kg';
      case ProductUnit.L:
        return 'L';
      case ProductUnit.G:
        return 'g';
      case ProductUnit.ML:
        return 'ml';
    }
  }

  /// Verifica se a unidade requer entrada decimal (peso/volume)
  bool get requiresQuantityInput {
    return this == ProductUnit.KG || this == ProductUnit.L;
  }
}

class Product extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final ProductStatus status;
  
  // Identificadores externos
  final String? ean;
  final String? externalCode;
  
  // Estoque
  final int stockQuantity;
  final bool controlStock;
  final int minStock;
  final int maxStock;
  
  // Atributos
  final ProductUnit unit;
  final int priority;
  final bool featured;
  final int storeId;
  final int? servesUpTo;
  final int? weight;
  final int soldCount;
  
  // Vínculos
  final List<ProductVariantLink> variantLinks;
  final List<ProductCategoryLink> categoryLinks;
  
  // Preços
  final int? price;
  final int? costPrice;
  final bool isOnPromotion;
  final int? promotionalPrice;
  final int? primaryCategoryId;
  final bool hasMultiplePrices;
  
  // Tipo do produto
  final ProductType productType;
  
  // Tags dietéticas
  final List<String> dietaryTags;
  final List<String> beverageTags;
  
  // Preços por tamanho (para sabores de pizza)
  final List<FlavorPrice> prices;
  
  // Imagens
  final List<ImageModel> images;
  final String? videoUrl;
  
  // Disponibilidade
  final AvailabilityType availabilityType;
  final List<ScheduleRule> schedules;
  
  // Campos de mercado/farmácia
  final String? packaging;
  final int? quantity;
  final int? sellingMinimum;
  final int? sellingIncremental;
  final int? averageUnit;
  
  // Campos adicionais
  final bool isIndustrialized;
  final String? externalItemId;
  final String? externalProductId;
  final String? availabilityStatus; // AVAILABLE/UNAVAILABLE
  final String? stockStatus; // IN_STOCK/OUT_OF_STOCK/UNLIMITED
  final bool hasViolation;
  final bool canEdit;
  final String? violationCheckState;
  final int sellingRank;
  final List<String> promotionTags;
  final List<String> classification;
  
  // ✅ CAMPOS ADICIONAIS DO CATÁLOGO (alinhados com estrutura completa)
  final String? availability;       // ALWAYS, SCHEDULED, etc
  final Map<String, dynamic>? problems; // Problemas do produto
  final String? productEan;          // Código EAN do produto (alias de ean)
  final int sequence;                // Ordem de exibição (alias de priority)
  final Map<String, dynamic>? violation; // Detalhes da violação
  final List<Map<String, dynamic>> extensions; // Extensões do produto
  final bool suggestedCombo;         // Se é um combo sugerido
  final Map<String, dynamic>? itemPrice; // Preço do item
  final bool available;              // Se o produto está disponível
  final List<Map<String, dynamic>>? statusByCatalog; // Status por catálogo
  final List<Map<String, dynamic>>? externalCodes; // Códigos externos por catálogo
  
  // Cashback
  final String? cashbackType;
  final int cashbackValue;
  
  // Master product (para produtos variantes)
  final int? masterProductId;

  // ✅ Linked product (para tamanhos de pizza que são OptionItems mas têm produto vinculado)
  final int? linkedProductId;

  const Product({
    this.id,
    this.name = '',
    this.description,
    this.status = ProductStatus.ACTIVE,
    this.ean,
    this.externalCode,
    this.stockQuantity = 0,
    this.controlStock = false,
    this.minStock = 0,
    this.maxStock = 0,
    this.unit = ProductUnit.UNIT,
    this.priority = 0,
    this.featured = false,
    this.storeId = 0,
    this.servesUpTo,
    this.weight,
    this.soldCount = 0,
    this.variantLinks = const [],
    this.categoryLinks = const [],
    this.price,
    this.costPrice,
    this.isOnPromotion = false,
    this.promotionalPrice,
    this.primaryCategoryId,
    this.hasMultiplePrices = false,
    this.productType = ProductType.INDIVIDUAL,
    this.dietaryTags = const [],
    this.beverageTags = const [],
    this.prices = const [],
    this.images = const [],
    this.videoUrl,
    this.availabilityType = AvailabilityType.always,
    this.schedules = const [],
    this.packaging,
    this.quantity,
    this.sellingMinimum,
    this.sellingIncremental,
    this.averageUnit,
    this.isIndustrialized = false,
    this.externalItemId,
    this.externalProductId,
    this.availabilityStatus,
    this.stockStatus,
    this.hasViolation = false,
    this.canEdit = true,
    this.violationCheckState,
    this.sellingRank = 0,
    this.promotionTags = const [],
    this.classification = const [],
    this.availability,
    this.problems,
    this.productEan,
    this.sequence = 0,
    this.violation,
    this.extensions = const [],
    this.suggestedCombo = false,
    this.itemPrice,
    this.available = true,
    this.statusByCatalog,
    this.externalCodes,
    this.cashbackType,
    this.cashbackValue = 0,
    this.masterProductId,
    this.linkedProductId,
  });

  /// Construtor para instância vazia
  const Product.empty()
      : id = null,
        name = '',
        description = null,
        status = ProductStatus.ACTIVE,
        ean = null,
        externalCode = null,
        stockQuantity = 0,
        controlStock = false,
        minStock = 0,
        maxStock = 0,
        unit = ProductUnit.UNIT,
        priority = 0,
        featured = false,
        storeId = 0,
        servesUpTo = null,
        weight = null,
        soldCount = 0,
        variantLinks = const [],
        categoryLinks = const [],
        price = null,
        costPrice = null,
        isOnPromotion = false,
        promotionalPrice = null,
        primaryCategoryId = null,
        hasMultiplePrices = false,
        productType = ProductType.INDIVIDUAL,
        dietaryTags = const [],
        beverageTags = const [],
        prices = const [],
        images = const [],
        videoUrl = null,
        availabilityType = AvailabilityType.always,
        schedules = const [],
        packaging = null,
        quantity = null,
        sellingMinimum = null,
        sellingIncremental = null,
        averageUnit = null,
        isIndustrialized = false,
        externalItemId = null,
        externalProductId = null,
        availabilityStatus = null,
        stockStatus = null,
        hasViolation = false,
        canEdit = true,
        violationCheckState = null,
        sellingRank = 0,
        promotionTags = const [],
        classification = const [],
        availability = null,
        problems = null,
        productEan = null,
        sequence = 0,
        violation = null,
        extensions = const [],
        suggestedCombo = false,
        itemPrice = null,
        available = true,
        statusByCatalog = null,
        externalCodes = null,
        cashbackType = null,
        cashbackValue = 0,
        masterProductId = null,
        linkedProductId = null;

  /// Getter para primeira imagem (imagem principal)
  ImageModel? get primaryImage => images.isNotEmpty ? images.first : null;
  
  /// Getter para URL da imagem principal
  String? get imageUrl => primaryImage?.url;

  /// Verifica se o produto está disponível para venda
  bool get isAvailable {
    if (status != ProductStatus.ACTIVE) return false;
    if (controlStock && stockQuantity <= 0) return false;
    return true;
  }

  /// Retorna o preço efetivo (promocional ou normal)
  int get effectivePrice {
    if (isOnPromotion && promotionalPrice != null) {
      return promotionalPrice!;
    }
    return price ?? 0;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      status: ProductStatus.fromString(json['status']),
      ean: json['ean'],
      externalCode: json['external_code'],
      stockQuantity: json['stock_quantity'] ?? 0,
      controlStock: json['control_stock'] ?? false,
      minStock: json['min_stock'] ?? 0,
      maxStock: json['max_stock'] ?? 0,
      unit: ProductUnit.fromString(json['unit']),
      priority: json['priority'] ?? 0,
      featured: json['featured'] ?? false,
      storeId: json['store_id'] ?? 0,
      servesUpTo: json['serves_up_to'],
      weight: json['weight'],
      soldCount: json['sold_count'] ?? 0,
      productType: ProductType.fromString(json['product_type']),
      price: json['price'],
      costPrice: json['cost_price'],
      isOnPromotion: json['is_on_promotion'] ?? false,
      promotionalPrice: json['promotional_price'],
      primaryCategoryId: json['primary_category_id'],
      hasMultiplePrices: json['has_multiple_prices'] ?? false,
      
      // Parse de listas
      variantLinks: (json['variant_links'] as List<dynamic>? ?? [])
          .map((link) => ProductVariantLink.fromJson(link))
          .toList(),
      categoryLinks: (json['category_links'] as List<dynamic>? ?? [])
          .map((link) => ProductCategoryLink.fromJson(link))
          .toList(),
      prices: (json['prices'] as List<dynamic>? ?? [])
          .map((p) => FlavorPrice.fromJson(p))
          .toList(),
      images: (json['gallery_images'] as List<dynamic>? ?? [])
          .map((imgJson) => ImageModel.fromJson(imgJson))
          .toList(),
      
      // Tags
      dietaryTags: (json['dietary_tags'] as List<dynamic>? ?? [])
          .map((tag) => tag.toString())
          .toList(),
      beverageTags: (json['beverage_tags'] as List<dynamic>? ?? [])
          .map((tag) => tag.toString())
          .toList(),
      
      // Vídeo
      videoUrl: json['video_url'],
      
      // Disponibilidade
      availabilityType: json['availability_type'] == 'SCHEDULED'
          ? AvailabilityType.scheduled
          : AvailabilityType.always,
      schedules: (json['schedules'] as List<dynamic>? ?? [])
          .map((s) => ScheduleRule.fromJson(s))
          .toList(),
      
      // Mercado/Farmácia
      packaging: json['packaging'],
      quantity: json['quantity'],
      sellingMinimum: json['selling_minimum'],
      sellingIncremental: json['selling_incremental'],
      averageUnit: json['average_unit'],
      
      // Campos adicionais
      isIndustrialized: json['is_industrialized'] ?? false,
      externalItemId: json['external_item_id'],
      externalProductId: json['external_product_id'],
      availabilityStatus: json['availability_status'],
      stockStatus: json['stock_status'],
      hasViolation: json['has_violation'] ?? false,
      canEdit: json['can_edit'] ?? true,
      violationCheckState: json['violation_check_state'],
      sellingRank: json['selling_rank'] ?? 0,
      promotionTags: (json['promotion_tags'] as List<dynamic>?)
          ?.map((tag) => tag.toString())
          .toList() ?? const [],
      classification: (json['classification'] as List<dynamic>?)
          ?.map((c) => c.toString())
          .toList() ?? const [],
      // ✅ CAMPOS ADICIONAIS DO CATÁLOGO
      availability: json['availability'],
      problems: json['problems'] != null ? Map<String, dynamic>.from(json['problems']) : null,
      productEan: json['product_ean'] ?? json['ean'], // Fallback para ean
      sequence: json['sequence'] ?? json['priority'] ?? 0, // Fallback para priority
      violation: json['violation'] != null ? Map<String, dynamic>.from(json['violation']) : null,
      extensions: (json['extensions'] as List<dynamic>? ?? [])
          .map((ext) => Map<String, dynamic>.from(ext))
          .toList(),
      suggestedCombo: json['suggested_combo'] ?? false,
      itemPrice: json['item_price'] != null ? Map<String, dynamic>.from(json['item_price']) : null,
      available: json['available'] ?? (json['status'] == 'ACTIVE' || json['status'] == 'AVAILABLE'),
      statusByCatalog: json['status_by_catalog'] != null 
          ? (json['status_by_catalog'] as List<dynamic>)
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : null,
      externalCodes: json['external_codes'] != null
          ? (json['external_codes'] as List<dynamic>)
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : null,
      cashbackType: json['cashback_type'],
      cashbackValue: json['cashback_value'] ?? 0,
      masterProductId: json['master_product_id'],
      linkedProductId: json['linked_product_id'], // ✅ Leitura do linked_product_id
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status.name,
      'ean': ean,
      'external_code': externalCode,
      'stock_quantity': stockQuantity,
      'control_stock': controlStock,
      'min_stock': minStock,
      'max_stock': maxStock,
      'unit': unit.name,
      'priority': priority,
      'featured': featured,
      'store_id': storeId,
      'serves_up_to': servesUpTo,
      'weight': weight,
      'sold_count': soldCount,
      'product_type': productType.name,
      'price': price,
      'cost_price': costPrice,
      'is_on_promotion': isOnPromotion,
      'promotional_price': promotionalPrice,
      'primary_category_id': primaryCategoryId,
      'has_multiple_prices': hasMultiplePrices,
      'variant_links': variantLinks.map((v) => v.toJson()).toList(),
      'category_links': categoryLinks.map((c) => c.toJson()).toList(),
      'prices': prices.map((p) => p.toJson()).toList(),
      'gallery_images': images.map((i) => i.toJson()).toList(),
      'dietary_tags': dietaryTags,
      'beverage_tags': beverageTags,
      'video_url': videoUrl,
      'availability_type': availabilityType == AvailabilityType.scheduled ? 'SCHEDULED' : 'ALWAYS',
      'schedules': schedules.map((s) => s.toJson()).toList(),
      'packaging': packaging,
      'quantity': quantity,
      'selling_minimum': sellingMinimum,
      'selling_incremental': sellingIncremental,
      'average_unit': averageUnit,
      'is_industrialized': isIndustrialized,
      'external_item_id': externalItemId,
      'external_product_id': externalProductId,
      'availability_status': availabilityStatus,
      'stock_status': stockStatus,
      'has_violation': hasViolation,
      'can_edit': canEdit,
      'violation_check_state': violationCheckState,
      'selling_rank': sellingRank,
      'promotion_tags': promotionTags,
      'classification': classification,
      'cashback_type': cashbackType,
      'cashback_value': cashbackValue,
      'master_product_id': masterProductId,
      'linked_product_id': linkedProductId, // ✅ Serialização
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? description,
    ProductStatus? status,
    String? ean,
    String? externalCode,
    int? stockQuantity,
    bool? controlStock,
    int? minStock,
    int? maxStock,
    ProductUnit? unit,
    int? priority,
    bool? featured,
    int? storeId,
    int? servesUpTo,
    int? weight,
    int? soldCount,
    List<ProductVariantLink>? variantLinks,
    List<ProductCategoryLink>? categoryLinks,
    int? price,
    int? costPrice,
    bool? isOnPromotion,
    int? promotionalPrice,
    int? primaryCategoryId,
    bool? hasMultiplePrices,
    ProductType? productType,
    List<String>? dietaryTags,
    List<String>? beverageTags,
    List<FlavorPrice>? prices,
    List<ImageModel>? images,
    String? videoUrl,
    AvailabilityType? availabilityType,
    List<ScheduleRule>? schedules,
    String? packaging,
    int? quantity,
    int? sellingMinimum,
    int? sellingIncremental,
    int? averageUnit,
    bool? isIndustrialized,
    String? externalItemId,
    String? externalProductId,
    String? availabilityStatus,
    String? stockStatus,
    bool? hasViolation,
    bool? canEdit,
    String? violationCheckState,
    int? sellingRank,
    List<String>? promotionTags,
    List<String>? classification,
    String? availability,
    Map<String, dynamic>? problems,
    String? productEan,
    int? sequence,
    Map<String, dynamic>? violation,
    List<Map<String, dynamic>>? extensions,
    bool? suggestedCombo,
    Map<String, dynamic>? itemPrice,
    bool? available,
    List<Map<String, dynamic>>? statusByCatalog,
    List<Map<String, dynamic>>? externalCodes,
    String? cashbackType,
    int? cashbackValue,
    int? masterProductId,
    int? linkedProductId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      ean: ean ?? this.ean,
      externalCode: externalCode ?? this.externalCode,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      controlStock: controlStock ?? this.controlStock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      unit: unit ?? this.unit,
      priority: priority ?? this.priority,
      featured: featured ?? this.featured,
      storeId: storeId ?? this.storeId,
      servesUpTo: servesUpTo ?? this.servesUpTo,
      weight: weight ?? this.weight,
      soldCount: soldCount ?? this.soldCount,
      variantLinks: variantLinks ?? this.variantLinks,
      categoryLinks: categoryLinks ?? this.categoryLinks,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      isOnPromotion: isOnPromotion ?? this.isOnPromotion,
      promotionalPrice: promotionalPrice ?? this.promotionalPrice,
      primaryCategoryId: primaryCategoryId ?? this.primaryCategoryId,
      hasMultiplePrices: hasMultiplePrices ?? this.hasMultiplePrices,
      productType: productType ?? this.productType,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      beverageTags: beverageTags ?? this.beverageTags,
      prices: prices ?? this.prices,
      images: images ?? this.images,
      videoUrl: videoUrl ?? this.videoUrl,
      availabilityType: availabilityType ?? this.availabilityType,
      schedules: schedules ?? this.schedules,
      packaging: packaging ?? this.packaging,
      quantity: quantity ?? this.quantity,
      sellingMinimum: sellingMinimum ?? this.sellingMinimum,
      sellingIncremental: sellingIncremental ?? this.sellingIncremental,
      averageUnit: averageUnit ?? this.averageUnit,
      isIndustrialized: isIndustrialized ?? this.isIndustrialized,
      externalItemId: externalItemId ?? this.externalItemId,
      externalProductId: externalProductId ?? this.externalProductId,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      stockStatus: stockStatus ?? this.stockStatus,
      hasViolation: hasViolation ?? this.hasViolation,
      canEdit: canEdit ?? this.canEdit,
      violationCheckState: violationCheckState ?? this.violationCheckState,
      sellingRank: sellingRank ?? this.sellingRank,
      promotionTags: promotionTags ?? this.promotionTags,
      classification: classification ?? this.classification,
      // ✅ CAMPOS ADICIONAIS DO CATÁLOGO
      availability: availability ?? this.availability,
      problems: problems ?? this.problems,
      productEan: productEan ?? this.productEan,
      sequence: sequence ?? this.sequence,
      violation: violation ?? this.violation,
      extensions: extensions ?? this.extensions,
      suggestedCombo: suggestedCombo ?? this.suggestedCombo,
      itemPrice: itemPrice ?? this.itemPrice,
      available: available ?? this.available,
      statusByCatalog: statusByCatalog ?? this.statusByCatalog,
      externalCodes: externalCodes ?? this.externalCodes,
      cashbackType: cashbackType ?? this.cashbackType,
      cashbackValue: cashbackValue ?? this.cashbackValue,
      masterProductId: masterProductId ?? this.masterProductId,
      linkedProductId: linkedProductId ?? this.linkedProductId, // ✅ Copiar novo valor
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    status,
    ean,
    externalCode,
    stockQuantity,
    controlStock,
    unit,
    priority,
    featured,
    storeId,
    productType,
    price,
    isOnPromotion,
    promotionalPrice,
    hasMultiplePrices,
    variantLinks,
    categoryLinks,
    prices,
    images,
    availabilityType,
    isIndustrialized,
    externalItemId,
    externalProductId,
    availabilityStatus,
    stockStatus,
    availability,
    problems,
    productEan,
    sequence,
    violation,
    extensions,
    suggestedCombo,
    itemPrice,
    available,
    statusByCatalog,
    externalCodes,
    cashbackType,
    cashbackValue,
    masterProductId,
    linkedProductId, // ✅ Adicionar ao props
  ];

  @override
  String toString() => 'Product(id: $id, name: $name, status: ${status.name})';
}
