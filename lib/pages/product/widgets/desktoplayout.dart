import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/pages/product/widgets/variant_widget.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import '../../../cubit/auth_cubit.dart';
import '../../../models/cart_item.dart';
import '../../../models/cart_variant.dart';
import '../../../models/cart_variant_option.dart';
import '../../../models/update_cart_payload.dart';
import '../../../widgets/dot_loading.dart';
import '../../cart/cart_state.dart';
import 'dart:math';

class DesktopProductCard extends StatelessWidget {
  final ProductPageState productState;
  final TextEditingController observationController;

  const DesktopProductCard({
    super.key,
    required this.productState,
    required this.observationController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final screenSize = MediaQuery.of(context).size;
    final product = productState.product!;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: min(screenSize.width * 0.90, 800),
        maxHeight: min(screenSize.height * 0.90, 600),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: CachedNetworkImage(
                imageUrl: product.product.coverImageUrl ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
              ),
            ),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              product.product.name.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => context.pop(),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.product.description != null && product.product.description!.isNotEmpty) ...[
                            Text(
                              product.product.description!,
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            product.totalPrice.toCurrency,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 32),
                          if (product.selectedVariants.isNotEmpty) ...[
                            ListView.separated(
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: product.selectedVariants.length,
                              itemBuilder: (_, i) {
                                final variant = product.selectedVariants[i];
                                return VariantWidget(
                                  onOptionUpdated: (v, o, nq) => context.read<ProductPageCubit>().updateOption(v, o, nq),
                                  variant: variant,
                                );
                              },
                              separatorBuilder: (_, __) => const SizedBox(height: 40),
                            ),
                            const SizedBox(height: 32),
                          ],
                          const Text(
                            'Alguma observação no produto?',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: observationController,
                            keyboardType: TextInputType.multiline,
                            maxLines: 4,
                            minLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Ex: tirar a cebola, maionese à parte etc.',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.primaryColor),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  _buildActionBar(context, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, DsTheme theme) {
    final productState = context.watch<ProductPageCubit>().state;
    final product = productState.product!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: theme.primaryColor),
                  onPressed: product.quantity > 1
                      ? () => context.read<ProductPageCubit>().updateQuantity(product.quantity - 1)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(product.quantity.toString()),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: theme.primaryColor),
                  onPressed: () => context.read<ProductPageCubit>().updateQuantity(product.quantity + 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: BlocBuilder<CartCubit, CartState>(
              builder: (context, cartState) {
                final isEditMode = productState.isEditMode;
                final buttonText = isEditMode
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

  // ✅ MÉTODO CORRIGIDO
  void _onConfirm(BuildContext context, ProductPageState productState) async {
    final authState = context.read<AuthCubit>().state;
    final cartCubit = context.read<CartCubit>();
    final product = productState.product!;

    final payload = UpdateCartItemPayload(
      cartItemId: productState.isEditMode ? productState.originalCartItemId : null,
      productId: product.product.id!,
      // ✅ CORREÇÃO APLICADA AQUI
      // Pega o ID da categoria que está dentro do objeto CartProduct
      categoryId: product.category.id!,
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

    // A lógica de login e pop permanece a mesma
    if (authState.status == AuthStatus.success) {
      await cartCubit.updateItem(payload);
      if (context.mounted) context.pop();
    } else {
      if (context.canPop()) context.pop();
      await Future.delayed(const Duration(milliseconds: 100));
      final loginSuccess = await context.push<bool>('/onboarding');
      if (loginSuccess == true && context.mounted) {
        context.go('/product/${product.product.name.toSlug()}/${product.product.id}', extra: product.product);
      }
    }
  }
}