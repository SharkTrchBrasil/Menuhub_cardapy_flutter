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
  final List<Category> allCategories; // ✅ NOVO: Recebe categorias para verificar se é pizza
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
  final Category? category; // ✅ NOVO: Categoria do produto (para verificar se é pizza)
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
  // ✅ 4. ESTADO DE LOADING MOVIDO PARA A CLASSE DE ESTADO
  bool _isLoading = false;

  // ✅ 5. FUNÇÃO DE PREÇO CORRIGIDA - Agora verifica se é pizza
  // ✅ 5. FUNÇÃO DE PREÇO CORRIGIDA E UNIFICADA
  String _getDisplayPrice() {
    // 1. Prioridade: Se for customizável (Pizzas etc)
    if (widget.category?.isCustomizable == true && widget.product.prices.isNotEmpty) {
      final validPrices = widget.product.prices.where((p) => p.price > 0).map((p) => p.price);
      if (validPrices.isNotEmpty) {
        final minPrice = validPrices.reduce(min);
        return '${minPrice.toCurrency}';
      }
    }
    
    // 2. Se tiver preços explícitos (ex: açaí por tamanho), pega o menor > 0
    if (widget.product.prices.isNotEmpty) {
      final validPrices = widget.product.prices.where((p) => p.price > 0).map((p) => p.price);
      if (validPrices.isNotEmpty) {
        final minPrice = validPrices.reduce(min);
        // Se parece ter variações, também usa "A partir de"
        if (validPrices.length > 1) {
             return '${minPrice.toCurrency}';
        }
        return minPrice.toCurrency;
      }
    }

    // 3. Produto geral (via categoryLinks)
    if (widget.product.categoryLinks.isNotEmpty) {
      final validPrices = widget.product.categoryLinks
        .map((link) => link.isOnPromotion && link.promotionalPrice != null 
            ? link.promotionalPrice! 
            : link.price)
        .where((p) => p > 0);
        
      if (validPrices.isNotEmpty) {
        final minPrice = validPrices.reduce(min);
        return minPrice.toCurrency;
      }
    }
    
    // 4. ✅ NOVO: Fallback para Pizza (preço nos tamanhos da categoria)
    if (widget.category?.isCustomizable == true) {
      final sizeGroup = widget.category!.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.size,
      );
      
      if (sizeGroup != null && sizeGroup.items.isNotEmpty) {
        // Encontra o menor preço entre os tamanhos ativos
        final validPrices = sizeGroup.items
            .where((item) => item.isActive && item.price > 0)
            .map((item) => item.price);
            
        if (validPrices.isNotEmpty) {
           final minPrice = validPrices.reduce(min);
           return '${minPrice.toCurrency}';
        }
      }
    }

    // LOG DE DEBUG PARA INVESTIGAR O PROBLEMA DO PREÇO
    print('[DEBUG] Produto sem preço: ${widget.product.name}');
    print('  - Categoria customizável? ${widget.category?.isCustomizable}');
    print('  - Prices count: ${widget.product.prices.length}');
    if (widget.product.prices.isNotEmpty) {
      widget.product.prices.forEach((p) => print('    - Price: ${p.price}, SizeId: ${p.sizeOptionId}'));
    }
    print('  - CategoryLinks count: ${widget.product.categoryLinks.length}');
    
    return ''; // Retorna vazio se não tiver preço
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    
    // ✅ Verifica se tem QUALQUER variante (para mostrar ícone correto)
    final hasAnyVariants = widget.product.variantLinks.isNotEmpty || (widget.category?.isCustomizable ?? false);

    // ✅ Layout Unificado para todos os produtos
    return SizedBox(
      width: 120,
      height: 192,
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
                    imageUrl: widget.product.imageUrl ?? 'https://placehold.co/120/e0e0e0/a0a0a0?text=Sem+Foto',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                      setState(() => _isLoading = true);
                      widget.onTap();
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: _isLoading
                          ? const CupertinoActivityIndicator()
                          : Icon(
                          hasAnyVariants
                              ? Icons.more_horiz
                              : Icons.add,
                          size: 20,
                          color: theme.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              _getDisplayPrice(),
              style: TextStyle(fontWeight: FontWeight.w600, color: theme.productTextColor),
            ),

            const SizedBox(height: 4),
            Expanded(
              child: Text(
                widget.product.name,
                style: TextStyle(color: theme.cartTextColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
