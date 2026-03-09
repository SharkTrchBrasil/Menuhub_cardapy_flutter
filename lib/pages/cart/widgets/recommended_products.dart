import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart'; // Import para usar 'min'
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/themes/ds_theme.dart';

class RecommendedProductsSection extends StatelessWidget {
  final List<Product> recommendedProducts;
  final List<Category>
  allCategories; // ✅ NOVO: Recebe categorias para verificar se é pizza
  // ✅ 1. RECEBE A FUNÇÃO DE CALLBACK DA PÁGINA PAI
  final void Function(Product product) onProductTap;

  const RecommendedProductsSection({
    required this.recommendedProducts,
    required this.allCategories,
    required this.onProductTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Peça também',
          style: TextStyle(
            color: theme.cartTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 192,
          child: ListView.separated(
            scrollDirection: Axis.horizontal, // ✅ Scroll horizontal
            itemCount: recommendedProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final product = recommendedProducts[i];
              // ✅ Busca a categoria do produto (para verificar se é pizza)
              final category = _findCategoryForProduct(product);
              // ✅ 2. PASSA A FUNÇÃO DE CALLBACK PARA O WIDGET FILHO
              return RecommendedProductTile(
                product: product,
                category: category,
                onTap: () => onProductTap(product),
              );
            },
          ),
        ),
      ],
    );
  }

  // ✅ Helper: Encontra a categoria do produto
  Category? _findCategoryForProduct(Product product) {
    if (product.categoryLinks.isEmpty) return null;

    final firstCategoryId = product.categoryLinks.first.categoryId;
    return allCategories.firstWhereOrNull((c) => c.id == firstCategoryId);
  }
}

class RecommendedProductTile extends StatefulWidget {
  final Product product;
  final Category?
  category; // ✅ NOVO: Categoria do produto (para verificar se é pizza)
  // ✅ 3. O WIDGET AGORA RECEBE UM SIMPLES VOIDCALLBACK
  final VoidCallback onTap;

  const RecommendedProductTile({
    required this.product,
    this.category,
    required this.onTap,
    super.key,
  });

  @override
  State<RecommendedProductTile> createState() => _RecommendedProductTileState();
}

class _RecommendedProductTileState extends State<RecommendedProductTile> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    // ✅ Verifica se tem QUALQUER variante (para mostrar ícone correto)
    final hasAnyVariants =
        widget.product.variantLinks.isNotEmpty ||
        (widget.category?.isCustomizable ?? false);

    // ✅ Layout Unificado para todos os produtos
    return SizedBox(
      width: 120,
      height: 200, // Aumentei um pouco a altura para caber o preço promocional
      child: GestureDetector(
        onTap: _isLoading ? null : widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl:
                        widget.product.imageUrl ??
                        'https://placehold.co/120/e0e0e0/a0a0a0?text=Sem+Foto',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap:
                        _isLoading
                            ? null
                            : () {
                              setState(() => _isLoading = true);
                              widget.onTap();
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                  }
                                },
                              );
                            },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child:
                          _isLoading
                              ? const CupertinoActivityIndicator()
                              : Icon(
                                hasAnyVariants ? Icons.more_horiz : Icons.add,
                                size: 20,
                                color: theme.primaryColor,
                              ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ✅ Seção de Preço Atualizada com Promoção
            _buildPriceSection(theme),

            const SizedBox(height: 4),
            Expanded(
              child: Text(
                widget.product.name,
                style: TextStyle(color: theme.cartTextColor, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection(DsTheme theme) {
    int? currentPrice;
    int? originalPrice;
    bool showAsStartingFrom = false;

    // 1. Tenta pegar de CategoryLink
    var link =
        widget.product.categoryLinks.firstWhereOrNull(
          (l) => l.categoryId == widget.category?.id,
        ) ??
        widget.product.categoryLinks.firstOrNull;

    if (link != null) {
      if (link.isOnPromotion && (link.promotionalPrice ?? 0) > 0) {
        currentPrice = link.promotionalPrice!;
        originalPrice = link.price;
      } else if (link.price > 0) {
        currentPrice = link.price;
      }
    }

    // 2. Se o preço base é zero, busca o valor mínimo dos complementos ou grupos obrigatórios
    if (currentPrice == null || currentPrice == 0) {
      final Map<int, int> mandatoryGroups = {};

      // A. VariantLinks (Complementos de Burgers/Itens normais)
      for (final variantLink in widget.product.variantLinks.where(
        (l) => l.isRequired,
      )) {
        int? minOptionPrice;
        for (final option in variantLink.variant.options.where(
          (o) => o.canBeSelected,
        )) {
          if (option.resolvedPrice > 0) {
            if (minOptionPrice == null ||
                option.resolvedPrice < minOptionPrice) {
              minOptionPrice = option.resolvedPrice;
            }
          }
        }

        if (minOptionPrice != null && variantLink.variant.id != null) {
          mandatoryGroups[variantLink.variant.id!] = minOptionPrice;
        }
      }

      // B. OptionGroups (Grupos de Customização/Builder - ex: Pão na Chapa)
      if (widget.category != null) {
        for (final group in widget.category!.optionGroups.where(
          (g) => g.minSelection > 0,
        )) {
          int? minItemPrice;
          for (final item in group.items.where((i) => i.isActive)) {
            if (item.price > 0) {
              if (minItemPrice == null || item.price < minItemPrice) {
                minItemPrice = item.price;
              }
            }
          }
          if (minItemPrice != null && group.id != null) {
            mandatoryGroups[group.id!] = minItemPrice;
          }
        }
      }

      if (mandatoryGroups.isNotEmpty) {
        int minTotalMandatory = 0;
        mandatoryGroups.forEach((id, price) => minTotalMandatory += price);
        currentPrice = minTotalMandatory;
        showAsStartingFrom = true;
      }
    }

    // 3. Se ainda não achou (ou para pizzas tradicionais que usam a lista de prices)
    if (currentPrice == null || currentPrice == 0) {
      if (widget.category?.isCustomizable == true &&
          widget.product.prices.isNotEmpty) {
        final validPrices = widget.product.prices
            .where((p) => p.price > 0)
            .map((p) => p.price.toInt());
        if (validPrices.isNotEmpty) {
          currentPrice = validPrices.reduce(min);
          showAsStartingFrom = true;
        }
      }
    }

    // fallback final para OptionGroup tipo size (se ainda for zero e for customizável)
    if ((currentPrice == null || currentPrice == 0) &&
        widget.category?.isCustomizable == true) {
      final sizeGroup = widget.category!.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.size,
      );
      if (sizeGroup != null && sizeGroup.items.isNotEmpty) {
        final validPrices = sizeGroup.items
            .where((i) => i.isActive && i.price > 0)
            .map((i) => i.price.toInt());
        if (validPrices.isNotEmpty) {
          currentPrice = validPrices.reduce(min);
          showAsStartingFrom = true;
        }
      }
    }

    if (currentPrice == null || currentPrice == 0)
      return const SizedBox.shrink();

    // ✅ Se é pizza ou foi calculado via complementos, mostra "A partir de"
    if (widget.category?.isCustomizable == true) {
      showAsStartingFrom = true;
    }

    final String pricePrefix = showAsStartingFrom ? 'a partir de ' : '';

    // ✅ Renderiza Layout de Promoção ou Normal
    if (originalPrice != null && originalPrice > currentPrice) {
      final discountPercent =
          (((originalPrice - currentPrice) / originalPrice) * 100).round();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$pricePrefix${currentPrice.toCurrency}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF168F48),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                originalPrice.toCurrency,
                style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF168F48),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '-$discountPercent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Layout Normal
    return Text(
      '$pricePrefix${currentPrice.toCurrency}',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: theme.productTextColor,
        fontSize: 14,
      ),
    );
  }
}

// ✅ Helper class para informações de tamanho
class _SizeInfo {
  final String name;
  final int price;
  final int? slices;
  final int? maxFlavors;

  _SizeInfo({
    required this.name,
    required this.price,
    this.slices,
    this.maxFlavors,
  });
}
