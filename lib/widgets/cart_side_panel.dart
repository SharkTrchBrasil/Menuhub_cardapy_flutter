import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';
import 'package:totem/pages/cart/widgets/cart_bottom_bar.dart';
import 'package:totem/pages/cart/widgets/cart_itens_section.dart';
import 'package:totem/pages/cart/widgets/coupon_section.dart';
import 'package:totem/pages/cart/widgets/free_shipping_progress.dart';
import 'package:totem/pages/cart/widgets/min_order_info.dart';
import 'package:totem/pages/cart/widgets/order_summary.dart';
import 'package:totem/pages/cart/widgets/recommended_products.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/models/cart_item.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/update_cart_payload.dart';
import 'package:totem/models/category.dart';
import 'package:totem/widgets/store_header_card.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/services/product_recommendation_service.dart';

/// Função helper para abrir o sidepanel do carrinho
void showCartSidePanel(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Carrinho',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const CartSidePanel();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Animação de slide da direita para esquerda
      final slideAnimation = Tween<Offset>(
        begin: const Offset(1.0, 0.0), // Começa da direita
        end: Offset.zero, // Termina na posição normal
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ));

      return SlideTransition(
        position: slideAnimation,
        child: child,
      );
    },
  );
}

/// SidePanel do carrinho que desliza da direita para esquerda (estilo iFood)
class CartSidePanel extends StatelessWidget {
  const CartSidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.4; // 40% da largura da tela
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelWidth,
          constraints: const BoxConstraints(maxWidth: 500), // Limite máximo
          height: double.infinity,
          decoration: BoxDecoration(
            color: theme.cartBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: BlocListener<CartCubit, CartState>(
            listener: (context, state) {
              // Fecha o sidepanel se o carrinho ficar vazio
              if (state.status == CartStatus.success && state.cart.items.isEmpty) {
                Navigator.of(context).pop();
              }
            },
            child: Column(
              children: [
                // Header do SidePanel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.cartBackgroundColor,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SACOLA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.onBackgroundColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey.shade600),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Fechar',
                      ),
                    ],
                  ),
                ),
                // Conteúdo do carrinho (usa o CartPage sem AppBar)
                Expanded(
                  child: _CartContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Conteúdo do carrinho sem AppBar (para usar no sidepanel)
class _CartContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cartState = context.watch<CartCubit>().state;

    if (cartState.status == CartStatus.loading && cartState.cart.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final cart = cartState.cart;

    if (cart.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Sua sacola está vazia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione itens',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Usa o CartPage completo, mas vamos criar uma versão sem AppBar
    // Por enquanto, vamos usar o Scaffold sem AppBar
    return const CartPageBody();
  }
}

/// Body do CartPage sem AppBar para usar no sidepanel
class CartPageBody extends StatelessWidget {
  const CartPageBody({super.key});

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

    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        if (state.status == CartStatus.loading && state.cart.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final cart = state.cart;

        if (cart.items.isEmpty) {
          return const SizedBox.shrink(); // Já tratado no _CartContent
        }

        final recommendedProducts = _getRecommendedProducts(
          allProducts: allProducts,
          allCategories: allCategories,
          itemsInCart: cart.items,
        );

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    StoreHeaderCard(
                      showAddItemsButton: true,
                      onAddItemsPressed: () => Navigator.of(context).pop(),
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
                        onTap: () => Navigator.of(context).pop(),
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
                        onProductTap: (product) => _handleProductTap(context, product),
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
          ),
        );
      },
    );
  }

  List<Product> _getRecommendedProducts({
    required List<Product> allProducts,
    required List<Category> allCategories,
    required List<CartItem> itemsInCart,
    int maxItems = 10,
  }) {
    return ProductRecommendationService.getRecommendedProducts(
      allProducts: allProducts,
      allCategories: allCategories,
      itemsInCart: itemsInCart,
      maxItems: maxItems,
    );
  }

  Future<void> _handleProductTap(BuildContext context, Product product) async {
    final hasVariants = product.variantLinks.isNotEmpty;

    if (hasVariants) {
      context.push('/product/${product.id}');
    } else {
      final firstCategoryLink = product.categoryLinks.firstOrNull;
      if (firstCategoryLink == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: ${product.name} não pertence a nenhuma categoria.'),
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
              content: Text('Não foi possível adicionar ${product.name}. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

