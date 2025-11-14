import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/models/category.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/widgets/cart_bottom_bar.dart';
import 'package:totem/pages/cart/widgets/cart_itens_section.dart';
import 'package:totem/pages/cart/widgets/coupon_section.dart';
import 'package:totem/pages/cart/widgets/free_shipping_progress.dart';
import 'package:totem/pages/cart/widgets/min_order_info.dart';
import 'package:totem/pages/cart/widgets/order_summary.dart';
import 'package:totem/pages/cart/widgets/recommended_products.dart';
import 'package:totem/services/product_recommendation_service.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import '../../helpers/navigation_helper.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../models/update_cart_payload.dart';
import '../../widgets/store_header_card.dart';
import '../address/cubits/delivery_fee_cubit.dart';
import '../main_tab/main_tab_controller.dart';
import 'cart_state.dart';

/// Cart Tab Page - Versão otimizada para funcionar como tab
class CartTabPage extends StatelessWidget {
  const CartTabPage({super.key});

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
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    final minOrder = store?.store_operation_config?.deliveryMinOrder ?? 0;

    int deliveryFeeInCents = 0;
    if (deliveryFeeState is DeliveryFeeLoaded) {
      deliveryFeeInCents = (deliveryFeeState.deliveryFee * 100).toInt();
    }

    return Scaffold(
      backgroundColor: theme.cartBackgroundColor,
      appBar: isMobile
          ? AppBar(
              backgroundColor: theme.cartBackgroundColor,
              elevation: 0,
              title: const Text('SACOLA', style: TextStyle(fontSize: 14)),
              centerTitle: true,
              actions: [
                TextButton(
                  style: ButtonStyle(
                      overlayColor: MaterialStateProperty.all(Colors.transparent)),
                  onPressed: () => context.read<CartCubit>().clearCart(),
                  child: Text(
                    'Limpar',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: theme.primaryColor),
                  ),
                ),
              ],
            )
          : isDesktop
              ? AppBar(
                  backgroundColor: theme.cartBackgroundColor,
                  elevation: 0,
                  title: const Text('CARRINHO DE COMPRAS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  centerTitle: true,
                  actions: [
                    TextButton(
                      style: ButtonStyle(
                          overlayColor:
                              MaterialStateProperty.all(Colors.transparent)),
                      onPressed: () => context.read<CartCubit>().clearCart(),
                      child: Text(
                        'Limpar carrinho',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                )
              : null,
      body: BlocListener<CartCubit, CartState>(
        listener: (context, state) {
          // ✅ Quando carrinho está vazio após limpar, sincroniza o estado das tabs
          // Isso garante que a navegação continue funcionando
          if (state.status == CartStatus.success && state.cart.items.isEmpty) {
            // Sincroniza o MainTabController se disponível
            try {
              final tabController = context.read<MainTabController>();
              tabController.syncState();
            } catch (e) {
              // Se não houver controller (desktop), ignora
            }
          }
        },
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 24.0 : 12.0),
          child: BlocBuilder<CartCubit, CartState>(
            buildWhen: (previous, current) =>
                previous.cart.items.length != current.cart.items.length ||
                previous.cart.total != current.cart.total ||
                previous.status != current.status,
            builder: (context, state) {
              if (state.status == CartStatus.loading && state.cart.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final cart = state.cart;

              if (cart.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Sua sacola está vazia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Adicione produtos para começar',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              // ✅ CORREÇÃO: Calcula sugestões apenas quando itens são adicionados/removidos, não quando quantidade muda
              // Usa um BlocBuilder separado que só reconstrói quando a lista de IDs muda
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        StoreHeaderCard(
                          showAddItemsButton: true,
                          onAddItemsPressed: () {
                            try {
                              final tabController = context.read<MainTabController>();
                              tabController.goToHome();
                            } catch (e) {
                              // Se não encontrar o controller, ignora
                            }
                          },
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
                            onTap: () {
                              try {
                                final tabController = context.read<MainTabController>();
                                tabController.goToHome();
                              } catch (e) {
                                // Se não encontrar o controller, ignora
                              }
                            },
                            child: Text(
                              'Adicionar mais itens',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        // ✅ CORREÇÃO: Widget separado que só reconstrói quando IDs de produtos mudam
                        _RecommendedProductsSection(
                          allProducts: allProducts,
                          allCategories: allCategories,
                          itemsInCart: cart.items,
                          bebidaCategories: bebidaCategoryNames,
                          getRecommendedProducts: getRecommendedProducts,
                          onProductTap: (product) => handleProductTap(context, product),
                        ),
                        const SizedBox(height: 34),
                        CouponSection(couponCode: cart.couponCode),
                        const SizedBox(height: 26),
                        FreeShippingProgress(
                          cartTotal: cart.subtotal / 100.0,
                          threshold:
                              store?.store_operation_config?.freeDeliveryThreshold,
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

  Future<void> handleProductTap(BuildContext context, Product product) async {
    // ✅ Verifica se tem QUALQUER variante (obrigatória ou opcional)
    final hasVariants = product.variantLinks.isNotEmpty;

    if (hasVariants) {
      // Se tem complementos, vai para a tela de detalhes
      goToProductPage(context, product);
    } else {
      final firstCategoryLink = product.categoryLinks.firstOrNull;

      if (firstCategoryLink == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Erro: ${product.name} não pertence a nenhuma categoria.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final payload = UpdateCartItemPayload(
        productId: product.id!,
        categoryId: firstCategoryLink.categoryId,
        quantity: 1,
        variants: null,
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
                  'Não foi possível adicionar ${product.name}. Tente novamente.'),
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
    Set<String>? bebidaCategories, // Mantido para compatibilidade, mas não usado mais
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

// ✅ WIDGET SEPARADO: Só reconstrói quando IDs de produtos mudam, não quando quantidade muda
class _RecommendedProductsSection extends StatelessWidget {
  final List<Product> allProducts;
  final List<Category> allCategories;
  final List<CartItem> itemsInCart;
  final Set<String> bebidaCategories;
  final List<Product> Function({
    required List<Product> allProducts,
    required List<Category> allCategories,
    required List<CartItem> itemsInCart,
    Set<String>? bebidaCategories,
    int maxItems,
  }) getRecommendedProducts;
  final void Function(Product) onProductTap;

  const _RecommendedProductsSection({
    required this.allProducts,
    required this.allCategories,
    required this.itemsInCart,
    required this.bebidaCategories,
    required this.getRecommendedProducts,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      // ✅ Só reconstrói quando a lista de IDs de produtos muda, não quando quantidade muda
      buildWhen: (previous, current) {
        final previousIds = previous.cart.items.map((item) => item.product.id).toSet();
        final currentIds = current.cart.items.map((item) => item.product.id).toSet();
        return previousIds != currentIds;
      },
      builder: (context, state) {
        final recommendedProducts = getRecommendedProducts(
          allProducts: allProducts,
          allCategories: allCategories,
          itemsInCart: state.cart.items,
          bebidaCategories: bebidaCategories,
        );

        if (recommendedProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return RecommendedProductsSection(
          recommendedProducts: recommendedProducts,
          onProductTap: onProductTap,
        );
      },
    );
  }
}

