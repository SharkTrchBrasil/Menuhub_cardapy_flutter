// lib/models/product_variant_link.dart

import 'package:totem/models/variant.dart';
import 'package:totem/models/variant_option.dart';
import '../helpers/enums/displaymode.dart';

class ProductVariantLink {
  final UIDisplayMode uiDisplayMode;
  final int minSelectedOptions;
  final int maxSelectedOptions;
  final int? maxTotalQuantity;
  final Variant variant;
  final bool available;
  final int displayOrder;

  ProductVariantLink({
    required this.uiDisplayMode,
    required this.minSelectedOptions,
    required this.maxSelectedOptions,
    this.maxTotalQuantity,
    required this.variant,
    required this.available,
    required this.displayOrder,
  });

  bool get isRequired => minSelectedOptions > 0;

  factory ProductVariantLink.fromJson(Map<String, dynamic> json) {
    UIDisplayMode modeFromString(String? modeStr) {
      switch (modeStr) {
        case "Seleção Única":
        case "SINGLE":
          return UIDisplayMode.SINGLE;
        case "Seleção Múltipla":
        case "MULTIPLE":
          return UIDisplayMode.MULTIPLE;
        case "Seleção com Quantidade":
        case "QUANTITY":
          return UIDisplayMode.QUANTITY;
        default:
          return UIDisplayMode.UNKNOWN;
      }
    }

    return ProductVariantLink(
      uiDisplayMode: modeFromString(json['ui_display_mode']),
      minSelectedOptions: json['min_selected_options'] ?? 0,
      maxSelectedOptions: json['max_selected_options'] ?? 1,
      maxTotalQuantity: json['max_total_quantity'],
      variant: Variant.fromJson(json['variant']),
      available: json['available'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }

  // ✅ MÉTODO TOJSON ADICIONADO
  Map<String, dynamic> toJson() {
    String modeToString(UIDisplayMode mode) {
      switch (mode) {
        case UIDisplayMode.SINGLE:
          return "SINGLE";
        case UIDisplayMode.MULTIPLE:
          return "MULTIPLE";
        case UIDisplayMode.QUANTITY:
          return "QUANTITY";
        case UIDisplayMode.UNKNOWN:
          return "UNKNOWN";
      }
    }

    return {
      'ui_display_mode': modeToString(uiDisplayMode),
      'min_selected_options': minSelectedOptions,
      'max_selected_options': maxSelectedOptions,
      'max_total_quantity': maxTotalQuantity,
      'variant': variant.toJson(),
      'available': available,
      'display_order': displayOrder,
    };
  }

  // ✅ MÉTODO COPYWITH PARA FACILITAR ATUALIZAÇÕES
  ProductVariantLink copyWith({
    UIDisplayMode? uiDisplayMode,
    int? minSelectedOptions,
    int? maxSelectedOptions,
    int? maxTotalQuantity,
    Variant? variant,
    bool? available,
    int? displayOrder,
  }) {
    return ProductVariantLink(
      uiDisplayMode: uiDisplayMode ?? this.uiDisplayMode,
      minSelectedOptions: minSelectedOptions ?? this.minSelectedOptions,
      maxSelectedOptions: maxSelectedOptions ?? this.maxSelectedOptions,
      maxTotalQuantity: maxTotalQuantity ?? this.maxTotalQuantity,
      variant: variant ?? this.variant,
      available: available ?? this.available,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  // ✅ FACTORY EMPTY PARA INSTÂNCIAS VAZIAS
  factory ProductVariantLink.empty() {
    return ProductVariantLink(
      uiDisplayMode: UIDisplayMode.SINGLE,
      minSelectedOptions: 0,
      maxSelectedOptions: 1,
      maxTotalQuantity: null,
      variant: Variant.empty(),
      available: true,
      displayOrder: 0,
    );
  }

  // ✅ HELPER: Verifica se a seleção é válida
  bool isSelectionValid(int selectedCount, {int? totalQuantity}) {
    // Verifica mínimo
    if (selectedCount < minSelectedOptions) return false;

    // Verifica máximo de opções
    if (selectedCount > maxSelectedOptions) return false;

    // Verifica quantidade total (se aplicável)
    if (uiDisplayMode == UIDisplayMode.QUANTITY &&
        maxTotalQuantity != null &&
        totalQuantity != null) {
      if (totalQuantity > maxTotalQuantity!) return false;
    }

    return true;
  }

  // ✅ HELPER: Mensagem de validação
  String getValidationMessage(int selectedCount, {int? totalQuantity}) {
    if (selectedCount < minSelectedOptions) {
      if (minSelectedOptions == 1) {
        return 'Escolha pelo menos uma opção';
      }
      return 'Escolha pelo menos $minSelectedOptions opções';
    }

    if (selectedCount > maxSelectedOptions) {
      if (maxSelectedOptions == 1) {
        return 'Escolha apenas uma opção';
      }
      return 'Escolha no máximo $maxSelectedOptions opções';
    }

    if (uiDisplayMode == UIDisplayMode.QUANTITY &&
        maxTotalQuantity != null &&
        totalQuantity != null &&
        totalQuantity! > maxTotalQuantity!) {
      return 'Quantidade total máxima: $maxTotalQuantity';
    }

    return '';
  }

  // ✅ HELPER: Texto de descrição das regras
  String get rulesDescription {
    switch (uiDisplayMode) {
      case UIDisplayMode.SINGLE:
        return 'Escolha 1 opção';

      case UIDisplayMode.MULTIPLE:
        if (minSelectedOptions == 0 && maxSelectedOptions == 1) {
          return 'Opcional (máx. 1)';
        }
        if (minSelectedOptions == 0) {
          return 'Opcional (máx. $maxSelectedOptions)';
        }
        if (minSelectedOptions == maxSelectedOptions) {
          return 'Escolha $minSelectedOptions opções';
        }
        return 'Escolha de $minSelectedOptions a $maxSelectedOptions opções';

      case UIDisplayMode.QUANTITY:
        if (maxTotalQuantity != null) {
          return 'Quantidade máxima total: $maxTotalQuantity';
        }
        return 'Escolha a quantidade desejada';

      case UIDisplayMode.UNKNOWN:
        return 'Não configurado';
    }
  }

  @override
  String toString() {
    return 'ProductVariantLink(variant: ${variant.name}, mode: ${uiDisplayMode.name}, min: $minSelectedOptions, max: $maxSelectedOptions)';
  }
}