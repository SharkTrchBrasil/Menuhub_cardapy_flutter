// lib/models/option_group.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/option_item.dart';

// ✅ ENUM: Define os tipos de grupos de opções
// Mapeia com o backend: SIZE, TOPPING, CRUST, EDGE, GENERIC
enum OptionGroupType {
  size,       // Mapeia para "SIZE" do backend (Tamanhos)
  topping,    // ✅ NOVO: Mapeia para "TOPPING" do backend (Sabores de pizza)
  crust,      // ✅ NOVO: Mapeia para "CRUST" do backend (Tipos de massa)
  edge,       // ✅ NOVO: Mapeia para "EDGE" do backend (Tipos de borda)
  generic,    // Mapeia para "GENERIC" do backend (Outros)
  flavor,     // ⚠️ DEPRECATED: Mantido para compatibilidade
  preference, // ⚠️ DEPRECATED: Mantido para compatibilidade
  other;      // Fallback

  static OptionGroupType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'SIZE':
        return OptionGroupType.size;
      case 'TOPPING':
        return OptionGroupType.topping;
      case 'CRUST':
        return OptionGroupType.crust;
      case 'EDGE':
        return OptionGroupType.edge;
      case 'GENERIC':
        return OptionGroupType.generic;
      case 'FLAVOR':
        return OptionGroupType.flavor; // Compatibilidade
      case 'PREFERENCE':
        return OptionGroupType.preference; // Compatibilidade
      default:
        return OptionGroupType.other;
    }
  }
  
  // Converte para string do backend
  String toApiString() {
    switch (this) {
      case OptionGroupType.size:
        return 'SIZE';
      case OptionGroupType.topping:
        return 'TOPPING';
      case OptionGroupType.crust:
        return 'CRUST';
      case OptionGroupType.edge:
        return 'EDGE';
      case OptionGroupType.generic:
        return 'GENERIC';
      case OptionGroupType.flavor:
        return 'FLAVOR'; // Compatibilidade
      case OptionGroupType.preference:
        return 'PREFERENCE'; // Compatibilidade
      case OptionGroupType.other:
        return 'GENERIC';
    }
  }
}

class OptionGroup extends Equatable {
  final int? id;
  final String name;
  // ✅ CAMPO ADICIONADO: O tipo do grupo
  final OptionGroupType groupType;
  final int minSelection;
  final int maxSelection;
  final List<OptionItem> items;
  final int displayOrder;
  final bool isActive;

  const OptionGroup({
    this.id,
    required this.name,
    required this.groupType,
    required this.minSelection,
    required this.maxSelection,
    required this.items,
    this.displayOrder = 0,
    this.isActive = true,
  });

  bool get isSingleSelection => maxSelection == 1;
  bool get isRequired => minSelection > 0;

  OptionGroup copyWith({
    int? id,
    String? name,
    OptionGroupType? groupType,
    int? minSelection,
    int? maxSelection,
    List<OptionItem>? items,
    int? displayOrder,
    bool? isActive,
  }) {
    return OptionGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      groupType: groupType ?? this.groupType,
      minSelection: minSelection ?? this.minSelection,
      maxSelection: maxSelection ?? this.maxSelection,
      items: items ?? this.items,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  factory OptionGroup.fromJson(Map<String, dynamic> json) {
    return OptionGroup(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      groupType: OptionGroupType.fromString(json['group_type']),
      minSelection: json['min_selection'] as int? ?? 0,
      maxSelection: json['max_selection'] as int? ?? 1,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((itemJson) => OptionItem.fromJson(itemJson))
          .toList(),
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group_type': groupType.name,
      'min_selection': minSelection,
      'max_selection': maxSelection,
      'items': items.map((item) => item.toJson()).toList(),
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }

  @override
  List<Object?> get props => [id, name, groupType, minSelection, maxSelection, items, isActive];
}