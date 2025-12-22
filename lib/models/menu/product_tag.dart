// lib/models/menu/product_tag.dart

import 'package:equatable/equatable.dart';

/// Tag do produto (ex: PIZZA_SIZE com tags ["Pequena", "Média"])
class ProductTag extends Equatable {
  final String group; // Grupo da tag (ex: "PIZZA_SIZE")
  final List<String> tags; // Valores da tag (ex: ["Pequena"])

  const ProductTag({
    required this.group,
    required this.tags,
  });

  factory ProductTag.fromJson(Map<String, dynamic> json) {
    return ProductTag(
      group: json['group'] as String,
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((tag) => tag.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group': group,
      'tags': tags,
    };
  }

  @override
  List<Object?> get props => [group, tags];
}












