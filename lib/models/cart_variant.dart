// Em: lib/models/cart_variant.dart

import 'package:totem/models/cart_variant_option.dart';
import 'package:totem/models/product_variant_link.dart';
import 'package:totem/models/variant_option.dart';

import '../helpers/enums/displaymode.dart';

class CartVariant {
  // --- Propriedades permanecem as mesmas ---
  final int id;
  final String name;
  final UIDisplayMode uiDisplayMode;
  final int minSelectedOptions;
  final int maxSelectedOptions;
  final int? maxTotalQuantity;
  final List<CartVariantOption> cartOptions;

  CartVariant({
    required this.id,
    required this.name,
    required this.uiDisplayMode,
    required this.minSelectedOptions,
    required this.maxSelectedOptions,
    this.maxTotalQuantity,
    required this.cartOptions,
  });

  // Construtores e Getters permanecem os mesmos...
  factory CartVariant.fromProductVariantLink(
      ProductVariantLink link, {
        List<CartVariantOption>? options, // <-- Adicione este parâmetro
      }) {

    return CartVariant(
      id: link.variant.id!,
      name: link.variant.name,
      uiDisplayMode: link.uiDisplayMode,
      minSelectedOptions: link.minSelectedOptions,
      maxSelectedOptions: link.maxSelectedOptions,
      maxTotalQuantity: link.maxTotalQuantity,
    cartOptions: options ??
    link.variant.options
        .map((option) => CartVariantOption.fromVariantOption(option))
        .toList(),

    );
  }

  bool get isRequired => minSelectedOptions > 0;
  int get totalQuantitySelected => cartOptions.fold<int>(0, (sum, option) => sum + option.quantity);
  int get distinctOptionsSelected => cartOptions.where((option) => option.quantity > 0).length;
  int get totalPrice => cartOptions.fold<int>(0, (sum, option) => sum + (option.price * option.quantity));
  bool get isValid => !isRequired || distinctOptionsSelected >= minSelectedOptions;

  /// ✅ NOVO MÉTODO: O CÉREBRO DAS REGRAS DA VARIANTE
  /// Recebe uma opção e a nova quantidade desejada, e retorna um *novo* CartVariant
  /// com o estado atualizado e as regras aplicadas.
  CartVariant updateOption(CartVariantOption optionToUpdate, int newQuantity) {
    List<CartVariantOption> newOptions = List.from(cartOptions);
    final optionIndex = newOptions.indexWhere((o) => o.id == optionToUpdate.id);

    if (optionIndex == -1) return this; // Opção não encontrada, não faz nada

    // Aplica as regras baseado no tipo de exibição
    switch (uiDisplayMode) {
      case UIDisplayMode.SINGLE:
      // Zera todos e define a quantidade da opção selecionada para 1.
        newOptions = newOptions.map((opt) {
          return opt.copyWith(quantity: opt.id == optionToUpdate.id ? 1 : 0);
        }).toList();
        break;

      case UIDisplayMode.MULTIPLE:
        final isSelecting = newQuantity > 0;
        // Permite selecionar apenas se não tiver atingido o máximo.
        if (isSelecting && distinctOptionsSelected >= maxSelectedOptions) {
          // Se já atingiu o máximo e está tentando selecionar uma *nova* opção, impede.
          if (newOptions[optionIndex].quantity == 0) {
            return this;
          }
        }
        newOptions[optionIndex] = newOptions[optionIndex].copyWith(quantity: newQuantity > 0 ? 1 : 0);
        break;

      case UIDisplayMode.QUANTITY:
        final currentTotal = totalQuantitySelected;
        final difference = newQuantity - newOptions[optionIndex].quantity;
        // Permite o incremento apenas se não for exceder o total máximo.
        if (maxTotalQuantity != null && (currentTotal + difference > maxTotalQuantity!)) {
          return this;
        }
        newOptions[optionIndex] = newOptions[optionIndex].copyWith(quantity: newQuantity < 0 ? 0 : newQuantity);
        break;

      default:
        break; // Não faz nada para tipos desconhecidos
    }

    // Retorna uma nova instância de si mesmo com as opções atualizadas.
    return copyWith(options: newOptions);
  }

  CartVariant copyWith({List<CartVariantOption>? options}) {
    return CartVariant(
      id: id,
      name: name,
      uiDisplayMode: uiDisplayMode,
      minSelectedOptions: minSelectedOptions,
      maxSelectedOptions: maxSelectedOptions,
      maxTotalQuantity: maxTotalQuantity,
      cartOptions: options ?? cartOptions,
    );
  }

  // fromJson e toJson permanecem os mesmos...
  factory CartVariant.fromJson(Map<String, dynamic> json) {
    return CartVariant(
      id: json['variant_id'],
      name: '',
      uiDisplayMode: UIDisplayMode.UNKNOWN,
      minSelectedOptions: 0,
      maxSelectedOptions: 99,
      maxTotalQuantity: null,
      cartOptions: (json['options'] as List)
          .map((optJson) => CartVariantOption.fromJson(optJson as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variant_id': id,
      'options': cartOptions
          .where((o) => o.quantity > 0)
          .map((o) => {
        'variant_option_id': o.id,
        'quantity': o.quantity,
        'price': o.price,
      })
          .toList(),
    };
  }
}