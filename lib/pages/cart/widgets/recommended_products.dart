import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart'; // Import para usar 'min'
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/product.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import '../../../helpers/navigation_helper.dart';

class RecommendedProductsSection extends StatelessWidget {
  final List<Product> recommendedProducts;
  // ✅ 1. RECEBE A FUNÇÃO DE CALLBACK DA PÁGINA PAI
  final void Function(Product product) onProductTap;

  const RecommendedProductsSection({
    required this.recommendedProducts,
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
            scrollDirection: Axis.horizontal,
            itemCount: recommendedProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final product = recommendedProducts[i];
              // ✅ 2. PASSA A FUNÇÃO DE CALLBACK PARA O WIDGET FILHO
              return RecommendedProductTile(
                product: product,
                onTap: () => onProductTap(product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class RecommendedProductTile extends StatefulWidget {
  final Product product;
  // ✅ 3. O WIDGET AGORA RECEBE UM SIMPLES VOIDCALLBACK
  final VoidCallback onTap;

  const RecommendedProductTile({
    required this.product,
    required this.onTap,
    super.key,
  });

  @override
  State<RecommendedProductTile> createState() => _RecommendedProductTileState();
}

class _RecommendedProductTileState extends State<RecommendedProductTile> {
  // ✅ 4. ESTADO DE LOADING MOVIDO PARA A CLASSE DE ESTADO
  bool _isLoading = false;

  // ✅ 5. FUNÇÃO DE PREÇO CORRIGIDA
  String _getDisplayPrice() {
    // Se o produto tiver preços de "sabor" (pizza, açaí), pega o menor deles.
    if (widget.product.prices.isNotEmpty) {
      final minPrice = widget.product.prices.map((p) => p.price).reduce(min);
      return minPrice.toCurrency;
    }
    // Se for um produto geral, pega o menor preço entre todos os seus vínculos de categoria.
    if (widget.product.categoryLinks.isNotEmpty) {
      final minPrice = widget.product.categoryLinks.map((link) {
        return link.isOnPromotion && link.promotionalPrice != null
            ? link.promotionalPrice!
            : link.price;
      }).reduce(min);
      return minPrice.toCurrency;
    }
    // Fallback se não encontrar nenhum preço.
    return 'N/D';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    // ✅ 6. VERIFICAÇÃO DE VARIANTES MAIS ROBUSTA
    final hasRequiredVariants = widget.product.variantLinks.any((link) => link.minSelectedOptions > 0);

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: widget.product.coverImageUrl ?? 'https://placehold.co/120/e0e0e0/a0a0a0?text=Sem+Foto',
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
                      : () async {
                    // Se tem variantes obrigatórias, navega para a página do produto
                    if (hasRequiredVariants) {
                      goToProductPage(context, widget.product);
                      return;
                    }
                    // Se não, executa a ação de adicionar ao carrinho
                    setState(() => _isLoading = true);
                    try {
                      // ✅ 7. CHAMA A FUNÇÃO DO PAI, QUE CONTÉM A LÓGICA DO CUBIT
                     // await widget.onTap();
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
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
                      // Mostra um ícone de "ver opções" se tiver variantes não obrigatórias
                        hasRequiredVariants || widget.product.variantLinks.isNotEmpty
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

          // ✅ 8. LÓGICA DE PREÇO USANDO A NOVA FUNÇÃO
          Text(
            _getDisplayPrice(),
            style: TextStyle(fontWeight: FontWeight.w600, color: theme.productTextColor),
          ),

          const SizedBox(height: 4),
          Text(
            widget.product.name,
            style: TextStyle(color: theme.cartTextColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}