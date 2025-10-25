// themes/classic/widgets/product_item.dart

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/product.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/category.dart';

class ProductItemGrid extends StatelessWidget {
  final Product product;
  final Category category; // Categoria é necessária para o contexto do preço
  final VoidCallback onTap;

  const ProductItemGrid({
    super.key,
    required this.product,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    int? displayPrice;
    int? originalPrice;

    // Lógica de preço para categoria customizável (sabores)
    if (category.isCustomizable) {
      if (product.prices.isNotEmpty) {
        // Mostra o menor preço como "preço de chamada"
        displayPrice = product.prices.map((p) => p.price).reduce(min);
      }
    } else {
      // Lógica para categoria geral
      final link = product.categoryLinks.firstWhereOrNull((l) => l.categoryId == category.id);
      if (link != null) {
        if (link.isOnPromotion && link.promotionalPrice != null) {
          displayPrice = link.promotionalPrice;
          originalPrice = link.price;
        } else {
          displayPrice = link.price;
        }
      }
    }

    // Fallback se nenhum preço foi encontrado
    displayPrice ??= 0;

    final imageUrl = product.coverImageUrl ?? 'https://placehold.co/128/e0e0e0/a0a0a0?text=Produto';

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna com Textos (Título, Descrição, Preço)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Seção de Título e Descrição
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (product.description != null && product.description!.isNotEmpty)
                          Text(
                            product.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),

                    // Seção de Preço
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            category.isCustomizable ? 'A partir de ${displayPrice.toCurrency}' : displayPrice.toCurrency,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (originalPrice != null)
                            Text(
                              originalPrice.toCurrency,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Imagem do Produto
              _buildProductImage(product, imageUrl)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product, String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: SizedBox(
        width: 96,
        height: 96,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade100,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/burguer.svg',
                width: 42,
                height: 42,
                colorFilter: ColorFilter.mode(Colors.grey.shade400, BlendMode.srcIn),
                semanticsLabel: 'Imagem padrão do produto',
              ),
            ),
          ),
        ),
      ),
    );
  }
}