// mobilelayout.dart (Corrigido)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';  // ✅ NOVO: Para chamar API de compartilhamento
import 'package:share_plus/share_plus.dart';  // ✅ NOVO: Compartilhamento
import 'package:totem/core/di.dart';  // ✅ NOVO: Para obter Dio
import 'package:totem/core/extensions.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/models/cart_variant.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/widgets/variant_header_widget.dart';
import 'package:totem/pages/product/widgets/variant_widget.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/cubit/store_cubit.dart';  // ✅ NOVO: Para obter store

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
      for (final variant in widget.productState.product!.selectedVariants) { //
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

    for (final variant in product.selectedVariants) { //
      final offset = _variantOffsets[variant.id]; //
      if (offset != null && selectionPoint >= offset) {
        newStickyVariant = variant;
      }
    }

    if (newStickyVariant?.id != _currentStickyVariant?.id) { //
      setState(() => _currentStickyVariant = newStickyVariant);
    }
  }

  // ✅ Método para rolar até próximo grupo obrigatório não selecionado
  void _scrollToNextRequiredVariant() {
    if (!mounted) return;
    final product = widget.productState.product;
    if (product == null) return;
    
    // Encontra o próximo grupo obrigatório que ainda não foi completado
    int? currentIndex;
    if (_currentStickyVariant != null) {
      currentIndex = product.selectedVariants.indexWhere(
        (v) => v.id == _currentStickyVariant!.id,
      );
    }
    
    // Procura a partir do grupo atual (ou início se não houver)
    final startIndex = (currentIndex ?? -1) + 1;
    for (int i = startIndex; i < product.selectedVariants.length; i++) {
      final variant = product.selectedVariants[i];
      if (variant.isRequired && !variant.isValid) {
        // Encontrou próximo obrigatório não completado
        final key = _variantKeys[variant.id];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.1, // Rola até mostrar 10% do topo do widget
          );
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final imageHeight = media.width * 0.8;
    final contentOverlapPosition = imageHeight - 30;

    // ✅ CORREÇÃO: Acessa o produto através do 'productState'
    // O '!' é seguro aqui, pois o widget pai (product_page.dart)
    // usa um 'AppPageStatusBuilder' que garante que 'product' não é nulo
    // no estado 'PageStatusSuccess'.
    final product = widget.productState.product!; //

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _showTitleInAppBar
          ? AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.shade200,
        title: Text(
          product.product.name, //
          style: widget.theme.bodyTextStyle
              .colored(widget.theme.productTextColor)
              .weighted(FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: widget.theme.primaryColor),
          onPressed: () => context.go('/'),
        ),
        actions: [
          // ✅ NOVO: Botão de compartilhamento no AppBar
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
            child: Stack(
              children: [
                SizedBox(
                  height: imageHeight,
                  width: media.width,
                  child: CachedNetworkImage(
                    imageUrl: product.product.coverImageUrl ?? '', //
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey.shade200),
                    errorWidget: (context, url, error) =>
                    const Icon(Icons.image_not_supported),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: contentOverlapPosition),
                  child: Container(
                    width: media.width,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 150),
                    child: _buildContentColumn(product),
                  ),
                ),
              ],
            ),
          ),
          if (!_showTitleInAppBar)
            Positioned(
              top: topPadding + 16,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.4),
                child: IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.close, size: 20, color: Colors.white),
                ),
              ),
            ),
          // ✅ NOVO: Botão de compartilhamento (canto superior direito)
          if (!_showTitleInAppBar)
            Positioned(
              top: topPadding + 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.4),
                child: IconButton(
                  onPressed: () => _shareProduct(context, product),
                  icon: const Icon(Icons.share, size: 20, color: Colors.white),
                ),
              ),
            ),
          if (_showTitleInAppBar && _currentStickyVariant != null)
            Positioned(
              top: kToolbarHeight + topPadding,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white,
                child: VariantHeaderWidget(
                  key: ValueKey(_currentStickyVariant!.id), //
                  variant: _currentStickyVariant!,
                ),
              ),
            )
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
          'share_type': 'app',  // Tipo de compartilhamento (app, web, etc.)
          'share_source': 'mobile',  // Origem do compartilhamento (mobile, desktop, etc.)
          'utm_source': 'totem_app',  // UTM source para rastreamento
          'utm_medium': 'share',  // UTM medium para rastreamento
        },
      );

      final shareUrl = response.data['share_url'] as String;
      final shareMessage = 'Confira este produto: ${product.product.name}\n$shareUrl';

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
        final productUrl = '$baseUrl/app/products/${store.urlSlug}/${product.product.id}';
        final shareMessage = 'Confira este produto: ${product.product.name}\n$productUrl';

        await Share.share(
          shareMessage,
          subject: product.product.name,
        );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            product.product.name, //
            style: widget.theme.displayMediumTextStyle
                .colored(widget.theme.productTextColor)
                .weighted(FontWeight.w900),
          ),
        ),
        if (product.product.description != null && //
            product.product.description!.isNotEmpty) ...[ //
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              product.product.description!, //
              style: widget.theme.bodyTextStyle.colored(Colors.grey.shade600),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            product.totalPrice.toCurrency, //
            style: widget.theme.displayLargeTextStyle
                .colored(widget.theme.productTextColor)
                .weighted(FontWeight.bold),
          ),
        ),
        const SizedBox(height: 26),
        // ✅ ADICIONADO: Seleção de tamanho para produtos customizáveis (pizza, etc)
        if (product.category.isCustomizable) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Tamanho',
              style: widget.theme.bodyTextStyle.weighted(FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Builder(
              builder: (context) {
                final sizeGroup = product.category.optionGroups
                    .firstWhereOrNull((g) => g.groupType == OptionGroupType.size);
                if (sizeGroup == null || sizeGroup.items.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sizeGroup.items.map((sizeOption) {
                    final isSelected = product.selectedSize?.id == sizeOption.id;
                    return GestureDetector(
                      onTap: () => context.read<ProductPageCubit>().selectSize(sizeOption),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.theme.primaryColor.withOpacity(0.1)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: isSelected
                                ? widget.theme.primaryColor
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sizeOption.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? widget.theme.primaryColor
                                    : Colors.grey.shade800,
                              ),
                            ),
                            if (sizeOption.description != null && sizeOption.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                sizeOption.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Alguma observação?',
              style: widget.theme.bodyTextStyle.weighted(FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: widget.observationController,
            keyboardType: TextInputType.multiline,
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Ex: tirar a cebola, maionese à parte etc.',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.theme.primaryColor)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }
}