// lib/models/product.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/models/product_category_link.dart';
import 'package:totem/models/flavor_price.dart';
import 'package:totem/models/product_variant_link.dart';
import 'package:totem/models/rating_summary.dart';


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

  // Campos que raramente são usados diretamente no cliente, mas vêm no JSON
  final bool featured;
  final String cashbackType;
  final int cashbackValue;

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
    this.featured = false,
    this.cashbackType = 'none',
    this.cashbackValue = 0,
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
      featured: json['featured'] ?? false,
      cashbackType: json['cashback_type'] ?? 'none',
      cashbackValue: json['cashback_value'] ?? 0,
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
        featured = false,
        cashbackType = 'none',
        cashbackValue = 0;

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
    featured,
    cashbackType,
    cashbackValue,
  ];
}