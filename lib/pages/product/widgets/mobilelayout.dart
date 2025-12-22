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

// ✅ NOVOS IMPORTS
import 'package:totem/core/enums/foodtags.dart';
import 'package:totem/core/enums/beverage.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/models/availability_model.dart'; // Para TimeShift e ScheduleRule
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
    final imageHeight = media.width * 0.7; // Proporção igual ao iFood
    final contentOverlapPosition = imageHeight - 24; // Overlap suave

    final product = widget.productState.product!;
    final store = context.watch<StoreCubit>().state.store;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: _showTitleInAppBar
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
                icon: Icon(Icons.arrow_back, color: widget.theme.primaryColor),
                onPressed: () => context.go('/'),
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
                // ✅ IFOOD STYLE: Imagem clicável (abre fullscreen)
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
                            placeholder: (context, url) =>
                                Container(color: Colors.grey.shade200),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported, size: 48),
                            ),
                          ),
                        ),
                        // ✅ IFOOD STYLE: Card flutuante com info da loja
                        if (store != null)
                          Positioned(
                            bottom: 32,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                      placeholder: (context, url) => Container(
                                        width: 28,
                                        height: 28,
                                        color: Colors.grey.shade200,
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 28,
                                        height: 28,
                                        color: widget.theme.primaryColor.withOpacity(0.1),
                                        child: Icon(
                                          Icons.store,
                                          size: 16,
                                          color: widget.theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Nome da loja + tempo + frete
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                            '${store.store_operation_config?.deliveryEstimatedMin ?? 30}-${store.store_operation_config?.deliveryEstimatedMax ?? 45} min',
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
                                              color: store.store_operation_config?.freeDeliveryThreshold != null
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
                      ],
                    ),
                  ),
                ),
                // ✅ Conteúdo principal (sem overlap/bordas arredondadas como no iFood)
                Container(
                  width: media.width,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 150),
                  child: _buildContentColumn(product),
                ),
              ],
            ),
          ),
          // ✅ IFOOD STYLE: Botão voltar rosa/vermelho
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
                  onTap: () => context.go('/'),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back, size: 22, color: Colors.white),
                  ),
                ),
              ),
            ),
          // ✅ Botão de compartilhamento (canto superior direito) - removido para ficar igual iFood
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
            )
        ],
      ),
    );
  }

  // ✅ NOVO: Abre imagem em fullscreen (igual iFood imagem 2)
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

  // ✅ Helper para obter texto do frete
  String _getDeliveryFeeText(store) {
    final config = store.store_operation_config;
    if (config == null) return 'Grátis';
    
    if (config.freeDeliveryThreshold != null && config.freeDeliveryThreshold > 0) {
      return 'Grátis';
    }
    
    final fee = config.deliveryFee;
    if (fee != null && fee > 0) {
      return 'R\$ ${fee.toStringAsFixed(2).replaceAll('.', ',')}';
    }
    
    return 'Grátis';
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
        // ✅ CORREÇÃO: Formato correto da URL é /product/{slug}/{id}
        final productSlug = product.product.name.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-9-]'), '');
        final productUrl = '$baseUrl/product/$productSlug/${product.product.id}';
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
    
    // ✅ Verifica disponibilidade
    final isAvailable = AvailabilityService.isProductAvailableNow(product.product);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ IFOOD STYLE: Título grande (22px, bold)
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
        
        // ✅ IFOOD STYLE: Descrição (14px, cinza, line-height 1.4)
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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

        // ✅ IFOOD STYLE: Preço BASE (não muda ao selecionar opções)
        // O preço total com opções aparece apenas no botão do carrinho (bottom)
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: product.category.isCustomizable && product.basePrice == 0
              ? Text(
                  'A partir de ${product.startingPrice.toCurrency}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                )
              : Text(
                  product.basePrice.toCurrency,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
        ),

        // ✅ TAGS ALIMENTARES E DE BEBIDAS
        if (product.product.dietaryTags.isNotEmpty || product.product.beverageTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

        const SizedBox(height: 20),
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
        // ✅ IFOOD STYLE: Campo de observação
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
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
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// ✅ IFOOD STYLE: Visualizador de imagem em fullscreen
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
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Icon(
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
                  child: const Icon(
                    Icons.close,
                    size: 28,
                    color: Colors.white,
                  ),
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
                if (productDescription != null && productDescription!.isNotEmpty) ...[
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