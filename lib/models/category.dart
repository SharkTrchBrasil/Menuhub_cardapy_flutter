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
    // ✅ Parse de availability_type
    AvailabilityType availabilityType = AvailabilityType.always;
    if (json['availability_type'] != null) {
      final typeStr = json['availability_type'].toString().toUpperCase();
      if (typeStr == 'SCHEDULED') {
        availabilityType = AvailabilityType.scheduled;
      }
      // Se for 'NEVER' ou outro valor, mantém 'always' como padrão (ou pode criar enum com 'never')
    }

    // ✅ Parse de schedules
    List<ScheduleRule> schedules = [];
    if (json['schedules'] != null && json['schedules'] is List) {
      schedules = (json['schedules'] as List<dynamic>)
          .map((scheduleJson) => ScheduleRule.fromJson(scheduleJson as Map<String, dynamic>))
          .toList();
    }

    // ✅ Detecta tipo da categoria
    CategoryType categoryType = CategoryType.fromString(json['type']);
    
    // ✅ Se não tiver tipo definido, tenta detectar pelo nome (para compatibilidade com formato antigo)
    if (categoryType == CategoryType.UNKNOWN || categoryType == CategoryType.GENERAL) {
      final categoryName = (json['name'] ?? '').toLowerCase();
      // Detecta categorias de pizza pelo nome
      if (categoryName.contains('pizza') || categoryName.contains('pizzas')) {
        categoryType = CategoryType.CUSTOMIZABLE;
      }
    }

    return Category(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 0,
      isActive: json['is_active'] ?? true,
      type: categoryType,
      image: json['image'] != null ? ImageModel.fromJson(json['image']) : null,
      optionGroups: (json['option_groups'] as List<dynamic>? ?? [])
          .map((groupJson) => OptionGroup.fromJson(groupJson))
          .toList(),
      productLinks: (json['product_links'] as List<dynamic>? ?? [])
          .map((linkJson) => ProductCategoryLink.fromJson(linkJson))
          .toList(),
      availabilityType: availabilityType,
      schedules: schedules,
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