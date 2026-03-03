// lib/models/menu/menu_category.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/menu/menu_item.dart';

/// Categoria do menu no novo formato
class MenuCategory extends Equatable {
  final String code; // UUID da categoria
  final String name;
  final List<MenuItem> itens;
  final String? template; // "pizza", etc.
  /// ✅ FORMATO CANÔNICO: Mapa sizeKey → List<OptionGroup> raw (com prices_by_size)
  /// Injetado pelo backend para garantir formato idêntico entre carga inicial e category_updated
  final Map<String, dynamic>? productOptionGroups;

  const MenuCategory({
    required this.code,
    required this.name,
    required this.itens,
    this.template,
    this.productOptionGroups,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      code: json['code'] as String,
      name: json['name'] as String,
      itens:
          (json['itens'] as List<dynamic>? ?? [])
              .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
              .toList(),
      template: json['template'] as String?,
      productOptionGroups:
          json['product_option_groups'] is Map
              ? Map<String, dynamic>.from(json['product_option_groups'] as Map)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'itens': itens.map((item) => item.toJson()).toList(),
      if (template != null) 'template': template,
      if (productOptionGroups != null)
        'product_option_groups': productOptionGroups,
    };
  }

  @override
  List<Object?> get props => [code, name, itens, template, productOptionGroups];
}
