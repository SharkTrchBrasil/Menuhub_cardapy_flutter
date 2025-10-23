import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/cart_variant.dart';
import 'package:totem/models/cart_variant_option.dart';
import 'package:totem/models/variant_option.dart'; // Garanta que este import tem o UIDisplayMode
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/widgets/variant_header_widget.dart';
import 'package:totem/pages/product/widgets/variant_option_item.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

class VariantWidget extends StatelessWidget {
  const VariantWidget({
    super.key,
    required this.onOptionUpdated,
    required this.variant,
  });

  final CartVariant variant;
  final void Function(CartVariant, CartVariantOption, int) onOptionUpdated;


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ AQUI: Substitua toda a lógica do cabeçalho antigo por este novo widget.
        VariantHeaderWidget(variant: variant),

        // A lista de opções permanece exatamente a mesma.
        ListView.separated(
          padding: const EdgeInsets.only(top: 8.0), // Adicionado um pequeno espaçamento
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: variant.cartOptions.length,
          itemBuilder: (_, index) {
            final option = variant.cartOptions[index];
            return VariantOptionItem(
              variant: variant,
              option: option,
              onUpdate: (newQuantity) {
                onOptionUpdated(variant, option, newQuantity);
              },
            );
          },
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }
}


