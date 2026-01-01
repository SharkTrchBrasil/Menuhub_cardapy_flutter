// lib/models/category.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/product_category_link.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/models/availability_model.dart';

enum CategoryType {
  GENERAL,
  CUSTOMIZABLE,
  UNKNOWN;

  static CategoryType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'GENERAL':
        return CategoryType.GENERAL;
      case 'CUSTOMIZABLE':
        return CategoryType.CUSTOMIZABLE;
      default:
        return CategoryType.UNKNOWN;
    }
  }

  String toApiString() => name;
}


class Category extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final int priority;
  final bool isActive;
  final CategoryType type;
  final ImageModel? image;
  final List<OptionGroup> optionGroups;
  final List<ProductCategoryLink> productLinks;
  // ✅ NOVOS CAMPOS: Disponibilidade e horários
  final AvailabilityType availabilityType;
  final List<ScheduleRule> schedules;
  // ✅ NOVO: Mapa de optionGroups por produto (para pizzas com múltiplos choices)
  // productId -> List<OptionGroup> (choices específicos de cada tamanho)
  final Map<int, List<OptionGroup>>? productOptionGroups;

  const Category({
    this.id,
    required this.name,
    this.description,
    required this.priority,
    required this.isActive,
    this.type = CategoryType.GENERAL,
    this.image,
    this.optionGroups = const [],
    this.productLinks = const [],
    this.availabilityType = AvailabilityType.always,
    this.schedules = const [],
    this.productOptionGroups,
  });

  bool get isCustomizable => type == CategoryType.CUSTOMIZABLE;

  Category copyWith({
    int? id,
    String? name,
    String? description,
    int? priority,
    bool? isActive,
    CategoryType? type,
    ImageModel? image,
    List<OptionGroup>? optionGroups,
    List<ProductCategoryLink>? productLinks,
    Map<int, List<OptionGroup>>? productOptionGroups,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      type: type ?? this.type,
      image: image ?? this.image,
      optionGroups: optionGroups ?? this.optionGroups,
      productLinks: productLinks ?? this.productLinks,
      productOptionGroups: productOptionGroups ?? this.productOptionGroups,
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    // ✅ Parse de availability_type robusto
    AvailabilityType availabilityType = AvailabilityType.always;
    try {
      if (json['availability_type'] != null) {
        final typeStr = json['availability_type'].toString().toUpperCase();
        if (typeStr == 'SCHEDULED') {
          availabilityType = AvailabilityType.scheduled;
        } else if (typeStr == 'ALWAYS') {
          availabilityType = AvailabilityType.always;
        }
      }
    } catch (e) {
      // Ignora erro de parse e mantem default
    }

    // ✅ Parse de schedules
    List<ScheduleRule> schedules = [];
    try {
      if (json['schedules'] != null && json['schedules'] is List) {
        schedules = (json['schedules'] as List<dynamic>)
            .map((scheduleJson) => ScheduleRule.fromJson(scheduleJson as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Ignora erro de parse
    }

    // ✅ Detecta tipo da categoria
    CategoryType categoryType = CategoryType.GENERAL;
    try {
      if (json['type'] != null) {
        categoryType = CategoryType.fromString(json['type'].toString());
      }
    } catch (e) {
      // Mantem general
    }
    
    // ✅ Se não tiver tipo definido, tenta detectar pelo nome (para compatibilidade com formato antigo)
    if (categoryType == CategoryType.UNKNOWN || categoryType == CategoryType.GENERAL) {
      final categoryName = (json['name']?.toString() ?? '').toLowerCase();
      // Detecta categorias de pizza pelo nome
      if (categoryName.contains('pizza') || categoryName.contains('pizzas')) {
        categoryType = CategoryType.CUSTOMIZABLE;
      }
    }

    // ✅ Parse de imagem (suporte a image object ou image_path string)
    ImageModel? imageModel;
    if (json['image'] != null && json['image'] is Map) {
      imageModel = ImageModel.fromJson(json['image']);
    } else if (json['image_path'] != null && json['image_path'].toString().isNotEmpty) {
      imageModel = ImageModel(url: json['image_path'].toString());
    }

    // ✅ Parse de productOptionGroups
    Map<int, List<OptionGroup>>? productOptionGroups;
    try {
      if (json['product_option_groups'] != null && json['product_option_groups'] is Map) {
        productOptionGroups = {};
        (json['product_option_groups'] as Map).forEach((key, value) {
            final productId = int.tryParse(key.toString());
            if (productId != null && value is List) {
                productOptionGroups![productId] = (value as List)
                    .map((v) => OptionGroup.fromJson(v))
                    .toList();
            }
        });
      }
    } catch (e) {
      // Ignora erro de parse
    }

    return Category(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0'),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      priority: json['priority'] is int ? json['priority'] : (int.tryParse(json['priority']?.toString() ?? '0') ?? 0),
      isActive: json['is_active'] == true || json['is_active'] == 1, // Suporte a bool ou int
      type: categoryType,
      image: imageModel,
      optionGroups: (json['option_groups'] as List<dynamic>? ?? [])
          .map((groupJson) => OptionGroup.fromJson(groupJson))
          .toList(),
      productLinks: (json['product_links'] as List<dynamic>? ?? [])
          .map((linkJson) => ProductCategoryLink.fromJson(linkJson))
          .toList(),
      availabilityType: availabilityType,
      schedules: schedules,
      productOptionGroups: productOptionGroups,
    );
  }

  const Category.empty()
      : id = 0,
        name = '',
        description = null,
        priority = 0,
        isActive = false,
        type = CategoryType.UNKNOWN,
        image = null,
        optionGroups = const [],
        productLinks = const [],
        availabilityType = AvailabilityType.always,
        schedules = const [],
        productOptionGroups = null;

  @override
  List<Object?> get props => [id, name, type, isActive, optionGroups, productLinks, availabilityType, schedules, productOptionGroups];
}