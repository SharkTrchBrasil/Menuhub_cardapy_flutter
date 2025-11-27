import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/services/store_status_service.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:collection/collection.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/category.dart';

/// Classe helper para navegação e exibição de dialogs de produtos
class NavigationHelper {
  /// Mostra o dialog de produto usando a página de detalhes unificada
  /// Funciona para todos os tipos de produtos (GENERAL, CUSTOMIZABLE, etc.)
  static void showProductDialog({
    required BuildContext context,
    required Product product,
    Category? category,
    int? sizeId, // ✅ Novo parâmetro
  }) {
    // Se categoria não foi passada, tenta encontrar no StoreCubit
    if (category == null) {
      final storeState = context.read<StoreCubit>().state;
      final categoryId = product.categoryLinks.firstOrNull?.categoryId;
      if (categoryId != null) {
        category = storeState.categories.firstWhereOrNull((c) => c.id == categoryId);
      }
    }

    // Usa o mesmo dialog de produtos GENERAL para todos os tipos, incluindo pizzas
    goToProductPage(context, product, category: category, sizeId: sizeId);
  }
}

// Navega para a página de detalhes de um produto para adicioná-lo ao carrinho
void goToProductPage(BuildContext context, Product product, {Category? category, int? sizeId}) {
  // Se categoria não foi passada, tenta encontrar no StoreCubit
  if (category == null) {
    final storeState = context.read<StoreCubit>().state;
    final categoryId = product.categoryLinks.firstOrNull?.categoryId;
    if (categoryId != null) {
      category = storeState.categories.firstWhereOrNull((c) => c.id == categoryId);
    }
  }

  final String slug = product.name.toSlug();

  // ✅ Adiciona query param se sizeId existir
  String location = '/product/$slug/${product.id}';
  if (sizeId != null) {
    location += '?size=$sizeId';
  }

  context.go(location, extra: product);
}

// Navega para a página de detalhes para EDITAR um item que JÁ ESTÁ no carrinho
void goToEditCartItemPage(BuildContext context, CartItem cartItem) {
  final String slug = cartItem.product.name.toSlug();

  // ✅ CORREÇÃO FINAL: Também usa o caminho absoluto aqui para consistência.
  context.go('/product/$slug/${cartItem.product.id}', extra: cartItem);
}

/// Navega para o carrinho, mas valida o status da loja primeiro
void goToCart(BuildContext context) {
  final storeState = context.read<StoreCubit>().state;
  final store = storeState.store;

  if (!StoreStatusService.canOpenCart(store)) {
    final status = StoreStatusService.validateStoreStatus(store);
    final message = StoreStatusService.getFriendlyMessage(status);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
    return;
  }

  context.go('/cart');
}
