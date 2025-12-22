// lib/models/menu/menu_data.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/menu/menu_category.dart';

/// Dados do menu contendo lista de categorias
class MenuData extends Equatable {
  final List<MenuCategory> menu;

  const MenuData({
    required this.menu,
  });

  factory MenuData.fromJson(Map<String, dynamic> json) {
    return MenuData(
      menu: (json['menu'] as List<dynamic>? ?? [])
          .map((item) => MenuCategory.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menu': menu.map((item) => item.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [menu];
}












