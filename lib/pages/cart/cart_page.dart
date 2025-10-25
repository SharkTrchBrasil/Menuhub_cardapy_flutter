import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/category.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/widgets/cart_bottom_bar.dart';
import 'package:totem/pages/cart/widgets/cart_itens_section.dart';
import 'package:totem/pages/cart/widgets/coupon_section.dart';
import 'package:totem/pages/cart/widgets/free_shipping_progress.dart';
import 'package:totem/pages/cart/widgets/min_order_info.dart';
import 'package:totem/pages/cart/widgets/order_summary.dart';
import 'package:totem/pages/cart/widgets/recommended_products.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import '../../helpers/navigation_helper.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../models/update_cart_payload.dart';
import '../../widgets/store_header_card.dart';
import '../address/cubits/delivery_fee_cubit.dart';

import 'cart_state.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  final Set<String> bebidaCategoryNames = const {
    'Bebidas',
    'Refrigerantes',
    'Sucos',
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final storeState = context.watch<StoreCubit>().state;
    final store = storeState.store;
    final allProducts = storeState.products ?? [];
    final allCategories = storeState.categories ?? [];
    final deliveryFeeState = context.watch<DeliveryFeeCubit>().state;

    final minOrder = store?.store_operation_config?.deliveryMinOrder ?? 0;

    int deliveryFeeInCents = 0;
    if (deliveryFeeState is DeliveryFeeLoaded) {
      deliveryFeeInCents = (deliveryFeeState.deliveryFee * 100).toInt();
    }

    return Scaffold(
      backgroundColor: theme.cartBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cartBackgroundColor,
        elevation: 0,
        leading: IconButton(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          icon: Icon(Icons.keyboard_arrow_down, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('SACOLA', style: TextStyle(fontSize: 14)),
        centerTitle: true,
        actions: [
          TextButton(
            style: ButtonStyle(overlayColor: MaterialStateProperty.all(Colors.transparent)),
            onPressed: () => context.read<CartCubit>().clearCart(),
            child: Text('Limpar', style: TextStyle(fontWeight: FontWeight.w600, color: theme.primaryColor)),
          ),
        ],
      ),
      body: BlocListener<CartCubit, CartState>(
        listener: (context, state) {
          if (state.status == CartStatus.success && state.cart.items.isEmpty) {
            context.pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              if (state.status == CartStatus.loading && state.cart.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final cart = state.cart;

              if (cart.items.isEmpty) {
                return const Center(child: Text('Sua sacola está vazia'));
              }

              final recommendedProducts = getRecommendedProducts(
                allProducts: allProducts,
                allCategories: allCategories,
                itemsInCart: cart.items,
                bebidaCategories: bebidaCategoryNames,
              );

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        StoreHeaderCard(
                          showAddItemsButton: true,
                          onAddItemsPressed: () => context.pop(),
                        ),
                        const SizedBox(height: 25),
                        if (minOrder > 0 && (cart.subtotal / 100) < minOrder) ...[
                          MinOrderNotice(minOrder: minOrder),
                          const SizedBox(height: 25),
                        ],
                        CartItemsSection(items: cart.items),
                        const SizedBox(height: 25),
                        Center(
                          child: GestureDetector(
                            onTap: () => context.pop(),
                            child: Text(
                              'Adicionar mais itens',
                              style: TextStyle(fontSize: 16, color: theme.primaryColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        if (recommendedProducts.isNotEmpty)
                          RecommendedProductsSection(
                            recommendedProducts: recommendedProducts,
                            onProductTap: (product) => handleProductTap(context, product),
                          ),
                        const SizedBox(height: 34),
                        CouponSection(couponCode: cart.couponCode),
                        const SizedBox(height: 26),
                        FreeShippingProgress(
                          cartTotal: cart.subtotal / 100.0,
                          threshold: store?.store_operation_config?.freeDeliveryThreshold,
                        ),
                        const SizedBox(height: 40),
                        OrderSummary(
                          subtotalInCents: cart.subtotal,
                          discountInCents: cart.discount,
                          deliveryFeeInCents: deliveryFeeInCents,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  CartBottomBar(
                    subtotal: cart.subtotal / 100.0,
                    finalTotal: cart.total / 100.0,
                    minOrder: minOrder,
                    hasCoupon: cart.couponCode != null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ✅ MÉTODO CORRIGIDO
  Future<void> handleProductTap(BuildContext context, Product product) async {
    final hasVariants = product.variantLinks.any((link) => link.minSelectedOptions > 0);

    if (hasVariants) {
      goToProductPage(context, product);
    } else {
      // 1. Pega o primeiro vínculo de categoria do produto.
      final firstCategoryLink = product.categoryLinks.firstOrNull;

      // 2. Validação de segurança: se o produto não tem categoria, não podemos adicioná-lo.
      if (firstCategoryLink == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: ${product.name} não pertence a nenhuma categoria.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Interrompe a execução
      }

      // 3. Cria o payload com o categoryId correto.
      final payload = UpdateCartItemPayload(
        productId: product.id!,
        categoryId: firstCategoryLink.categoryId, // Usa o ID da primeira categoria encontrada
        quantity: 1,
        variants: null, // Para produtos simples, não há variantes a serem enviadas
      );

      try {
        await context.read<CartCubit>().updateItem(payload);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} adicionado à sacola!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível adicionar ${product.name}. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<Product> getRecommendedProducts({
    required List<Product> allProducts,
    required List<Category> allCategories,
    required List<CartItem> itemsInCart,
    Set<String>? bebidaCategories,
    int maxItems = 10,
  }) {
    final productIdsInCart = itemsInCart.map((item) => item.product.id).toSet();
    final categoriesInCart = itemsInCart
        .expand((item) => item.product.categoryLinks.map((link) => link.categoryId))
        .toSet();
    final beverages = bebidaCategories ?? const {};

    final potentialProducts = allProducts
        .where((p) => !productIdsInCart.contains(p.id) && (p.coverImageUrl?.isNotEmpty ?? false))
        .toList();

    final recommended = <Product>[];

    recommended.addAll(potentialProducts.where((p) {
      return p.categoryLinks.any((link) => categoriesInCart.contains(link.categoryId));
    }));

    recommended.addAll(potentialProducts.where((p) {
      final categoryOfProduct = allCategories.firstWhereOrNull(
            (cat) => p.categoryLinks.any((link) => link.categoryId == cat.id),
      );
      return beverages.any((bev) => categoryOfProduct?.name.toLowerCase().contains(bev.toLowerCase()) ?? false);
    }));

    final uniqueIds = <int>{};
    return recommended.where((product) => uniqueIds.add(product.id!)).take(maxItems).toList();
  }
}