// lib/models/option_item_price.dart

import 'package:equatable/equatable.dart';

/// Modelo para preços de OptionItems (sabores) por tamanho.
/// 
/// Estrutura:
/// - Sabores (TOPPING) têm preços diferentes dependendo do tamanho (SIZE) selecionado
/// - Cada OptionItemPrice relaciona um sabor (option_item_id) com um tamanho (parent_option_id)
class OptionItemPrice extends Equatable {
  final int? id;
  final int optionItemId; // ID do OptionItem que é o sabor (TOPPING)
  final int parentOptionId; // ID do OptionItem que é o tamanho (SIZE)
  final int price; // Preço em centavos
  final bool isAvailable; // Se o sabor está disponível para este tamanho
  final String? posCode; // Código PDV (opcional)

  const OptionItemPrice({
    this.id,
    required this.optionItemId,
    required this.parentOptionId,
    required this.price,
    this.isAvailable = true,
    this.posCode,
  });

  factory OptionItemPrice.fromJson(Map<String, dynamic> json) {
    return OptionItemPrice(
      id: json['id'] as int?,
      optionItemId: json['option_item_id'] as int,
      parentOptionId: json['parent_option_id'] as int,
      price: json['price'] is int 
          ? json['price'] as int 
          : ((json['price'] as num) * 100).round(), // Converte para centavos se necessário
      isAvailable: json['is_available'] as bool? ?? true,
      posCode: json['pos_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'option_item_id': optionItemId,
      'parent_option_id': parentOptionId,
      'price': price,
      'is_available': isAvailable,
      'pos_code': posCode,
    };
  }

  OptionItemPrice copyWith({
    int? id,
    int? optionItemId,
    int? parentOptionId,
    int? price,
    bool? isAvailable,
    String? posCode,
  }) {
    return OptionItemPrice(
      id: id ?? this.id,
      optionItemId: optionItemId ?? this.optionItemId,
      parentOptionId: parentOptionId ?? this.parentOptionId,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      posCode: posCode ?? this.posCode,
    );
  }

  @override
  List<Object?> get props => [
        id,
        optionItemId,
        parentOptionId,
        price,
        isAvailable,
        posCode,
      ];
}

















