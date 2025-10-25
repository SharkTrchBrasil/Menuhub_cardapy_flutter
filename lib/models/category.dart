// lib/models/category.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/product_category_link.dart';

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
  });

  bool get isCustomizable => type == CategoryType.CUSTOMIZABLE;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 0,
      isActive: json['is_active'] ?? true,
      type: CategoryType.fromString(json['type']),
      image: json['image'] != null ? ImageModel.fromJson(json['image']) : null,
      optionGroups: (json['option_groups'] as List<dynamic>? ?? [])
          .map((groupJson) => OptionGroup.fromJson(groupJson))
          .toList(),
      productLinks: (json['product_links'] as List<dynamic>? ?? [])
          .map((linkJson) => ProductCategoryLink.fromJson(linkJson))
          .toList(),
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
        productLinks = const [];

  @override
  List<Object?> get props => [id, name, type, isActive, optionGroups, productLinks];
}