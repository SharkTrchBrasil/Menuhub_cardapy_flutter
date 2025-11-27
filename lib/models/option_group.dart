// lib/models/option_group.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/option_item.dart';

// ✅ ENUM: Define os tipos de grupos de opções
// Mapeia com o backend: SIZE, GENERIC
enum OptionGroupType {
  size,       // Mapeia para "SIZE" do backend
  generic,    // Mapeia para "GENERIC" do backend (Massa, Borda)
  flavor,     // ✅ NOVO: Grupos virtuais de sabores de pizza
  preference, // ✅ NOVO: Grupo virtual de preferências (massa + borda combinadas)
  other;      // Fallback

  static OptionGroupType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'SIZE':
        return OptionGroupType.size;
      case 'GENERIC':
        return OptionGroupType.generic;
      case 'FLAVOR':
        return OptionGroupType.flavor;
      case 'PREFERENCE':
        return OptionGroupType.preference;
      default:
        return OptionGroupType.other;
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