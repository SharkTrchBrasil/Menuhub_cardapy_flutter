import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/cart_item.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';
import 'package:totem/widgets/unified_cart_bottom_bar.dart';
import 'package:totem/pages/cart/widgets/cart_itens_section.dart';
import 'package:totem/pages/cart/widgets/coupon_section.dart';
import 'package:totem/pages/cart/widgets/free_shipping_progress.dart';
import 'package:totem/pages/cart/widgets/min_order_info.dart';
import 'package:totem/widgets/order_summary_card.dart';
import 'package:totem/pages/cart/widgets/recommended_products.dart';
import 'package:totem/services/product_recommendation_service.dart';
import 'package:totem/widgets/store_header_card.dart';
import 'package:totem/pages/main_tab/main_tab_controller.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/helpers/navigation_helper.dart';
import 'package:totem/models/update_cart_payload.dart';
import 'package:collection/collection.dart';

/// Desktop Cart Page
/// Implementação específica para desktop
class DesktopCart extends StatelessWidget {
  const DesktopCart({super.key});

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

    return Scaffold(
      backgroundColor: theme.cartBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cartBackgroundColor,
        elevation: 0,
        title: const Text(
          'CARRINHO DE COMPRAS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            style: ButtonStyle(
              overlayColor: MaterialStateProperty.all(Colors.transparent),
            ),
            onPressed: () => context.read<CartCubit>().clearCart(),
            child: Text(
              'Limpar carrinho',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: BlocListener<CartCubit, CartState>(
        listener: (context, state) {
          if (state.status == CartStatus.success && state.cart.items.isEmpty) {
            try {
              final tabController = context.read<MainTabController>();
              tabController.syncState();
            } catch (e) {
              // Ignora se não houver controller (desktop)
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: BlocBuilder<CartCubit, CartState>(
            buildWhen:
                (previous, current) =>
                    previous.cart != current.cart ||
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
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Seu carrinho está vazio',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Adicione produtos para começar suas compras',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        StoreHeaderCard(
                          showAddItemsButton: true,
                          onAddItemsPressed: () {
                            try {
                              final tabController =
                                  context.read<MainTabController>();
                              tabController.goToHome();
                            } catch (e) {
                              // Ignora se não encontrar o controller
                            }
                          },
                        ),
                        const SizedBox(height: 32),
                        if (minOrder > 0 &&
                            (cart.subtotal / 100) < minOrder) ...[
                          MinOrderNotice(minOrder: minOrder),
                          const SizedBox(height: 32),
                        ],
                        CartItemsSection(items: cart.items),
                        const SizedBox(height: 32),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              try {
                                final tabController =
                                    context.read<MainTabController>();
                                tabController.goToHome();
                              } catch (e) {
                                // Ignora se não encontrar o controller
                              }
                            },
                            child: Text(
                              'Adicionar mais itens',
                              style: TextStyle(
                                fontSize: 18,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _RecommendedProductsSection(
                          allProducts: allProducts,
                          allCategories: allCategories,
                          itemsInCart: cart.items,
                          bebidaCategories: bebidaCategoryNames,
                          onProductTap:
                              (product) => _handleProductTap(context, product),
                        ),
                        const SizedBox(height: 40),
                        CouponSection(couponCode: cart.couponCode),
                        const SizedBox(height: 32),
                        FreeShippingProgress(
                          cartTotal: cart.subtotal / 100.0,
                          threshold:
                              store?.getFreeDeliveryThresholdForDelivery(),
                        ),
                        const SizedBox(height: 48),
                        OrderSummaryCard(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                  const UnifiedCartBottomBar(
                    variant: CartBottomBarVariant.cart,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleProductTap(BuildContext context, Product product) async {
    // ✅ CORREÇÃO: Verifica se tem variantes/complementos OU é pizza (tem prices)
    final hasVariants = product.variantLinks.isNotEmpty;
    final isPizza = product.prices.isNotEmpty; // Pizza tem preços por sabor

    // ✅ Se tem complementos OU é pizza, abre tela de detalhes (igual na home)
    if (hasVariants || isPizza) {
      goToProductPage(context, product, fromCart: true);
    } else {
      final firstCategoryLink = product.categoryLinks.firstOrNull;

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
              content: Text('${product.name} adicionado ao carrinho!'),
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
}

// ✅ MELHORADO: StatefulWidget para cachear recomendações e evitar reconstruções visíveis
class _RecommendedProductsSection extends StatefulWidget {
  final List<Product> allProducts;
  final List<Category> allCategories;
  final List<CartItem> itemsInCart;
  final Set<String> bebidaCategories;
  final void Function(Product) onProductTap;

  const _RecommendedProductsSection({
    required this.allProducts,
    required this.allCategories,
    required this.itemsInCart,
    required this.bebidaCategories,
    required this.onProductTap,
  });

  @override
  State<_RecommendedProductsSection> createState() =>
      _RecommendedProductsSectionState();
}

class _RecommendedProductsSectionState
    extends State<_RecommendedProductsSection> {
  List<Product> _cachedRecommendations = [];
  List<int> _lastProductIds = []; // ✅ Lista ordenada para comparação estável
  int _lastAllProductsCount = 0; // ✅ NOVO: Rastreia quando allProducts muda
  String _stableKey = ''; // ✅ Chave estável para o widget

  @override
  void initState() {
    super.initState();
    _updateRecommendations(widget.itemsInCart, forceUpdate: true);
  }

  void _updateRecommendations(
    List<CartItem> items, {
    bool forceUpdate = false,
  }) {
    // ✅ Cria lista ordenada de IDs para comparação estável
    final currentProductIds =
        items.map((item) => item.product.id ?? 0).where((id) => id > 0).toList()
          ..sort();

    final productsChanged = !_listEquals(_lastProductIds, currentProductIds);
    final allProductsChanged =
        _lastAllProductsCount != widget.allProducts.length;

    // ✅ CORREÇÃO: Recalcula se produtos do carrinho mudaram OU se allProducts foi carregada
    if (productsChanged || allProductsChanged || forceUpdate) {
      _lastProductIds = currentProductIds;
      _lastAllProductsCount = widget.allProducts.length;
      _stableKey =
          '${currentProductIds.join('-')}_${widget.allProducts.length}';

      _cachedRecommendations =
          ProductRecommendationService.getRecommendedProducts(
            allProducts: widget.allProducts,
            allCategories: widget.allCategories,
            itemsInCart: items,
            maxItems: 10,
          );
    }
  }

  // ✅ Helper para comparar listas de forma segura
  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedRecommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return RecommendedProductsSection(
      key: ValueKey(_stableKey),
      recommendedProducts: _cachedRecommendations,
      allCategories: widget.allCategories,
      onProductTap: widget.onProductTap,
    );
  }

  @override
  void didUpdateWidget(covariant _RecommendedProductsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRecommendations(widget.itemsInCart);
  }
}
