import 'package:totem/models/variant.dart';
import 'package:totem/models/variant_option.dart';

import '../helpers/enums/displaymode.dart';



class ProductVariantLink {
  final UIDisplayMode uiDisplayMode;
  final int minSelectedOptions;
  final int maxSelectedOptions;
  final int? maxTotalQuantity;
  final Variant variant; // O template Variant está aninhado aqui

  // ✅ ADICIONADO: Campos para disponibilidade e ordem
  final bool available;
  final int displayOrder;

  ProductVariantLink({
    required this.uiDisplayMode,
    required this.minSelectedOptions,
    required this.maxSelectedOptions,
    this.maxTotalQuantity,
    required this.variant,
    required this.available, // ✅ Adicionado
    required this.displayOrder, // ✅ Adicionado
  });

  bool get isRequired => minSelectedOptions > 0;

  factory ProductVariantLink.fromJson(Map<String, dynamic> json) {
    UIDisplayMode modeFromString(String? modeStr) {
      // ✅ SUGESTÃO: É mais robusto receber chaves como 'SINGLE' ou 'MULTIPLE' do backend.
      // Mas mantendo a lógica atual:
      switch (modeStr) {
        case "Seleção Única":
          return UIDisplayMode.SINGLE;
        case "Seleção Múltipla":
          return UIDisplayMode.MULTIPLE;
        case "Seleção com Quantidade":
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
      // ✅ Lendo os novos campos do JSON
      available: json['available'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }
}