import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/category.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/widgets/unified_cart_bottom_bar.dart';
import 'package:totem/pages/cart/widgets/cart_itens_section.dart';
import 'package:totem/widgets/order_summary_card.dart';
import 'package:totem/pages/cart/widgets/coupon_section.dart';
import 'package:totem/pages/cart/widgets/free_shipping_progress.dart';
import 'package:totem/pages/cart/widgets/min_order_info.dart';
import 'package:totem/pages/cart/widgets/recommended_products.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import '../../helpers/navigation_helper.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../models/update_cart_payload.dart';
import '../../widgets/store_header_card.dart';
import '../address/cubits/delivery_fee_cubit.dart';
import '../../services/product_recommendation_service.dart';

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
    final catalogState = context.watch<CatalogCubit>().state;
    final store = storeState.store;
    final allProducts = catalogState.products ?? [];
    final allCategories = catalogState.activeCategories;
    final deliveryFeeState = context.watch<DeliveryFeeCubit>().state;

    final minOrder = store?.getMinOrderForDelivery() ?? 0;

    int deliveryFeeInCents = 0;
    if (deliveryFeeState is DeliveryFeeLoaded) {
      deliveryFeeInCents = (deliveryFeeState.deliveryFee * 100).toInt();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          icon: const Icon(Icons.expand_more, color: Colors.black, size: 28),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'SACOLA',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            style: ButtonStyle(
              overlayColor: MaterialStateProperty.all(Colors.transparent),
            ),
            onPressed: () => context.read<CartCubit>().clearCart(),
            child: const Text(
              'Limpar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFFE91E63), // Pink/Red color from image
              ),
            ),
          ),
        ],
      ),
      body: BlocListener<CartCubit, CartState>(
        listener: (context, state) {
          if (state.status == CartStatus.success && state.cart.items.isEmpty) {
            context.go('/');
          }
        },
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
                    padding: const EdgeInsets.all(12.0),
                    children: [
                      StoreHeaderCard(
                        showAddItemsButton: true,
                        onAddItemsPressed: () => context.go('/'),
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
                          onTap: () => context.go('/'),
                          child: Text(
                            'Adicionar mais itens',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      if (recommendedProducts.isNotEmpty)
                        RecommendedProductsSection(
                          recommendedProducts: recommendedProducts,
                          allCategories: allCategories,
                          onProductTap:
                              (product) => handleProductTap(context, product),
                        ),
                      const SizedBox(height: 34),
                      CouponSection(couponCode: cart.couponCode),
                      const SizedBox(height: 26),
                      FreeShippingProgress(
                        cartTotal: cart.subtotal / 100.0,
                        threshold: store?.getFreeDeliveryThresholdForDelivery(),
                      ),
                      const SizedBox(height: 40),

                      const OrderSummaryCard(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                const UnifiedCartBottomBar(variant: CartBottomBarVariant.cart),
              ],
            );
          },
        ),
      ),
    );
  }

  // ✅ MÉTODO CORRIGIDO
  Future<void> handleProductTap(BuildContext context, Product product) async {
    // ✅ CORREÇÃO: Verifica se tem variantes/complementos OU é pizza (tem prices)
    final hasVariants = product.variantLinks.isNotEmpty;
    final isPizza = product.prices.isNotEmpty; // Pizza tem preços por sabor

    // ✅ Se tem complementos OU é pizza, abre tela de detalhes (igual na home)
    if (hasVariants || isPizza) {
      goToProductPage(context, product, fromCart: true);
    } else {
      // 1. Pega o primeiro vínculo de categoria do produto.
      final firstCategoryLink = product.categoryLinks.firstOrNull;

      // 2. Validação de segurança: se o produto não tem categoria, não podemos adicioná-lo.
      if (firstCategoryLink == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro: ${product.name} não pertence a nenhuma categoria.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Interrompe a execução
      }

      // 3. Cria o payload com o categoryId correto.
      final payload = UpdateCartItemPayload(
        productId: product.id!,
        categoryId:
            firstCategoryLink
                .categoryId, // Usa o ID da primeira categoria encontrada
        quantity: 1,
        variants:
            null, // Para produtos simples, não há variantes a serem enviadas
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
              content: Text(
                'Não foi possível adicionar ${product.name}. Tente novamente.',
              ),
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
    Set<String>?
    bebidaCategories, // Mantido para compatibilidade, mas não usado mais
    int maxItems = 10,
  }) {
    // ✅ Usa o serviço profissional de recomendações
    return ProductRecommendationService.getRecommendedProducts(
      allProducts: allProducts,
      allCategories: allCategories,
      itemsInCart: itemsInCart,
      maxItems: maxItems,
    );
  }
}
