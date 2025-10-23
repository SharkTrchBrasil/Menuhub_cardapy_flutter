


import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';

import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/cart_product.dart';
import '../models/coupon.dart';
import '../models/product.dart';
// ✅ FUNÇÃO PARA ADICIONAR UM NOVO PRODUTO
void goToProductPage(BuildContext context, Product product) {
  final String slug = product.name.toSlug();
  final String path = '/product/$slug/${product.id}';

  // ✅ CORREÇÃO CRUCIAL: Passa o objeto 'Product' que já temos no 'extra'.
  //    Isso ativa a lógica de "UI Otimista" no Cubit.
  context.go(path, extra: product);
}

// A sua função de editar, se você a criou, já deve estar correta
void goToEditCartItemPage(BuildContext context, CartItem cartItem) {
  final String slug = cartItem.product.name.toSlug();
  final String path = '/product/$slug/${cartItem.product.id}';
  context.go(path, extra: cartItem);
}



void goToCartProductPage(BuildContext context, CartProduct cartProduct) {
  final String slug = cartProduct.toProduct(). name.toSlug();
  final String path = '/$slug/${cartProduct.toProduct().id}';

  context.go(
    path,
    extra: cartProduct,
  );
}
