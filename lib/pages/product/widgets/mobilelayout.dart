// mobilelayout.dart (Corrigido)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart'; // ✅ NOVO: Para chamar API de compartilhamento
import 'package:share_plus/share_plus.dart'; // ✅ NOVO: Compartilhamento
import 'package:totem/core/di.dart'; // ✅ NOVO: Para obter Dio
import 'package:totem/core/extensions.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/models/cart_variant.dart';
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/widgets/variant_header_widget.dart';
import 'package:totem/pages/product/widgets/variant_widget.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/cubit/store_cubit.dart'; // ✅ NOVO: Para obter store

// ✅ NOVOS IMPORTS
import 'package:totem/core/enums/foodtags.dart';
import 'package:totem/core/enums/beverage.dart';
import 'package:totem/core/enums/available_type.dart';
// Para TimeShift e ScheduleRule
import 'package:totem/models/store.dart';
import 'package:totem/services/availability_service.dart';

import '../product_page_state.dart';

class MobileProductPage extends StatefulWidget {
  final DsTheme theme;
  final TextEditingController observationController;
  final ProductPageState productState; //

  const MobileProductPage({
    super.key,
    required this.theme,
    required this.productState, //
    required this.observationController,
  });

  @override
  State<MobileProductPage> createState() => _MobileProductPageState();
}

class _MobileProductPageState extends State<MobileProductPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _variantKeys = {};
  final Map<int, double> _variantOffsets = {};
  CartVariant? _currentStickyVariant;
  bool _showTitleInAppBar = false;

  @override
  void initState() {
    super.initState();

    // ✅ CORREÇÃO: Acessa o produto através do 'productState'
    // O '!' é seguro pois este widget só é construído quando o estado é de sucesso.
    if (widget.productState.product != null) {
      for (final variant in widget.productState.product!.selectedVariants) {
        //
        _variantKeys[variant.id] = GlobalKey(); //
      }
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOffsets());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _calculateOffsets() {
    if (!mounted) return;
    _variantOffsets.clear();
    final scrollRenderBox = context.findRenderObject() as RenderBox?;
    if (scrollRenderBox == null) return;
    final scrollOrigin = scrollRenderBox.localToGlobal(Offset.zero);

    for (final entry in _variantKeys.entries) {
      final key = entry.value;
      if (key.currentContext != null) {
        final renderBox = key.currentContext!.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final offset = position.dy - scrollOrigin.dy + _scrollController.offset;
        _variantOffsets[entry.key] = offset;
      }
    }
  }

  void _onScroll() {
    final media = MediaQuery.of(context).size;
    final currentOffset = _scrollController.offset;
    final shouldShowAppBar = currentOffset > media.width * 0.8 - kToolbarHeight;
    if (shouldShowAppBar != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = shouldShowAppBar);
    }

    // ✅ CORREÇÃO: Acessa o produto através do 'productState'
    final product = widget.productState.product; //

    if (product == null) return;

    final selectionPoint =
        currentOffset + kToolbarHeight + (MediaQuery.of(context).padding.top);
    CartVariant? newStickyVariant;

    for (final variant in product.selectedVariants) {
      //
      final offset = _variantOffsets[variant.id]; //
      if (offset != null && selectionPoint >= offset) {
        newStickyVariant = variant;
      }
    }

    if (newStickyVariant?.id != _currentStickyVariant?.id) {
      //
      setState(() => _currentStickyVariant = newStickyVariant);
    }
  }

  // ✅ Método para rolar até próximo grupo obrigatório não selecionado
  // ✅ CORREÇÃO: Agora funciona corretamente para pizzas com 3+ sabores
  void _scrollToNextRequiredVariant() {
    if (!mounted) return;
    final product = widget.productState.product;
    if (product == null) return;

    // ✅ CORREÇÃO: Itera por TODOS os grupos, não apenas a partir do atual
    // Isso garante que pizzas com 3 sabores rolem por todos os grupos
    for (int i = 0; i < product.selectedVariants.length; i++) {
      final variant = product.selectedVariants[i];

      // ✅ Verifica se é obrigatório E ainda não foi completado
      if (variant.isRequired && !variant.isValid) {
        // Verifica se a key existe e tem contexto válido
        final key = _variantKeys[variant.id];
        if (key != null && key.currentContext != null) {
          // ✅ Usa Future.delayed para garantir que o scroll aconteça após o rebuild
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted) return;
            if (key.currentContext == null) return;

            Scrollable.ensureVisible(
              key.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment:
                  0.15, // ✅ Rola até mostrar 15% do topo (melhor visibilidade)
            );
          });
          return; // Para no primeiro grupo não completado
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final imageHeight = media.width * 0.7; // Proporção igual ao Menuhub
    final contentOverlapPosition = imageHeight - 24; // Overlap suave

    final product = widget.productState.product!;
    final store = context.watch<StoreCubit>().state.store;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar:
          _showTitleInAppBar
              ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0.5,
                shadowColor: Colors.grey.shade300,
                title: Text(
                  product.product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                centerTitle: true,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: widget.theme.primaryColor,
                  ),
                  onPressed: () {
                    final uri = GoRouterState.of(context).uri;
                    final fromCart = uri.queryParameters['fromCart'] == 'true';
                    context.go(
                      (fromCart || widget.productState.isEditMode)
                          ? '/cart'
                          : '/',
                    );
                  },
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.share, color: widget.theme.primaryColor),
                    onPressed: () => _shareProduct(context, product),
                  ),
                ],
              )
              : null,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ MENUHUB STYLE: Imagem clicável (abre fullscreen)
                GestureDetector(
                  onTap: () => _openImageFullscreen(context, product),
                  child: SizedBox(
                    height: imageHeight,
                    width: media.width,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Imagem do produto
                        Hero(
                          tag: 'product_image_${product.product.id}',
                          child: CachedNetworkImage(
                            imageUrl: product.product.imageUrl ?? '',
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) =>
                                    Container(color: Colors.grey.shade200),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                  ),
                                ),
                          ),
                        ),
                        // ✅ MENUHUB STYLE: Card flutuante com info da loja
                        // ✅ Card flutuante com info da loja (clicável para voltar)
                        if (store != null)
                          Positioned(
                            bottom: 32,
                            left: 16,
                            child: GestureDetector(
                              onTap: () {
                                final uri = GoRouterState.of(context).uri;
                                final fromCart =
                                    uri.queryParameters['fromCart'] == 'true';
                                context.go(
                                  (fromCart || widget.productState.isEditMode)
                                      ? '/cart'
                                      : '/',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Logo da loja
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: store.image?.url ?? '',
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => Container(
                                              width: 28,
                                              height: 28,
                                              color: Colors.grey.shade200,
                                            ),
                                        errorWidget:
                                            (context, url, error) => Container(
                                              width: 28,
                                              height: 28,
                                              color: widget.theme.primaryColor
                                                  .withOpacity(0.1),
                                              child: Icon(
                                                Icons.store,
                                                size: 16,
                                                color:
                                                    widget.theme.primaryColor,
                                              ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Nome da loja + tempo + frete
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              store.name,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.verified,
                                              size: 14,
                                              color: Colors.blue.shade600,
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              store.getDeliveryTimeRange(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              ' • ',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            Text(
                                              _getDeliveryFeeText(store),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    _isFreeDelivery(store)
                                                        ? Colors.green.shade600
                                                        : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // ✅ Conteúdo principal (sem overlap/bordas arredondadas como no Menuhub)
                Container(
                  width: media.width,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 150),
                  child: _buildContentColumn(product),
                ),
              ],
            ),
          ),
          // ✅ MENUHUB STYLE: Botão voltar rosa/vermelho
          if (!_showTitleInAppBar)
            Positioned(
              top: topPadding + 12,
              left: 12,
              child: Material(
                color: widget.theme.primaryColor,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: Colors.black38,
                child: InkWell(
                  onTap: () {
                    final uri = GoRouterState.of(context).uri;
                    final fromCart = uri.queryParameters['fromCart'] == 'true';
                    context.go(
                      (fromCart || widget.productState.isEditMode)
                          ? '/cart'
                          : '/',
                    );
                  },
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          // ✅ Botão de compartilhamento (canto superior direito) - removido para ficar igual Menuhub
          if (_showTitleInAppBar && _currentStickyVariant != null)
            Positioned(
              top: kToolbarHeight + topPadding,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white,
                child: VariantHeaderWidget(
                  key: ValueKey(_currentStickyVariant!.id),
                  variant: _currentStickyVariant!,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ NOVO: Abre imagem em fullscreen (igual Menuhub imagem 2)
  void _openImageFullscreen(BuildContext context, CartProduct product) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenImageViewer(
            imageUrl: product.product.imageUrl ?? '',
            productName: product.product.name,
            productDescription: product.product.description,
            heroTag: 'product_image_${product.product.id}',
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
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
              'mobile', // Origem do compartilhamento (mobile, desktop, etc.)
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

  Widget _buildContentColumn(CartProduct product) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOffsets());

    // ✅ Verifica disponibilidade
    final isAvailable = AvailabilityService.isProductAvailableNow(
      product.product,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ MENUHUB STYLE: Título grande (22px, bold)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            product.product.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
        ),

        // ✅ MENUHUB STYLE: Descrição (14px, cinza, line-height 1.4)
        if (product.product.description != null &&
            product.product.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              product.product.description!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],

        // ✅ AVISO DE INDISPONIBILIDADE
        if (!isAvailable)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
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
                        if (product.product.availabilityType ==
                            AvailabilityType.scheduled)
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

        // ✅ MENUHUB STYLE: Preço BASE FIXO (não muda ao selecionar sabores)
        // Para pizzas: mostra o preço do tamanho selecionado (startingPrice)
        // O preço total com opções extras aparece apenas no botão "Adicionar"
        const SizedBox(height: 12),
        // ✅ MENUHUB STYLE: Preço com Promoção
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Builder(
            builder: (context) {
              // Encontra o link da categoria correta para verificar promoção
              final link = product.product.categoryLinks.firstWhereOrNull(
                (l) => l.categoryId == product.category.id,
              );

              final bool hasPromo = link?.hasPromotion ?? false;
              final int originalPriceInt = link?.price ?? 0;

              // Preço principal a ser exibido
              final int displayPriceInt =
                  (product.category.isCustomizable || product.basePrice == 0)
                      ? product.startingPrice
                      : product.basePrice;

              final bool showAsStartingFrom =
                  product.category.isCustomizable ||
                  (product.basePrice == 0 && displayPriceInt > 0);

              // Se tiver promoção e NÃO for customizável (pizzas têm lógica própria de "A partir de")
              // Ou se for customizável mas queremos mostrar promoção no "A partir de"
              if (hasPromo) {
                final double originalPrice = originalPriceInt / 100.0;
                final double displayPrice = displayPriceInt / 100.0;

                // Calcula % desconto
                int discountPercent = 0;
                if (originalPrice > 0) {
                  discountPercent =
                      (((originalPrice - displayPrice) / originalPrice) * 100)
                          .round();
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Preço Atual (Promocional)
                    Text(
                      showAsStartingFrom
                          ? 'a partir de ${displayPriceInt.toCurrency}'
                          : displayPriceInt.toCurrency,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Preço Original Riscado
                    Text(
                      originalPriceInt.toCurrency,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Badge de Desconto
                    if (discountPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '-$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                );
              }

              // Preço Normal
              return Text(
                showAsStartingFrom
                    ? 'a partir de ${displayPriceInt.toCurrency}'
                    : displayPriceInt.toCurrency,
                style: const TextStyle(
                  fontSize: 22, // Aumentei um pouco para destaque
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              );
            },
          ),
        ),

        // ✅ TAGS ALIMENTARES E DE BEBIDAS
        if (product.product.dietaryTags.isNotEmpty ||
            product.product.beverageTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...product.product.dietaryTags.map(
                  (tag) => Chip(
                    label: Text(
                      foodTagNames[tag] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.green.shade50,
                    labelStyle: TextStyle(color: Colors.green.shade800),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
                ...product.product.beverageTags.map(
                  (tag) => Chip(
                    label: Text(
                      beverageTagNames[tag] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: TextStyle(color: Colors.blue.shade800),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],

        // ✅ Espaçamento antes dos grupos de opções
        const SizedBox(height: 20),

        // ✅ REMOVIDO: Texto "Tamanho" redundante (já aparece no nome do produto)
        // O tamanho já é selecionado antes de abrir esta tela
        if (product.selectedVariants.isNotEmpty) //
          ListView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: product.selectedVariants.length, //
            itemBuilder: (_, i) {
              final variant = product.selectedVariants[i]; //
              return VariantWidget(
                key: _variantKeys[variant.id], //
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
          ),
        const SizedBox(height: 24),
        // ✅ MENUHUB STYLE: Campo de observação
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'Alguma observação?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // Contador de caracteres
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.observationController,
                builder: (context, value, child) {
                  return Text(
                    '${value.text.length}/140',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: widget.observationController,
            keyboardType: TextInputType.text,
            maxLength: 140,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ex: tirar a cebola, maionese à parte etc.',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              counterText: '', // Esconde o contador padrão (já temos o nosso)
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Helper para obter texto do frete dinâmico
  String _getDeliveryFeeText(Store store) {
    if (_isFreeDelivery(store)) return 'Grátis';

    final fee = store.store_operation_config?.deliveryFee;
    if (fee != null && fee > 0) {
      return 'R\$ ${fee.toStringAsFixed(2).replaceAll('.', ',')}';
    }

    return 'Grátis';
  }

  bool _isFreeDelivery(Store store) {
    final threshold = store.getFreeDeliveryThresholdForDelivery();
    if (threshold != null && threshold > 0) return true;

    final fee = store.store_operation_config?.deliveryFee;
    return fee == null || fee <= 0;
  }
}

/// ✅ MENUHUB STYLE: Visualizador de imagem em fullscreen
/// Fundo preto, imagem centralizada, X no canto, nome/descrição embaixo
class _FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String productName;
  final String? productDescription;
  final String heroTag;

  const _FullscreenImageViewer({
    required this.imageUrl,
    required this.productName,
    this.productDescription,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagem centralizada
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder:
                      (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                  errorWidget:
                      (context, url, error) => const Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey,
                      ),
                ),
              ),
            ),
          ),

          // Botão X para fechar (canto superior direito)
          Positioned(
            top: topPadding + 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close, size: 28, color: Colors.white),
                ),
              ),
            ),
          ),

          // Nome e descrição na parte inferior
          Positioned(
            bottom: bottomPadding + 24,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (productDescription != null &&
                    productDescription!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    productDescription!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
