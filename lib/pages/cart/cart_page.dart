import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/cart.dart';

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


import '../../helpers/navigation_helper.dart';
import '../../models/cart_product.dart';
import '../../models/product.dart';
import '../../models/update_cart_payload.dart';
import '../../widgets/store_header_card.dart';
import '../address/cubits/delivery_fee_cubit.dart';


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
    final store = context.watch<StoreCubit>().state.store;
    final deliveryFeeState = context.watch<DeliveryFeeCubit>().state;
    final allProducts = context.read<StoreCubit>().state.products ?? [];

    final minOrder = store?.store_operation_config?.deliveryMinOrder ?? 0;

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
            style: ButtonStyle(
              overlayColor: MaterialStateProperty.all(Colors.transparent),
            ),
            onPressed: () => context.read<CartCubit>().clearCart(),
            child: Text(
              'Limpar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: BlocListener<CartCubit, CartState>(



        // Adicione o BlocListener aqui
        listener: (context, state) {
          if (state.cart.items.isEmpty && state.status == CartStatus.success) {
            context.pop();
          }

        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              // ✅ FONTE ÚNICA DA VERDADE: Pegamos o objeto `cart` do estado.
              final cart = state.cart;


              if (cart.items.isEmpty) {
                // O listener acima já vai fechar a tela, mas é bom ter um fallback.
                return const Center(child: Text('Sua sacola está vazia'));
              }


              final recommendedProducts = getRecommendedProducts(
                allProducts: allProducts,
                itemsInCart: cart.items, // Passa a lista de CartItem
                bebidaCategories: bebidaCategoryNames,
              );




              // final hasCoupon = state.products.any((p) => p.coupon != null);
              //
              // // ✅ CORREÇÃO: Acessando os dados do produto via 'sourceProduct'
              // final hasPromotion = state.products.any((p) =>
              // p.sourceProduct.activatePromotion == true &&
              //     (p.sourceProduct.promotionPrice ?? 0) < p.sourceProduct.basePrice);


              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        StoreHeaderCard(
                          showAddItemsButton: true, // Mostra o botão
                          onAddItemsPressed: () {
                            context.pop(); // Ou sua rota para o cardápio
                          },
                        ),
                        const SizedBox(height: 25),

                        if (minOrder > 0 && cart.subtotal < minOrder)
                          MinOrderNotice(minOrder: minOrder),
                        if (minOrder > 0 && cart.subtotal < minOrder)
                        const SizedBox(height: 25),
                        CartItemsSection(items: cart.items),

                        const SizedBox(height: 25),
                        Center(
                          child: GestureDetector(
                            onTap: () => context.pop(),
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
                          ),
                        const SizedBox(height: 34),

                        // ✅ Passa apenas o código do cupom
                        CouponSection(couponCode: cart.couponCode),


                        const SizedBox(height: 26),

                        // ✅ Passa o subtotal correto
                        FreeShippingProgress(
                          cartTotal: cart.subtotal / 100.0,
                          threshold: store?.store_operation_config?.freeDeliveryThreshold,
                        ),
                        const SizedBox(height: 40),


                        //
                        // // ✅ WIDGET ATUALIZADO COM OS DADOS CORRETOS
                        // OrderSummary(
                        //   subtotalInCents: cart.subtotal,
                        //   discountInCents: cart.discount, // <-- CORREÇÃO: Pega o desconto direto do carrinho
                        //   deliveryFeeInCents: (deliveryFeeState.deliveryFee * 100).toInt(), // <-- ADICIONADO: Pega a taxa e converte para centavos
                        // ),




                      ],
                    ),
                  ),

                  // ✅ CORREÇÃO: Passando os getters corretos do CartState
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

// ✅ [VERSÃO CORRIGIDA E FINAL]

// A função agora é async para poder esperar a resposta do backend.
  Future<void> handleProductTap(BuildContext context, Product product) async {
    // A verificação de variantes continua perfeita.
    final hasRequiredVariants = product.variantLinks?.any((link) => link.minSelectedOptions > 0) ?? false;

    if (hasRequiredVariants || (product.variantLinks?.isNotEmpty ?? false)) {
      // Se tiver variantes, a ação de navegar para a página do produto está correta.
      goToProductPage(context, product);
    } else {
      // ✅ CORREÇÃO: Se não tiver variantes, usamos o novo fluxo de dados.

      // 1. Montamos o payload para o backend.
      final payload = UpdateCartItemPayload(
        productId: product.id,
        quantity: 1, // Adiciona uma unidade
        variants: [],  // Lista de variantes vazia
      );

      try {
        // 2. Chamamos o método `updateItem` do CartCubit.
        await context.read<CartCubit>().updateItem(payload);

        // 3. Mostramos o feedback de sucesso apenas se a chamada de rede funcionar.
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
        // Opcional: Mostrar um feedback de erro se a chamada falhar.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível adicionar ${product.name}.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  List<Product> getRecommendedProducts({
    required List<Product> allProducts,
    required List<CartItem> itemsInCart,
    Set<String>? bebidaCategories,
    int maxItems = 10,
  }) {
    final productIdsInCart = itemsInCart.map((item) => item.product.id).toSet();

    // Precisamos encontrar as categorias dos produtos que estão no carrinho
    final categoriesInCart = <int>{};
    for (var id in productIdsInCart) {
      final productInCart = allProducts.firstWhere((p) => p.id == id, orElse: () => Product.empty());
      if (productInCart.id != 0) {
        categoriesInCart.add(productInCart.category.id!);
      }
    }

    final beverages = bebidaCategories ?? bebidaCategoryNames;

    final recommended = [
      // 1. Mesmo grupo de categorias
      ...allProducts.where((product) {
        final sameCategory =
            product.category != null &&
            categoriesInCart.contains(product.category!.id);
        final notInCart = !productIdsInCart.contains(product.id);
        final hasImage =
            product.coverImageUrl != null && product.coverImageUrl!.isNotEmpty;
        return sameCategory && notInCart && hasImage;
      }),

      // 2. Bebidas e acompanhamentos (categoria específica)
      ...allProducts.where((product) {
        final categoryName = product.category?.name?.toLowerCase();
        final isBebida =
            categoryName != null &&
            beverages.any(
              (bebida) => categoryName.contains(bebida.toLowerCase()),
            );
        final notInCart = !productIdsInCart.contains(product.id);
        final hasImage =
            product.coverImageUrl != null && product.coverImageUrl!.isNotEmpty;
        return isBebida && notInCart && hasImage;
      }),

      // 3. Outros produtos populares com imagem
      ...allProducts.where((product) {
        final notInCart = !productIdsInCart.contains(product.id);
        final hasImage =
            product.coverImageUrl != null && product.coverImageUrl!.isNotEmpty;
        return notInCart && hasImage;
      }),
    ];

    // Remove duplicados por ID e limita o tamanho
    final uniqueRecommended =
        recommended
            .fold<Map<String, Product>>(
              {},
              (map, product) => map..[product.id.toString()] = product,
            )
            .values
            .take(maxItems)
            .toList();

    return uniqueRecommended;
  }
}
