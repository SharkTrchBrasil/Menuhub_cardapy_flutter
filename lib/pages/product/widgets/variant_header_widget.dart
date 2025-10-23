// Em: lib/pages/product/widgets/variant_header_widget.dart

import 'package:flutter/material.dart';
import 'package:totem/models/cart_variant.dart';

import '../../../helpers/enums/displaymode.dart';
import '../../../models/variant_option.dart';

class VariantHeaderWidget extends StatelessWidget {
  const VariantHeaderWidget({super.key, required this.variant});

  final CartVariant variant;

  String get details {
    final min = variant.minSelectedOptions;
    final max = variant.maxSelectedOptions;

    // Lógica de detalhes copiada do VariantWidget
    if (variant.uiDisplayMode == UIDisplayMode.QUANTITY) {
      if (variant.maxTotalQuantity == null) return 'Adicione quantos itens desejar';
      return 'Escolha até ${variant.maxTotalQuantity} itens no total';
    }
    if (min == 0 && max == 1) return 'Opcional, escolha 1 opção';
    if (min > 0 && min == max) return 'Escolha $max opç${max > 1 ? 'ões' : 'ão'}';
    if (min > 0) return 'Escolha de $min até $max opções';
    return 'Escolha até $max opç${max > 1 ? 'ões' : 'ão'}';
  }

  bool get isRequired => variant.minSelectedOptions > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
     // color: Colors.white, // Fundo branco para não ser transparente
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFFf3f4f6),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            variant.name.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(details, style: TextStyle(color: Colors.grey.shade700)),
              const Spacer(),
              if (isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('OBRIGATÓRIO', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}