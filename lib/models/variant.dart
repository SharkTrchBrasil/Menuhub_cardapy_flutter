// lib/models/variant.dart

import 'package:totem/models/variant_option.dart';

// Enum VariantType
enum VariantType {
  INGREDIENTS,
  SPECIFICATIONS,
  CROSS_SELL,
  DISPOSABLES,
  UNKNOWN
}

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

  // ✅ FACTORY EMPTY ADICIONADO
  factory Variant.empty() {
    return const Variant(
      id: null,
      name: '',
      type: VariantType.UNKNOWN,
      options: [],
    );
  }

  // ✅ FACTORY PLACEHOLDER (OPCIONAL)
  factory Variant.placeholder({String? name}) {
    return Variant(
      id: 0,
      name: name ?? 'Carregando...',
      type: VariantType.UNKNOWN,
      options: const [],
    );
  }

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
    // Mapeamento da String da API para o Enum do App
    VariantType typeFromString(String? typeStr) {
      switch (typeStr) {
        case "Ingredientes":
          return VariantType.INGREDIENTS;
        case "Especificações":
          return VariantType.SPECIFICATIONS;
        case "Cross-sell":
          return VariantType.CROSS_SELL;
        case "Descartáveis":
          return VariantType.DISPOSABLES;
        default:
          return VariantType.UNKNOWN;
      }
    }

    return Variant(
      id: json['id'],
      name: json['name'],
      type: typeFromString(json['type']),
      options: (json['options'] as List? ?? [])
          .map((optionJson) => VariantOption.fromJson(optionJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    // Mapeamento do Enum do App para a String da API
    String typeToString(VariantType type) {
      switch (type) {
        case VariantType.INGREDIENTS:
          return "Ingredientes";
        case VariantType.SPECIFICATIONS:
          return "Especificações";
        case VariantType.CROSS_SELL:
          return "Cross-sell";
        case VariantType.DISPOSABLES:
          return "Descartáveis";
        case VariantType.UNKNOWN:
          return "Desconhecido";
      }
    }

    return {
      if (id != null) 'id': id,
      'name': name,
      'type': typeToString(type),
      // Opções são salvas separadamente na API
      'options': options.map((option) => option.toJson()).toList(),
    };
  }

  // ✅ HELPER: Pega opção por ID
  VariantOption? getOptionById(int optionId) {
    try {
      return options.firstWhere((option) => option.id == optionId);
    } catch (e) {
      return null;
    }
  }

  // ✅ HELPER: Lista de opções disponíveis
  List<VariantOption> get availableOptions {
    return options.where((option) => option.canBeSelected).toList();
  }

  // ✅ HELPER: Verifica se tem opções disponíveis
  bool get hasAvailableOptions {
    return availableOptions.isNotEmpty;
  }

  // ✅ HELPER: Verifica se está vazio
  bool get isEmpty => id == null || id == 0 || name.isEmpty;

  @override
  String toString() {
    return 'Variant(id: $id, name: $name, type: ${type.name}, options: ${options.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Variant && other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}