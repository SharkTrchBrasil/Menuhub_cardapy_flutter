// lib/pages/product/product_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/pages/product/widgets/desktoplayout.dart';
import 'package:totem/pages/product/widgets/mobilelayout.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/models/page_status.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/app_page_status_builder.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import '../../cubit/auth_cubit.dart';
import '../../models/cart_item.dart';
import '../../models/cart_variant.dart';
import '../../models/cart_variant_option.dart';
import '../../models/update_cart_payload.dart';
import '../../widgets/dot_loading.dart';
import '../cart/cart_cubit.dart';
import '../../cubit/store_cubit.dart';
import '../../cubit/store_state.dart';
import '../cart/cart_state.dart' as CartCubitState;

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final TextEditingController observationController = TextEditingController();

  @override
  void dispose() {
    observationController.dispose();
    super.dispose();
  }

  // ... (o resto do seu widget build permanece o mesmo)
  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return BlocListener<StoreCubit, StoreState>(
      listener: (context, storeState) {
        final productPageState = context.read<ProductPageCubit>().state;
        if (productPageState.status is PageStatusSuccess && storeState.products != null) {
          try {
            final updatedSourceProduct = storeState.products!.firstWhere(
                  (p) => p.id == productPageState.product!.product.id,
            );
            context.read<ProductPageCubit>().updateWithNewSourceProduct(updatedSourceProduct);
          } catch (e) {
            if (context.canPop()) context.pop();
          }
        }
      },
      child: Material(
        color: Colors.transparent,
        child: BlocConsumer<ProductPageCubit, ProductPageState>(
          listener: (context, state) {
            if (state.product != null && observationController.text != (state.product!.note ?? '')) {
              observationController.text = state.product!.note ?? '';
            }
          },
          builder: (context, productState) {
            return AppPageStatusBuilder<CartProduct>(
              status: productState.status,
              tryAgain: () => context.read<ProductPageCubit>().retryLoad(),
              successBuilder: (productFromState) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (ResponsiveBuilder.isMobile(context)) {
                      return Stack(
                        children: [
                          MobileProductPage(
                            productState: productState,
                            observationController: observationController,
                            theme: theme,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildMobileActionBar(context, productState, theme),
                          ),
                        ],
                      );
                    }
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(color: Colors.transparent),
                        ),
                        Center(
                          child: DesktopProductCard(
                            productState: productState,
                            observationController: observationController,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileActionBar(BuildContext context, ProductPageState productState, DsTheme theme) {
    final product = productState.product!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.remove, color: theme.productTextColor),
            onPressed: () => context.read<ProductPageCubit>().updateQuantity(product.quantity - 1),
          ),
          Text(product.quantity.toString()),
          IconButton(
            icon: Icon(Icons.add, color: theme.productTextColor),
            onPressed: () => context.read<ProductPageCubit>().updateQuantity(product.quantity + 1),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: BlocBuilder<CartCubit, CartCubitState.CartState>(
              builder: (context, cartState) {
                final buttonText = productState.isEditMode
                    ? 'Salvar ${product.totalPrice.toCurrency}'
                    : 'Adicionar ${product.totalPrice.toCurrency}';

                return DsPrimaryButton(
                  onPressed: cartState.isUpdating || !product.isValid
                      ? null
                      : () => _onConfirm(context, productState),
                  child: cartState.isUpdating ? const DotLoading() : Text(buttonText),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onConfirm(BuildContext context, ProductPageState productState) async {
    final authState = context.read<AuthCubit>().state;
    final cartCubit = context.read<CartCubit>();
    final product = productState.product!;

    // ✅ CORREÇÃO FINAL APLICADA AQUI
    final payload = UpdateCartItemPayload(
      cartItemId: productState.isEditMode ? productState.originalCartItemId : null,
      productId: product.product.id!,
      categoryId: product.category.id!, // Passa o ID da categoria
      quantity: product.quantity,
      note: observationController.text.trim(),
      sizeName: product.selectedSize?.name,
      variants: product.selectedVariants.map((cartVariant) {
        final selectedOptions = cartVariant.cartOptions.where((option) => option.quantity > 0).toList();
        if (selectedOptions.isEmpty) return null;
        return CartItemVariant(
          variantId: cartVariant.id,
          name: cartVariant.name,
          options: selectedOptions.map((option) => CartItemVariantOption(
            variantOptionId: option.id,
            quantity: option.quantity,
            name: option.name,
            price: option.price,
          )).toList(),
        );
      }).whereType<CartItemVariant>().toList(),
    );

    Future<void> updateAndPop() async {
      await cartCubit.updateItem(payload);
      if (context.mounted && context.canPop()) {
        context.pop();
      }
    }

    if (authState.status == AuthStatus.success) {
      await updateAndPop();
    } else {
      if (context.canPop()) {
        context.pop();
      }
      await Future.delayed(const Duration(milliseconds: 100));
      final loginSuccess = await context.push<bool>('/onboarding');
      if (loginSuccess == true && context.mounted) {
        context.go('/product/${product.product.name.toSlug()}/${product.product.id}', extra: product.product);
      }
    }
  }
}