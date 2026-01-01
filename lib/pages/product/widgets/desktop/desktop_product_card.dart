import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:collection/collection.dart';
import 'package:totem/core/di.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/pages/product/widgets/variant_widget.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import '../../../../cubit/auth_cubit.dart';
import '../../../../cubit/store_cubit.dart';
import '../../../../models/cart_item.dart';
import '../../../../models/cart_variant.dart';
import '../../../../models/cart_variant_option.dart';
import '../../../../models/update_cart_payload.dart';
import '../../../../widgets/dot_loading.dart';
import '../../../cart/cart_state.dart';
import '../../../../services/pending_cart_service.dart';
import '../../../../core/helpers/side_panel.dart';
import '../../../../pages/signin/signin_page.dart';
import '../../../../widgets/clear_cart_confirmation.dart';
import 'dart:math';

// ✅ NOVOS IMPORTS
import 'package:totem/core/enums/foodtags.dart';
import 'package:totem/core/enums/beverage.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/services/availability_service.dart';

class DesktopProductCard extends StatefulWidget {
  final ProductPageState productState;
  final TextEditingController observationController;

  const DesktopProductCard({
    super.key,
    required this.productState,
    required this.observationController,
  });

  @override
  State<DesktopProductCard> createState() => _DesktopProductCardState();
}

class _DesktopProductCardState extends State<DesktopProductCard> {
  final Map<int, GlobalKey> _variantKeys = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.productState.product != null) {
      for (final variant in widget.productState.product!.selectedVariants) {
        _variantKeys[variant.id] = GlobalKey();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToNextRequiredVariant() {
    if (!mounted) return;
    final product = widget.productState.product;
    if (product == null) return;
    
    for (int i = 0; i < product.selectedVariants.length; i++) {
      final variant = product.selectedVariants[i];
      if (variant.isRequired && !variant.isValid) {
        final key = _variantKeys[variant.id];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
          return;
        }
      }
    }
  }

  // ✅ Helper para obter preço original e promocional
  int? _getOriginalPrice(CartProduct product) {
    final link = product.product.categoryLinks
        .firstWhereOrNull((l) => l.categoryId == product.category.id);
    if (link != null && link.isOnPromotion && link.promotionalPrice != null) {
      // ✅ Preço original (sem desconto) + variantes
      return link.price + product.variantsPrice;
    }
    return null;
  }

  int? _getPromotionalPrice(CartProduct product) {
    final link = product.product.categoryLinks
        .firstWhereOrNull((l) => l.categoryId == product.category.id);
    if (link != null && link.isOnPromotion && link.promotionalPrice != null) {
      // ✅ Preço promocional + variantes (se houver)
      return link.promotionalPrice! + product.variantsPrice;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final screenSize = MediaQuery.of(context).size;
    final product = widget.productState.product!;
    final originalPrice = _getOriginalPrice(product);
    final promotionalPrice = _getPromotionalPrice(product);

    // ✅ Verifica disponibilidade
    final isAvailable = AvailabilityService.isProductAvailableNow(product.product);

    // ✅ Layout: 50/50 e mais largo
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: min(screenSize.width * 0.90, 1200),
        maxHeight: min(screenSize.height * 0.90, 900),
        minWidth: 700,
        minHeight: 600,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Imagem à esquerda - 50% da largura
            Expanded(
              flex: 5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 350),
                child: CachedNetworkImage(
                  imageUrl: product.product.imageUrl ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),
            // ✅ Conteúdo à direita - 50% da largura
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Header com botões de ação (compartilhar e fechar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          onPressed: () => _shareProduct(context, product),
                          tooltip: 'Compartilhar',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => context.pop(),
                          tooltip: 'Fechar',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // ✅ Conteúdo scrollável (padding consistente)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ TÍTULO CENTRALIZADO
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            child: Center(
                              child: Text(
                                product.product.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          // ✅ REGRAS DE PIZZA OU DESCRIÇÃO
                          if (product.category.isCustomizable) ...[
                            // Mostra regras de cobrança para pizzas
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Importante:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'A pizza de mais de 1 sabor será cobrada pelo preço cheio do sabor mais caro.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (product.product.description != null && product.product.description!.isNotEmpty) ...[
                            // Mostra descrição normal para outros produtos
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Text(
                                product.product.description!,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade700,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],

                          // ✅ AVISO DE INDISPONIBILIDADE
                          if (!isAvailable)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Produto indisponível no momento',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (product.product.availabilityType == AvailabilityType.scheduled)
                                            const Text(
                                              'Verifique os horários de funcionamento.',
                                              style: TextStyle(color: Colors.red, fontSize: 12),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // ✅ TAGS ALIMENTARES E DE BEBIDAS
                          if (product.product.dietaryTags.isNotEmpty || product.product.beverageTags.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...product.product.dietaryTags.map((tag) => Chip(
                                    label: Text(foodTagNames[tag] ?? '', style: const TextStyle(fontSize: 12)),
                                    backgroundColor: Colors.green.shade50,
                                    labelStyle: TextStyle(color: Colors.green.shade800),
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  )),
                                  ...product.product.beverageTags.map((tag) => Chip(
                                    label: Text(beverageTagNames[tag] ?? '', style: const TextStyle(fontSize: 12)),
                                    backgroundColor: Colors.blue.shade50,
                                    labelStyle: TextStyle(color: Colors.blue.shade800),
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  )),
                                ],
                              ),
                            ),
                          ],

                          // ✅ PREÇO COM DESCONTO
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (promotionalPrice != null && originalPrice != null) ...[
                                  // Preço promocional (verde) - já inclui variantes
                                  Text(
                                    (promotionalPrice / 100.0).toCurrency(),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Preço original (riscado) - já inclui variantes
                                  Text(
                                    (originalPrice / 100.0).toCurrency(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.grey.shade500,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ] else ...[
                                  // ✅ Para pizzas: mostra "A partir de" antes de selecionar sabores
                                  if (product.category.isCustomizable && product.totalPrice == 0) ...[
                                    Text(
                                      'A partir de ${product.startingPrice.toCurrency}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ] else ...[
                                    // Preço normal ou preço final da pizza
                                    Text(
                                      product.totalPrice.toCurrency,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          // ✅ "Serve X pessoas" se houver (futuro - quando o campo existir no modelo)
                          // if (product.product.servesPeople != null) ...[
                          //   Padding(
                          //     padding: const EdgeInsets.only(bottom: 20),
                          //     child: Row(
                          //       children: [
                          //         Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                          //         const SizedBox(width: 4),
                          //         Text(
                          //           'Serve ${product.product.servesPeople} pessoa${product.product.servesPeople! > 1 ? 's' : ''}',
                          //           style: TextStyle(
                          //             fontSize: 14,
                          //             color: Colors.grey.shade600,
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                          // ],
                          if (product.product.unit.requiresQuantityInput) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Text(
                                'Preço por ${product.product.unit.displayName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // ✅ Variantes (opções de customização)
                          if (product.selectedVariants.isNotEmpty) ...[
                            ListView.separated(
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: product.selectedVariants.length,
                              itemBuilder: (_, i) {
                                final variant = product.selectedVariants[i];
                                return VariantWidget(
                                  key: _variantKeys[variant.id],
                                  onOptionUpdated: (v, o, nq) {
                                    context.read<ProductPageCubit>().updateOption(
                                      v, 
                                      o, 
                                      nq,
                                      onUpdateComplete: _scrollToNextRequiredVariant,
                                    );
                                  },
                                  variant: variant,
                                  onScrollToNextRequired: _scrollToNextRequiredVariant,
                                );
                              },
                              separatorBuilder: (_, __) => const SizedBox(height: 32),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // ✅ Campo de observação
                          const Text(
                            'Alguma observação no produto?',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: widget.observationController,
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
                  _buildActionBar(context, theme, isAvailable),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, DsTheme theme, bool isAvailable) {
    final productState = context.watch<ProductPageCubit>().state;
    final product = productState.product!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          product.product.unit.requiresQuantityInput
              ? _buildWeightQuantityInput(context, theme, product)
              : _buildIntegerQuantityInput(context, theme, product),
          const SizedBox(width: 16),
          Expanded(
            child: BlocBuilder<CartCubit, CartState>(
              builder: (context, cartState) {
                final isEditMode = productState.isEditMode;
                final buttonText = isEditMode
                    ? 'Salvar ${product.totalPrice.toCurrency}'
                    : 'Adicionar ${product.totalPrice.toCurrency}';

                return DsPrimaryButton(
                  onPressed: cartState.isUpdating || !product.isValid || !isAvailable
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

    final payload = UpdateCartItemPayload(
      cartItemId: productState.isEditMode ? productState.originalCartItemId : null,
      productId: product.product.id!,
      categoryId: product.category.id!,
      quantity: product.quantity,
      note: widget.observationController.text.trim(),
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
      // ✅ SEGURANÇA: Verifica se o carrinho tem itens de outra loja
      final productStoreId = product.product.storeId;
      final canProceed = await canAddToCart(
        context: context,
        productStoreId: productStoreId,
      );
      
      if (!canProceed) {
        return; // Usuário cancelou, não adiciona
      }
      
      await cartCubit.updateItem(payload);
      if (context.mounted) {
        if (context.canPop()) {
          context.pop();
        }
        
        // ✅ LÓGICA DE REDIRECT INTELIGENTE
        // Verifica se veio do carrinho (via query params)
        final uri = GoRouterState.of(context).uri;
        final fromCart = uri.queryParameters['fromCart'] == 'true';

        if (fromCart || productState.isEditMode) {
          context.go('/cart');
        } else {
          context.go('/');
        }
      }
    }

    final isLoggedIn = authState.customer != null;
    
    if (isLoggedIn) {
      await updateAndPop();
    } else {
      await PendingCartService.savePendingCartItem(payload);
      
      try {
        final loginSuccess = await showResponsiveSidePanel<bool>(
          context,
          const OnboardingPage(),
          useFullScreenOnDesktop: true,
        );
        
        if (loginSuccess == true && context.mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (context.canPop()) {
            context.pop();
          }
          context.go('/');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao abrir tela de login. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Widget _buildIntegerQuantityInput(BuildContext context, DsTheme theme, CartProduct product) {
    return Container(
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
    );
  }
  
  Widget _buildWeightQuantityInput(BuildContext context, DsTheme theme, CartProduct product) {
    final cubit = context.read<ProductPageCubit>();
    final currentWeight = product.weightQuantity ?? 0.5;
    final unitName = product.product.unit.displayName;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.remove, color: theme.primaryColor),
            onPressed: currentWeight > 0.1
                ? () => cubit.updateWeightQuantity((currentWeight - 0.1).clamp(0.1, 100.0))
                : null,
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: TextEditingController(text: currentWeight.toStringAsFixed(2)),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                border: InputBorder.none,
                suffixText: unitName,
                suffixStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              onSubmitted: (value) {
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                if (parsed != null && parsed > 0) {
                  cubit.updateWeightQuantity(parsed.clamp(0.01, 100.0));
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, color: theme.primaryColor),
            onPressed: () => cubit.updateWeightQuantity((currentWeight + 0.1).clamp(0.1, 100.0)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareProduct(BuildContext context, CartProduct product) async {
    try {
      final store = context.read<StoreCubit>().state.store;
      if (store == null || product.product.id == null) return;

      final dio = getIt<Dio>();
      final response = await dio.post(
        '/products/${store.urlSlug}/${product.product.id}/share',
        data: {
          'share_type': 'app',
          'share_source': 'desktop',
          'utm_source': 'totem_app',
          'utm_medium': 'share',
        },
      );

      final shareUrl = response.data['share_url'] as String;
      final shareMessage = 'Confira este produto: ${product.product.name}\n$shareUrl';

      final shareResult = await Share.share(
        shareMessage,
        subject: product.product.name,
      );

      if (shareResult.status == ShareResultStatus.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produto compartilhado com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      try {
        final store = context.read<StoreCubit>().state.store;
        if (store == null || product.product.id == null) return;

        final baseUrl = 'https://${store.urlSlug}.menuhub.com.br';
        // ✅ CORREÇÃO: Formato correto da URL é /product/{slug}/{id}
        final productSlug = product.product.name.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-9-]'), '');
        final productUrl = '$baseUrl/product/$productSlug/${product.product.id}';
        final shareMessage = 'Confira este produto: ${product.product.name}\n$productUrl';

        await Share.share(
          shareMessage,
          subject: product.product.name,
        );
      } catch (e2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao compartilhar produto: ${e2.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}
