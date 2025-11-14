import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart'; // Import para usar 'min'
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/product.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

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

    // ✅ Verifica se tem QUALQUER variante (para mostrar ícone correto)
    final hasAnyVariants = widget.product.variantLinks.isNotEmpty;

    return SizedBox(
      width: 120,
      child: GestureDetector(
        onTap: _isLoading ? null : widget.onTap,
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
                      : () {
                    // ✅ Previne propagação do evento para o tile pai
                    // O callback do pai decide se vai para detalhes ou adiciona direto
                    setState(() => _isLoading = true);
                    widget.onTap();
                    // Reset loading após delay para feedback visual
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    });
                  },
                  behavior: HitTestBehavior.opaque, // Previne propagação
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
                      // Mostra ícone de "ver opções" se tiver complementos, "add" se for simples
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
      ),
    );
  }
}