

import 'package:totem/models/variant_option.dart';

class Variant {
  final int? id;
  final String name;
  final VariantType type;
  final List<VariantOption> options;

  const Variant({
    this.id,
    required this.name,
    required this.type,
    required this.options,
  });

  Variant copyWith({
    int? id,
    String? name,
    VariantType? type,
    List<VariantOption>? options,
  }) {
    return Variant(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      options: options ?? this.options,
    );
  }

  factory Variant.fromJson(Map<String, dynamic> json) {
    // ✅ CORRIGIDO: Mapeamento da String da API para o Enum do App
    VariantType typeFromString(String? typeStr) {
      switch (typeStr) {
        case "Ingredientes":
          return VariantType.INGREDIENTS;
        case "Especificações":
          return VariantType.SPECIFICATIONS;
        case "Cross-sell":
          return VariantType.CROSS_SELL;
        case "Descartáveis": // Adicionando o caso que faltava
          return VariantType.DISPOSABLES;
        default:
          return VariantType.UNKNOWN;
      }
    }

    return Variant(
      id: json['id'],
      name: json['name'],
      type: typeFromString(json['type']),
      // O campo 'options' geralmente vem em uma busca detalhada do Variant,
      // então mantemos a leitura dele aqui.
      options: (json['options'] as List? ?? [])
          .map((optionJson) => VariantOption.fromJson(optionJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    // ✅ CORRIGIDO: Mapeamento do Enum do App para a String da API
    String typeToString(VariantType type) {
      switch (type) {
        case VariantType.INGREDIENTS:
          return "Ingredientes";
        case VariantType.SPECIFICATIONS:
          return "Especificações";
        case VariantType.CROSS_SELL:
          return "Cross-sell";
        case VariantType.DISPOSABLES:
          return "Descartáveis"; // Adicionando o caso que faltava
        default:
          return "";
      }
    }

    return {
      if (id != null) 'id': id,
      'name': name,
      'type': typeToString(type),
      // ✅ CORRIGIDO: A lista de 'options' foi REMOVIDA daqui.
      // A API não permite enviar as opções ao criar o "molde" (Variant).
      // Elas devem ser salvas depois, uma a uma.
    };
  }
}

// Lembre-se de garantir que seu enum VariantType tenha todos os tipos
enum VariantType {
  INGREDIENTS,
  SPECIFICATIONS,
  CROSS_SELL,
  DISPOSABLES,
  UNKNOWN
}