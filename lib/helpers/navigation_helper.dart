import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

// Navega para a página de detalhes de um produto para adicioná-lo ao carrinho
void goToProductPage(BuildContext context, Product product) {
  final String slug = product.name.toSlug();

  // ✅ CORREÇÃO FINAL: Usa o caminho absoluto com a barra inicial '/',
  // exatamente como no seu backup que funcionava. Isso garante que a
  // navegação funcione de forma consistente, não importa de onde ela seja chamada.
  context.go('/product/$slug/${product.id}', extra: product);
}

// Navega para a página de detalhes para EDITAR um item que JÁ ESTÁ no carrinho
void goToEditCartItemPage(BuildContext context, CartItem cartItem) {
  final String slug = cartItem.product.name.toSlug();

  // ✅ CORREÇÃO FINAL: Também usa o caminho absoluto aqui para consistência.
  context.go('/product/$slug/${cartItem.product.id}', extra: cartItem);
}

// A função `goToCartProductPage` foi corretamente removida, pois a lógica
// foi unificada nas duas funções acima, que são mais claras e seguras.