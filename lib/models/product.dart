// lib/models/product.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/models/product_category_link.dart';
import 'package:totem/models/flavor_price.dart';
import 'package:totem/models/product_variant_link.dart';
import 'package:totem/models/rating_summary.dart';

// ✅ NOVOS IMPORTS
import 'package:totem/models/availability_model.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/core/enums/foodtags.dart';
import 'package:totem/core/enums/beverage.dart';


// Enums alinhados com o admin
enum ProductType {
  INDIVIDUAL,
  KIT,
  UNKNOWN;

  static ProductType fromString(String? value) {
    switch (value) {
      case 'INDIVIDUAL':
        return ProductType.INDIVIDUAL;
      case 'KIT':
        return ProductType.KIT;
      default:
        return ProductType.UNKNOWN;
    }
  }

  String toApiString() => name;
}

enum ProductStatus {
  ACTIVE,
  INACTIVE,
  OUT_OF_STOCK,
  UNKNOWN;

  static ProductStatus fromString(String? value) {
    switch (value) {
      case 'ACTIVE':
        return ProductStatus.ACTIVE;
      case 'INACTIVE':
        return ProductStatus.INACTIVE;
      case 'OUT_OF_STOCK':
        return ProductStatus.OUT_OF_STOCK;
      default:
        return ProductStatus.UNKNOWN;
    }
  }

  String toApiString() => name;
}

enum ProductUnit {
  UNIT,
  KILOGRAM,
  LITER,
  GRAM,
  MILLILITER;

  static ProductUnit fromString(String? value) {
    switch (value) {
      case 'UNIT':
        return ProductUnit.UNIT;
      case 'KILOGRAM':
        return ProductUnit.KILOGRAM;
      case 'LITER':
        return ProductUnit.LITER;
      case 'GRAM':
        return ProductUnit.GRAM;
      case 'MILLILITER':
        return ProductUnit.MILLILITER;
      default:
        return ProductUnit.UNIT;
    }
  }

  String toApiString() => name;

  bool get requiresQuantityInput {
    return this == ProductUnit.KILOGRAM ||
        this == ProductUnit.LITER ||
        this == ProductUnit.GRAM ||
        this == ProductUnit.MILLILITER;
  }

  String get shortName {
    switch (this) {
      case ProductUnit.UNIT:
        return 'un';
      case ProductUnit.KILOGRAM:
        return 'kg';
      case ProductUnit.LITER:
        return 'L';
      case ProductUnit.GRAM:
        return 'g';
      case ProductUnit.MILLILITER:
        return 'ml';
    }
  }
}

class Product extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final ProductStatus status;

  // Novos campos do admin
  final int storeId;
  final ProductType productType;

  // Galeria e Mídia
  final List<ImageModel> images;
  final String? videoUrl;

  // Vínculos e Preços (Estrutura Central)
  final List<ProductCategoryLink> categoryLinks;
  final List<ProductVariantLink> variantLinks;
  final List<FlavorPrice> prices; // Para sabores de itens customizáveis

  // Avaliações
  final RatingsSummary? rating;

  // Estoque (simplificado para o cliente)
  final int? calculatedStock;
  
  // ✅ NOVO: Controle de estoque detalhado
  final bool controlStock;
  final int minStock;
  final int maxStock;
  final int stockQuantity;

  // Campos que raramente são usados diretamente no cliente, mas vêm no JSON
  final bool featured;
  final String cashbackType;
  final int cashbackValue;
  
  // ✅ NOVO: Unidade de medida do produto
  final ProductUnit unit;

  // ✅ NOVO: Campos de disponibilidade e tags
  final AvailabilityType availabilityType;
  final List<ScheduleRule> schedules;
  final Set<FoodTag> dietaryTags;
  final Set<BeverageTag> beverageTags;

  const Product({
    this.id,
    required this.name,
    this.description,
    required this.status,
    required this.storeId,
    required this.productType,
    this.images = const [],
    this.videoUrl,
    this.categoryLinks = const [],
    this.variantLinks = const [],
    this.prices = const [],
    this.rating,
    this.calculatedStock,
    this.controlStock = false,
    this.minStock = 0,
    this.maxStock = 0,
    this.stockQuantity = 0,
    this.featured = false,
    this.cashbackType = 'none',
    this.cashbackValue = 0,
    this.unit = ProductUnit.UNIT,
    this.availabilityType = AvailabilityType.always,
    this.schedules = const [],
    this.dietaryTags = const {},
    this.beverageTags = const {},
  });

  // Helper para obter a imagem de capa
  String? get coverImageUrl {
    return images.firstWhere((img) => !img.isVideo, orElse: () => const ImageModel(url: '')).url;
  }

  // Helper para obter todas as imagens da galeria (excluindo vídeo)
  List<ImageModel> get galleryImages => images.where((img) => !img.isVideo).toList();

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      status: ProductStatus.fromString(json['status']),
      storeId: json['store_id'] ?? 0,
      productType: ProductType.fromString(json['product_type']),

      images: (json['gallery_images'] as List<dynamic>? ?? [])
          .map((imgJson) => ImageModel.fromJson(imgJson))
          .toList(),

      videoUrl: json['video_url'],

      categoryLinks: (json['category_links'] as List<dynamic>? ?? [])
          .map((link) => ProductCategoryLink.fromJson(link))
          .toList(),

      variantLinks: (json['variant_links'] as List<dynamic>? ?? [])
          .map((link) => ProductVariantLink.fromJson(link))
          .toList(),

      prices: (json['prices'] as List<dynamic>? ?? [])
          .map((p) => FlavorPrice.fromJson(p))
          .toList(),

      rating: json['rating'] != null
          ? RatingsSummary.fromMap(json['rating'])
          : null,

      calculatedStock: json['calculated_stock'],
      
      // ✅ NOVO: Parse de estoque detalhado
      controlStock: json['control_stock'] ?? false,
      minStock: json['min_stock'] ?? 0,
      maxStock: json['max_stock'] ?? 0,
      stockQuantity: json['stock_quantity'] ?? 0,
      
      featured: json['featured'] ?? false,
      cashbackType: json['cashback_type'] ?? 'none',
      cashbackValue: json['cashback_value'] ?? 0,
      unit: ProductUnit.fromString(json['unit']),

      // ✅ NOVO: Parse de disponibilidade e tags
      availabilityType: json['availability_type'] != null
          ? (json['availability_type'] == 'SCHEDULED' ? AvailabilityType.scheduled : AvailabilityType.always)
          : AvailabilityType.always,
      schedules: (json['schedules'] as List<dynamic>? ?? [])
          .map((scheduleJson) => ScheduleRule.fromJson(scheduleJson))
          .toList(),
      
      dietaryTags: (json['dietary_tags'] as List<dynamic>? ?? [])
          .map((tagString) => apiValueToFoodTag[tagString])
          .whereType<FoodTag>()
          .toSet(),
      
      beverageTags: (json['beverage_tags'] as List<dynamic>? ?? [])
          .map((tagString) => apiValueToBeverageTag[tagString])
          .whereType<BeverageTag>()
          .toSet(),
    );
  }

  // Construtor vazio para estados iniciais
  const Product.empty()
      : id = 0,
        name = '',
        description = null,
        status = ProductStatus.UNKNOWN,
        storeId = 0,
        productType = ProductType.UNKNOWN,
        images = const [],
        videoUrl = null,
        categoryLinks = const [],
        variantLinks = const [],
        prices = const [],
        rating = null,
        calculatedStock = null,
        controlStock = false,
        minStock = 0,
        maxStock = 0,
        stockQuantity = 0,
        featured = false,
        cashbackType = 'none',
        cashbackValue = 0,
        unit = ProductUnit.UNIT,
        availabilityType = AvailabilityType.always,
        schedules = const [],
        dietaryTags = const {},
        beverageTags = const {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status.toApiString(),
      'store_id': storeId,
      'product_type': productType.toApiString(),
      'gallery_images': images.map((img) => img.toJson()).toList(),
      'video_url': videoUrl,
      'category_links': categoryLinks.map((link) => link.toJson()).toList(),
      'variant_links': variantLinks.map((link) => link.toJson()).toList(),
      'prices': prices.map((p) => p.toJson()).toList(),
      'rating': rating?.toMap(),
      'calculated_stock': calculatedStock,
      'control_stock': controlStock,
      'min_stock': minStock,
      'max_stock': maxStock,
      'stock_quantity': stockQuantity,
      'featured': featured,
      'cashback_type': cashbackType,
      'cashback_value': cashbackValue,
      'unit': unit.toApiString(),
      // ✅ NOVO: Serialização de disponibilidade e tags
      'availability_type': availabilityType == AvailabilityType.scheduled ? 'SCHEDULED' : 'ALWAYS',
      'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
      'dietary_tags': dietaryTags.map((tag) => foodTagNames[tag]!).toList(),
      'beverage_tags': beverageTags.map((tag) => beverageTagNames[tag]!).toList(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    status,
    storeId,
    productType,
    images,
    videoUrl,
    categoryLinks,
    variantLinks,
    prices,
    rating,
    calculatedStock,
    controlStock,
    minStock,
    maxStock,
    stockQuantity,
    featured,
    cashbackType,
    cashbackValue,
    unit,
    availabilityType,
    schedules,
    dietaryTags,
    beverageTags,
  ];
}