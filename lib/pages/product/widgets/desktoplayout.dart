import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart'; // ✅ NOVO: Para chamar API de compartilhamento
import 'package:share_plus/share_plus.dart'; // ✅ NOVO: Compartilhamento
import 'package:totem/core/di.dart'; // ✅ NOVO: Para obter Dio
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
import '../../../cubit/store_cubit.dart'; // ✅ NOVO: Para obter store
import '../../../models/cart_item.dart';
import '../../../models/cart_variant.dart';
import '../../../models/cart_variant_option.dart';
import '../../../models/option_group.dart';
import '../../../models/update_cart_payload.dart';
import '../../../widgets/dot_loading.dart';
import '../../cart/cart_state.dart';
import '../../../services/pending_cart_service.dart';
import '../../../core/helpers/side_panel.dart';
import '../../../pages/signin/signin_page.dart';
import 'dart:math';

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
    // Inicializa keys para variantes
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

  // ✅ Método para rolar até próximo grupo obrigatório não selecionado (desktop)
  void _scrollToNextRequiredVariant() {
    if (!mounted) return;
    final product = widget.productState.product;
    if (product == null) return;

    // Procura próximo grupo obrigatório não completado
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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final screenSize = MediaQuery.of(context).size;
    final product = widget.productState.product!;

    // ✅ Layout: mais largo e alto (aproximadamente 90% da largura e 85% da altura)
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: min(
          screenSize.width * 0.90,
          1200,
        ), // ✅ Aumentado de 800 para 1200px
        maxHeight: min(
          screenSize.height * 0.85,
          800,
        ), // ✅ Aumentado de 600 para 800px
        minWidth: 600, // ✅ Largura mínima para garantir legibilidade
        minHeight: 500, // ✅ Altura mínima
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        elevation: 4, // ✅ Sombra sutil
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Imagem à esquerda - 40% da largura
            Expanded(
              flex: 4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 300),
                child: CachedNetworkImage(
                  imageUrl: product.product.imageUrl ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder:
                      (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                ),
              ),
            ),
            // ✅ Conteúdo à direita - 60% da largura
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Header com título e botões
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 24, 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.product.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20, // ✅ Aumentado de 14 para 20
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ✅ NOVO: Botão de compartilhamento
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
                  // ✅ Conteúdo scrollável
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ Descrição do produto
                          if (product.product.description != null &&
                              product.product.description!.isNotEmpty) ...[
                            Text(
                              product.product.description!,
                              style: TextStyle(
                                fontSize:
                                    15, // ✅ Ajustado para melhor legibilidade
                                color: Colors.grey.shade700,
                                height: 1.6, // ✅ Aumentado line height
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // ✅ Preço (maior e mais destacado)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ Para pizzas: mostra "A partir de" antes de selecionar sabores
                              if (product.category.isCustomizable &&
                                  product.totalPrice == 0) ...[
                                Text(
                                  'A partir de ${product.startingPrice.toCurrency}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  product.totalPrice.toCurrency,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              if (product
                                  .product
                                  .unit
                                  .requiresQuantityInput) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Preço por ${product.product.unit.displayName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
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
                                  key: _variantKeys[variant.id],
                                  onOptionUpdated: (v, o, nq) {
                                    context
                                        .read<ProductPageCubit>()
                                        .updateOption(
                                          v,
                                          o,
                                          nq,
                                          onUpdateComplete:
                                              _scrollToNextRequiredVariant,
                                        );
                                  },
                                  variant: variant,
                                  onScrollToNextRequired:
                                      _scrollToNextRequiredVariant,
                                );
                              },
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 40),
                            ),
                            const SizedBox(height: 32),
                          ],
                          const Text(
                            'Alguma observação no produto?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: widget.observationController,
                            keyboardType: TextInputType.multiline,
                            maxLines: 4,
                            minLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'Ex: tirar a cebola, maionese à parte etc.',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.primaryColor,
                                ),
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
          // ✅ NOVO: Widget de quantidade adaptativo (inteira ou decimal)
          product.product.unit.requiresQuantityInput
              ? _buildWeightQuantityInput(context, theme, product)
              : _buildIntegerQuantityInput(context, theme, product),
          const SizedBox(width: 16),
          Expanded(
            child: BlocBuilder<CartCubit, CartState>(
              builder: (context, cartState) {
                final isEditMode = productState.isEditMode;
                final buttonText =
                    isEditMode
                        ? 'Salvar ${product.totalPrice.toCurrency}'
                        : 'Adicionar ${product.totalPrice.toCurrency}';

                return DsPrimaryButton(
                  onPressed:
                      cartState.isUpdating || !product.isValid
                          ? null
                          : () => _onConfirm(context, productState),
                  child:
                      cartState.isUpdating
                          ? const DotLoading()
                          : Text(buttonText),
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
    final isCustomizable = product.category.isCustomizable;
    final productIdToSend =
        isCustomizable
            ? (product.selectedSize?.linkedProductId ?? product.product.id!)
            : product.product.id!;

    final payload = UpdateCartItemPayload(
      cartItemId:
          productState.isEditMode ? productState.originalCartItemId : null,
      productId: productIdToSend,
      // ✅ CORREÇÃO APLICADA AQUI
      // Pega o ID da categoria que está dentro do objeto CartProduct
      categoryId: product.category.id!,
      quantity: product.quantity,
      note: widget.observationController.text.trim(),
      sizeName: product.selectedSize?.name,
      sizeImageUrl: product.selectedSize?.image?.url,
      variants:
          product.selectedVariants.expand<CartItemVariant>((cartVariant) {
            final selectedOptions =
                cartVariant.cartOptions
                    .where((option) => option.quantity > 0)
                    .toList();
            if (selectedOptions.isEmpty) return [];

            final crustOptions = <CartItemVariantOption>[];
            final edgeOptions = <CartItemVariantOption>[];
            final otherOptions = <CartItemVariantOption>[];

            for (final option in selectedOptions) {
              if (isCustomizable &&
                  option.crustId != null &&
                  option.edgeId != null) {
                crustOptions.add(
                  CartItemVariantOption(
                    variantOptionId: null,
                    optionItemId: option.crustId,
                    quantity: option.quantity,
                    name:
                        (option.crustName?.toLowerCase().startsWith('massa') ??
                                false)
                            ? (option.crustName ?? 'Massa')
                            : 'Massa ${option.crustName ?? ''}',
                    price: option.crustPrice ?? 0,
                  ),
                );

                edgeOptions.add(
                  CartItemVariantOption(
                    variantOptionId: null,
                    optionItemId: option.edgeId,
                    quantity: option.quantity,
                    name:
                        (option.edgeName?.toLowerCase().startsWith('borda') ??
                                false)
                            ? (option.edgeName ?? 'Borda')
                            : 'Borda ${option.edgeName ?? ''}',
                    price: option.edgePrice ?? 0,
                  ),
                );
                continue;
              }

              if (isCustomizable &&
                  option.parentCustomizationOptionId != null) {
                final parts = option.name.split(' + ');
                final mainName = parts.first;
                final edgeName = parts.length > 1 ? parts.last : 'Borda';

                crustOptions.add(
                  CartItemVariantOption(
                    variantOptionId: null,
                    optionItemId: option.id,
                    quantity: option.quantity,
                    name: mainName,
                    price: option.price,
                  ),
                );

                edgeOptions.add(
                  CartItemVariantOption(
                    variantOptionId: null,
                    optionItemId: option.parentCustomizationOptionId,
                    quantity: option.quantity,
                    name: edgeName,
                    price: 0,
                  ),
                );
                continue;
              }

              final type = cartVariant.groupType;
              if (type == 'CRUST') {
                crustOptions.add(
                  CartItemVariantOption(
                    variantOptionId: isCustomizable ? null : option.id,
                    optionItemId: isCustomizable ? option.id : null,
                    quantity: option.quantity,
                    name: option.name,
                    price: option.price,
                  ),
                );
              } else if (type == 'EDGE') {
                edgeOptions.add(
                  CartItemVariantOption(
                    variantOptionId: isCustomizable ? null : option.id,
                    optionItemId: isCustomizable ? option.id : null,
                    quantity: option.quantity,
                    name: option.name,
                    price: option.price,
                  ),
                );
              } else {
                otherOptions.add(
                  CartItemVariantOption(
                    variantOptionId: isCustomizable ? null : option.id,
                    optionItemId: isCustomizable ? option.id : null,
                    quantity: option.quantity,
                    name: option.name,
                    price: option.price,
                  ),
                );
              }
            }

            final result = <CartItemVariant>[];

            if (crustOptions.isNotEmpty) {
              final crustGroup = product.category.optionGroups.firstWhereOrNull(
                (g) => g.groupType == OptionGroupType.crust,
              );
              result.add(
                CartItemVariant(
                  variantId: isCustomizable ? null : cartVariant.id,
                  optionGroupId:
                      isCustomizable
                          ? (crustGroup?.id ?? cartVariant.id)
                          : null,
                  groupType: 'CRUST',
                  name: crustGroup?.name ?? 'Massa',
                  options: crustOptions,
                ),
              );
            }

            if (edgeOptions.isNotEmpty) {
              final edgeGroup = product.category.optionGroups.firstWhereOrNull(
                (g) => g.groupType == OptionGroupType.edge,
              );
              result.add(
                CartItemVariant(
                  variantId: null,
                  optionGroupId: edgeGroup?.id ?? cartVariant.id,
                  groupType: 'EDGE',
                  name: edgeGroup?.name ?? 'Borda',
                  options: edgeOptions,
                ),
              );
            }

            if (otherOptions.isNotEmpty) {
              result.add(
                CartItemVariant(
                  variantId: isCustomizable ? null : cartVariant.id,
                  optionGroupId: isCustomizable ? cartVariant.id : null,
                  groupType: cartVariant.groupType,
                  name: cartVariant.name,
                  options: otherOptions,
                ),
              );
            }

            return result;
          }).toList(),
    );

    Future<void> updateAndPop() async {
      await cartCubit.updateItem(payload);
      if (context.mounted) {
        // ✅ Fecha a tela de detalhes do produto e navega para o destino correto
        if (context.canPop()) {
          context.pop(); // Fecha tela de detalhes
        }
        final uri = GoRouterState.of(context).uri;
        final fromCart = uri.queryParameters['fromCart'] == 'true';
        context.go((fromCart || productState.isEditMode) ? '/cart' : '/');
      }
    }

    // ✅ CORREÇÃO: Verifica se o usuário está logado (customer != null)
    // Isso é mais confiável que verificar apenas o status
    final isLoggedIn = authState.customer != null;

    if (isLoggedIn) {
      // ✅ Usuário está logado, adiciona ao carrinho diretamente
      await updateAndPop();
    } else {
      // ✅ Usuário NÃO está logado - abre sidepanel com login
      print(
        '🔐 [DesktopProductCard] Usuário não logado. Abrindo sidepanel de login...',
      );

      // ✅ Salva payload pendente antes de pedir login
      await PendingCartService.savePendingCartItem(payload);

      // ✅ Usa showResponsiveSidePanel ao invés de navegar
      // No mobile e desktop, abre um modal full screen com o login
      try {
        final loginSuccess = await showResponsiveSidePanel<bool>(
          context,
          const OnboardingPage(),
          useFullScreenOnDesktop: true, // ✅ Força full screen no desktop também
        );

        print('🔐 [DesktopProductCard] Resultado do login: $loginSuccess');

        // ✅ Após login bem-sucedido, o AuthCubit vai processar o item pendente
        // e depois vamos fechar a tela e navegar para home
        if (loginSuccess == true && context.mounted) {
          print(
            '✅ [DesktopProductCard] Login bem-sucedido. Aguardando processamento do item...',
          );
          // Aguarda um pouco para garantir que o item foi adicionado
          await Future.delayed(const Duration(milliseconds: 500));
          // Fecha a tela de detalhes do produto
          if (context.canPop()) {
            context.pop(); // Fecha tela de detalhes
          }
          final uri = GoRouterState.of(context).uri;
          final fromCart = uri.queryParameters['fromCart'] == 'true';
          context.go((fromCart || productState.isEditMode) ? '/cart' : '/');
        }
      } catch (e) {
        print('❌ [DesktopProductCard] Erro ao abrir sidepanel de login: $e');
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

  // ✅ NOVO: Widget de quantidade inteira (para produtos normais)
  Widget _buildIntegerQuantityInput(
    BuildContext context,
    DsTheme theme,
    CartProduct product,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.remove, color: theme.primaryColor),
            onPressed:
                product.quantity > 1
                    ? () => context.read<ProductPageCubit>().updateQuantity(
                      product.quantity - 1,
                    )
                    : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(product.quantity.toString()),
          ),
          IconButton(
            icon: Icon(Icons.add, color: theme.primaryColor),
            onPressed:
                () => context.read<ProductPageCubit>().updateQuantity(
                  product.quantity + 1,
                ),
          ),
        ],
      ),
    );
  }

  // ✅ NOVO: Widget de quantidade decimal (para kg/litros)
  Widget _buildWeightQuantityInput(
    BuildContext context,
    DsTheme theme,
    CartProduct product,
  ) {
    final cubit = context.read<ProductPageCubit>();
    final currentWeight =
        product.weightQuantity ?? 0.5; // Valor padrão: 0.5 kg/L
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
            onPressed:
                currentWeight > 0.1
                    ? () => cubit.updateWeightQuantity(
                      (currentWeight - 0.1).clamp(0.1, 100.0),
                    )
                    : null,
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: TextEditingController(
                text: currentWeight.toStringAsFixed(2),
              ),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                border: InputBorder.none,
                suffixText: unitName,
                suffixStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
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
            onPressed:
                () => cubit.updateWeightQuantity(
                  (currentWeight + 0.1).clamp(0.1, 100.0),
                ),
          ),
        ],
      ),
    );
  }

  // ✅ NOVO: Método para compartilhar produto
  Future<void> _shareProduct(BuildContext context, CartProduct product) async {
    try {
      final store = context.read<StoreCubit>().state.store;
      if (store == null || product.product.id == null) return;

      // ✅ NOVO: Chama API para gerar link de compartilhamento seguro com token
      final dio = getIt<Dio>();
      final response = await dio.post(
        '/products/${store.urlSlug}/${product.product.id}/share',
        data: {
          'share_type': 'app', // Tipo de compartilhamento (app, web, etc.)
          'share_source':
              'desktop', // Origem do compartilhamento (mobile, desktop, etc.)
          'utm_source': 'totem_app', // UTM source para rastreamento
          'utm_medium': 'share', // UTM medium para rastreamento
        },
      );

      final shareUrl = response.data['share_url'] as String;
      final shareMessage =
          'Confira este produto: ${product.product.name}\n$shareUrl';

      // Usa o Share do Flutter
      final shareResult = await Share.share(
        shareMessage,
        subject: product.product.name,
      );

      // ✅ NOVO: Feedback visual
      if (shareResult.status == ShareResultStatus.success) {
        print('✅ Produto compartilhado: ${product.product.id}');
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
      // ✅ CORREÇÃO: Se falhar na API, ainda tenta compartilhar URL básica
      print('⚠️ Erro ao gerar link de compartilhamento: $e');
      try {
        final store = context.read<StoreCubit>().state.store;
        if (store == null || product.product.id == null) return;

        // Fallback: usa URL básica sem token
        final baseUrl = 'https://${store.urlSlug}.menuhub.com.br';
        // ✅ CORREÇÃO: Formato correto da URL é /product/{slug}/{id}
        final productSlug = product.product.name
            .toLowerCase()
            .replaceAll(' ', '-')
            .replaceAll(RegExp(r'[^a-z0-9-]'), '');
        final productUrl =
            '$baseUrl/product/$productSlug/${product.product.id}';
        final shareMessage =
            'Confira este produto: ${product.product.name}\n$productUrl';

        await Share.share(shareMessage, subject: product.product.name);
      } catch (e2) {
        // ✅ CORREÇÃO: Não bloqueia se houver erro ao compartilhar
        print('⚠️ Erro ao compartilhar produto: $e2');
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
