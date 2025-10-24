// Em: sua_pasta/cart_items_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ✅ Importa os novos modelos e widgets
import 'package:totem/models/cart.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

import '../../../models/cart_item.dart';
import 'cart_product_list_item.dart'; // O nosso widget de item corrigido

class CartItemsSection extends StatelessWidget {
  // ✅ MUDANÇA AQUI: Agora recebe uma lista de `CartItem`
  final List<CartItem> items;

  const CartItemsSection({required this.items, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 30),
          child: Text(
            'Itens adicionados',
            style: TextStyle(
              fontSize: 16,
              color: theme.cartTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // A lógica de mapeamento permanece, mas agora é mais simples
        // e funciona com os tipos corretos.
        ...items.map(
              (item) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            // O CartItemListItem espera um `CartItem`, que é exatamente
            // o que estamos passando agora.
            child: CartItemListItem(
              item: item,
            ),
          ),
        ),
      ],
    );
  }
}