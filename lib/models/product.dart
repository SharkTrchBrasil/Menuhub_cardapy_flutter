// lib/models/product.dart

import 'package:totem/models/category.dart';
import 'package:totem/models/product_image.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/models/product_category_link.dart';
import 'package:totem/models/flavor_price.dart';
import 'package:totem/models/product_variant_link.dart';

import 'package:totem/models/rating_summary.dart';


import 'kit_combo.dart';

enum ProductType {
  INDIVIDUAL,
  KIT,
  UNKNOWN;

  String toApiString() {
    switch (this) {
      case ProductType.INDIVIDUAL:
        return 'INDIVIDUAL';
      case ProductType.KIT:
        return 'KIT';
      case ProductType.UNKNOWN:
        return 'UNKNOWN';
    }
  }
}

enum ProductStatus {
  active,
  inactive,
  outOfStock,
  unknown;
}

class Product {
  final int id;
  final String name;
  final String description;
  final int basePrice;
  final int? promotionPrice;
  final bool featured;
  final bool activatePromotion;
  final Category category;

  final String? fileKey;
  final String? videoUrl;
  final List<ProductImage> galleryImages;
  final List<ImageModel> images;
  final ImageModel? videoFile;

  final List<ProductCategoryLink> categoryLinks;
  final List<FlavorPrice> prices;
  final List<ProductVariantLink>? variantLinks;
  final ProductType productType;
  final int? calculatedStock;
  final List<KitComponent> components;
  final List<int> defaultOptionIds;
  final String cashbackType;
  final int cashbackValue;
  final ProductStatus status;
  final RatingsSummary? rating;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    this.promotionPrice,
    required this.featured,
    required this.activatePromotion,
    required this.category,
    this.variantLinks,
    this.rating,
    required this.productType,
    this.calculatedStock,
    required this.components,
    required this.defaultOptionIds,
    required this.cashbackType,
    required this.cashbackValue,
    required this.status,
    this.fileKey,
    this.images = const [],
    this.videoFile,
    required this.galleryImages,
    required this.categoryLinks,
    required this.prices,
    this.videoUrl,
  });

  // ✅ FACTORY CONSTRUCTOR PARA PRODUTO VAZIO
  factory Product.empty() {
    return Product(
      id: 0,
      name: '',
      description: '',
      basePrice: 0,
      promotionPrice: null,
      featured: false,
      activatePromotion: false,
      category: Category.empty(), // ✅ Usa o empty da categoria
      variantLinks: [],
      rating: null,
      productType: ProductType.INDIVIDUAL,
      calculatedStock: 0,
      components: [],
      defaultOptionIds: [],
      cashbackType: 'none',
      cashbackValue: 0,
      status: ProductStatus.active,
      fileKey: null,
      images: const [],
      videoFile: null,
      galleryImages: const [],
      categoryLinks: const [],
      prices: const [],
      videoUrl: null,
    );
  }

  // ✅ HELPER: Cópia do produto vazio com alguns campos preenchidos
  factory Product.placeholder({
    int? id,
    String? name,
    String? description,
  }) {
    return Product(
      id: id ?? 0,
      name: name ?? 'Carregando...',
      description: description ?? '',
      basePrice: 0,
      promotionPrice: null,
      featured: false,
      activatePromotion: false,
      category: Category.empty(),
      variantLinks: [],
      rating: null,
      productType: ProductType.INDIVIDUAL,
      calculatedStock: 0,
      components: [],
      defaultOptionIds: [],
      cashbackType: 'none',
      cashbackValue: 0,
      status: ProductStatus.active,
      fileKey: null,
      images: const [],
      videoFile: null,
      galleryImages: const [],
      categoryLinks: const [],
      prices: const [],
      videoUrl: null,
    );
  }

  // Helpers para imagens
  String? get coverImageUrl {
    if (galleryImages.isNotEmpty) {
      return galleryImages.first.imageUrl;
    }
    if (images.isNotEmpty && !images.first.isVideo) {
      return images.first.url;
    }
    return null;
  }

  List<String> get allImageUrls {
    return galleryImages.map((img) => img.imageUrl).toList();
  }

  // fromJson
  factory Product.fromJson(Map<String, dynamic> map) {
    ProductType _typeFromString(String? typeStr) {
      if (typeStr == 'KIT') return ProductType.KIT;
      if (typeStr == 'INDIVIDUAL') return ProductType.INDIVIDUAL;
      return ProductType.UNKNOWN;
    }

    ProductStatus _statusFromString(String? statusStr) {
      switch (statusStr) {
        case 'ACTIVE':
          return ProductStatus.active;
        case 'INACTIVE':
          return ProductStatus.inactive;
        case 'OUT_OF_STOCK':
          return ProductStatus.outOfStock;
        default:
          return ProductStatus.unknown;
      }
    }

    return Product(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      basePrice: map['base_price'] as int? ?? 0,
      promotionPrice: map['promotion_price'] as int?,
      activatePromotion: map['activate_promotion'] as bool? ?? false,
      featured: map['featured'] as bool? ?? false,
      category: Category.fromJson(map['category'] as Map<String, dynamic>? ?? {}),

      variantLinks: (map['variant_links'] as List<dynamic>?)
          ?.map((linkJson) => ProductVariantLink.fromJson(linkJson as Map<String, dynamic>))
          .toList(),

      rating: map['rating'] != null
          ? RatingsSummary.fromMap(map['rating'] as Map<String, dynamic>)
          : null,

      productType: _typeFromString(map['product_type'] as String?),
      calculatedStock: map['calculated_stock'] as int?,

      components: (map['components'] as List<dynamic>?)
          ?.map((c) => KitComponent.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],

      defaultOptionIds: List<int>.from(map['default_option_ids'] as List<dynamic>? ?? []),
      cashbackType: map['cashback_type'] as String? ?? 'none',
      cashbackValue: map['cashback_value'] as int? ?? 0,
      status: _statusFromString(map['status'] as String?),
      fileKey: map['file_key'],
      videoUrl: map['video_url'],

      galleryImages: (map['gallery_images'] as List? ?? [])
          .map((imageJson) => ProductImage.fromJson(imageJson))
          .toList(),

      images: (map['gallery_images'] as List? ?? [])
          .map((imageJson) => ImageModel.fromJson(imageJson))
          .toList(),

      categoryLinks: (map['category_links'] as List? ?? [])
          .map((linkJson) => ProductCategoryLink.fromJson(linkJson))
          .toList(),

      prices: (map['prices'] as List? ?? [])
          .map((priceJson) => FlavorPrice.fromJson(priceJson))
          .toList(),
    );
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'base_price': basePrice,
      'promotion_price': promotionPrice,
      'activate_promotion': activatePromotion,
      'featured': featured,
      'product_type': productType.toApiString(),
      'calculated_stock': calculatedStock,
      'cashback_type': cashbackType,
      'cashback_value': cashbackValue,
      'status': status.name,
      'file_key': fileKey,
      'video_url': videoUrl,
      'gallery_images': galleryImages.map((img) => img.toJson()).toList(),
      'category_links': categoryLinks.map((link) => link.toJson()).toList(),
      'prices': prices.map((price) => price.toJson()).toList(),
      'variant_links': variantLinks?.map((link) => link.toJson()).toList(),
      'default_option_ids': defaultOptionIds,
    };
  }

  // ✅ MÉTODO COPYWITH PARA FACILITAR ATUALIZAÇÕES
  Product copyWith({
    int? id,
    String? name,
    String? description,
    int? basePrice,
    int? promotionPrice,
    bool? featured,
    bool? activatePromotion,
    Category? category,
    List<ProductVariantLink>? variantLinks,
    RatingsSummary? rating,
    ProductType? productType,
    int? calculatedStock,
    List<KitComponent>? components,
    List<int>? defaultOptionIds,
    String? cashbackType,
    int? cashbackValue,
    ProductStatus? status,
    String? fileKey,
    List<ImageModel>? images,
    ImageModel? videoFile,
    List<ProductImage>? galleryImages,
    List<ProductCategoryLink>? categoryLinks,
    List<FlavorPrice>? prices,
    String? videoUrl,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      promotionPrice: promotionPrice ?? this.promotionPrice,
      featured: featured ?? this.featured,
      activatePromotion: activatePromotion ?? this.activatePromotion,
      category: category ?? this.category,
      variantLinks: variantLinks ?? this.variantLinks,
      rating: rating ?? this.rating,
      productType: productType ?? this.productType,
      calculatedStock: calculatedStock ?? this.calculatedStock,
      components: components ?? this.components,
      defaultOptionIds: defaultOptionIds ?? this.defaultOptionIds,
      cashbackType: cashbackType ?? this.cashbackType,
      cashbackValue: cashbackValue ?? this.cashbackValue,
      status: status ?? this.status,
      fileKey: fileKey ?? this.fileKey,
      images: images ?? this.images,
      videoFile: videoFile ?? this.videoFile,
      galleryImages: galleryImages ?? this.galleryImages,
      categoryLinks: categoryLinks ?? this.categoryLinks,
      prices: prices ?? this.prices,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }
}