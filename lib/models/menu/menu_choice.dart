// lib/models/menu/menu_choice.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/menu/garnish_item.dart';

/// Grupo de escolhas (ex: "Escolha um sabor", "Escolha a sua Preferência")
class MenuChoice extends Equatable {
  final String code; // Código do grupo (ex: "SABOR", "SABOR2", "F1F071")
  final String name; // Nome do grupo (ex: "Escolha um sabor")
  final int min; // Mínimo de seleções obrigatórias
  final int max; // Máximo de seleções permitidas
  final List<GarnishItem> garnishItens; // Opções disponíveis

  const MenuChoice({
    required this.code,
    required this.name,
    required this.min,
    required this.max,
    required this.garnishItens,
  });

  factory MenuChoice.fromJson(Map<String, dynamic> json) {
    return MenuChoice(
      code: json['code'] as String,
      name: json['name'] as String,
      min: json['min'] as int? ?? 0,
      max: json['max'] as int? ?? 1,
      garnishItens: (json['garnishItens'] as List<dynamic>? ?? [])
          .map((item) => GarnishItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'min': min,
      'max': max,
      'garnishItens': garnishItens.map((item) => item.toJson()).toList(),
    };
  }

  /// Verifica se é obrigatório (min > 0)
  bool get isRequired => min > 0;

  /// Verifica se permite múltiplas seleções (max > 1)
  bool get allowsMultiple => max > 1;

  @override
  List<Object?> get props => [code, name, min, max, garnishItens];
}












