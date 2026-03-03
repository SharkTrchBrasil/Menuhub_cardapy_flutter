import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/services/store_status_service.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:collection/collection.dart';
import 'package:totem/core/utils/id_obfuscator.dart'; // ✅ ENTERPRISE: Ofuscação de IDs

import '../models/cart_item.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../helpers/enums/product_status.dart';
import '../helpers/enums/product_type.dart';

/// Classe helper para navegação e exibição de dialogs de produtos
class NavigationHelper {
  /// Mostra o dialog de produto usando a página de detalhes unificada
  /// Funciona para todos os tipos de produtos (GENERAL, CUSTOMIZABLE, etc.)
  static void showProductDialog({
    required BuildContext context,
    Product?
    product, // ✅ CORREÇÃO: Tornado opcional para suportar pizzas sem produto
    Category? category,
    int? sizeId, // ✅ Novo parâmetro
  }) {
    // ✅ VALIDAÇÃO: Pelo menos product OU category deve ser fornecido
    if (product == null && category == null) {
      print(
        '⚠️ [NavigationHelper] showProductDialog requer product OU category',
      );
      return;
    }

    // Se categoria não foi passada, tenta encontrar no CatalogCubit
    if (category == null && product != null) {
      final catalogCubit = context.read<CatalogCubit>();
      final categoryId = product.categoryLinks.firstOrNull?.categoryId;
      if (categoryId != null) {
        category = catalogCubit.state.categories?.firstWhereOrNull(
          (c) => c.id == categoryId,
        );
      }
    }

    // Usa o mesmo dialog de produtos GENERAL para todos os tipos, incluindo pizzas
    goToProductPage(context, product, category: category, sizeId: sizeId);
  }
}

// Navega para a página de detalhes de um produto para adicioná-lo ao carrinho
void goToProductPage(
  BuildContext context,
  Product? product, {
  Category? category,
  int? sizeId,
  bool fromCart = false,
}) {
  // ✅ VALIDAÇÃO: Requer pelo menos product OU category
  if (product == null && category == null) {
    print('⚠️ [goToProductPage] Requer product OU category');
    return;
  }

  // Se categoria não foi passada, tenta encontrar no CatalogCubit
  if (category == null && product != null) {
    final catalogCubit = context.read<CatalogCubit>();
    final categoryId = product.categoryLinks.firstOrNull?.categoryId;
    if (categoryId != null) {
      category = catalogCubit.state.categories?.firstWhereOrNull(
        (c) => c.id == categoryId,
      );
    }
  }

  // ✅ Para pizzas sem produto, usa a categoria como base
  if (product == null && category != null) {
    // Navega para uma página de customização de pizza
    // Usa ID da categoria como slug temporário
    String location = '/category/${category.name.toSlug()}/${category.id}';

    final queryParams = <String>[];
    if (sizeId != null) queryParams.add('size=$sizeId');
    if (fromCart) queryParams.add('fromCart=true');

    if (queryParams.isNotEmpty) {
      location += '?${queryParams.join('&')}';
    }

    context.go(location, extra: category);
    return;
  }

  // ✅ ENTERPRISE: Usa ID ofuscado na URL
  final productUrl = IdObfuscator.createProductUrl(product!.name, product.id!);
  String location = '/product/$productUrl';

  final queryParams = <String>[];
  if (sizeId != null) queryParams.add('size=$sizeId');
  if (fromCart) queryParams.add('fromCart=true');

  if (queryParams.isNotEmpty) {
    location += '?${queryParams.join('&')}';
  }

  context.go(location, extra: product);
}

// Navega para a página de detalhes para EDITAR um item que JÁ ESTÁ no carrinho
void goToEditCartItemPage(BuildContext context, CartItem cartItem) {
  // ✅ ENTERPRISE: Usa ID ofuscado na URL
  final productUrl = IdObfuscator.createProductUrl(
    cartItem.product.name,
    cartItem.product.id!,
  );
  context.go('/product/$productUrl', extra: cartItem);
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
