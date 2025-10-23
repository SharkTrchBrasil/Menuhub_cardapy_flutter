// lib/models/product.dart

import 'package:totem/models/category.dart';
import 'package:totem/models/product_category_link.dart';
import 'package:totem/models/product_variant_link.dart';
import 'package:totem/models/rating_summary.dart';
import '../helpers/enums.dart';
import 'flavor_price.dart';
import 'image_model.dart';
import 'kit_combo.dart';
import 'product_image.dart'; // ✅ PASSO 1: Importe o novo modelo de imagem

class Product {
  final int id;
  final String name;
  final String description;
  final int basePrice;
  final int? promotionPrice;
  final bool featured;
  final bool activatePromotion;
  // final String? imageUrl; // ❌ REMOVIDO: O campo de imagem única foi removido
  final Category category;
  final List<ProductVariantLink>? variantLinks;
  final RatingsSummary? rating;
  final ProductType productType;
  final int? calculatedStock;
  final List<KitComponent> components;
  final List<int> defaultOptionIds;
  final String cashbackType;
  final int cashbackValue;
  final ProductStatus status;

  final List<ImageModel> images;
  final ImageModel? videoFile;

  final String? fileKey;
  final String? videoUrl;

  final List<ProductImage> galleryImages;
  final List<ProductCategoryLink> categoryLinks;
  final List<FlavorPrice> prices;


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


  // Helper para obter a imagem de capa
  String? get coverImageUrl {
    if (images.isNotEmpty && !images.first.isVideo) {
      return images.first.url;
    }
    return null;
  }


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
          return ProductStatus.unknown;
        default:
          return ProductStatus.unknown;
      }
    }

    final String? videoUrl = map['video_url'];


    return Product(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      basePrice: map['base_price'] as int? ?? 0,
      promotionPrice: map['promotion_price'] as int?,
      activatePromotion: map['activate_promotion'] as bool? ?? false,
      featured: map['featured'] as bool? ?? false,
      // imageUrl: map['image_path'] as String?, // ❌ REMOVIDO
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
// O backend agora envia 'video_url'
      videoUrl: map['video_url'],

      // Mapeia a lista de imagens da galeria
      galleryImages: (map['gallery_images'] as List? ?? [])
          .map((imageJson) => ProductImage.fromJson(imageJson))
          .toList(),

      // Mapeia a lista de preços por categoria
      categoryLinks: (map['category_links'] as List? ?? [])
          .map((linkJson) => ProductCategoryLink.fromJson(linkJson))
          .toList(),

      // Mapeia a lista de preços por tamanho (para pizzas, etc.)
      prices: (map['prices'] as List? ?? [])
          .map((priceJson) => FlavorPrice.fromJson(priceJson))
          .toList(),

     //  variantLinks: [], // Descomentar quando o model ProductVariantLink for criado/atualizado


    );
  }

  static Product empty() => Product(
    id: 0,
    name: '',
    description: '',
    basePrice: 0,
    variantLinks: [],
    category: Category.empty(),
    promotionPrice: 0,
    featured: false,
    activatePromotion: false,
    productType: ProductType.INDIVIDUAL,
    components: [],
    defaultOptionIds: [],
    cashbackType: 'none',
    cashbackValue: 0,
    status: ProductStatus.unknown,
    images: [],
    galleryImages: [],
    categoryLinks: [],
    prices: [], // ✅ Adicionado ao factory 'empty'
  );
}