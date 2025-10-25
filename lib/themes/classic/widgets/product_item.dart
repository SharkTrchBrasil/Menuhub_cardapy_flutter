import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/core/extensions.dart';
import 'package:collection/collection.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';

class ProductItem extends StatelessWidget {
  final Product product;
  final Category category; // Categoria necessária para o contexto de preço
  final VoidCallback? onTap;

  const ProductItem({
    super.key,
    required this.product,
    required this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    int? displayPrice;
    int? originalPrice;

    // Lógica de preço para categoria customizável (sabores)
    if (category.isCustomizable) {
      if (product.prices.isNotEmpty) {
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

    displayPrice ??= 0;
    final hasPromo = originalPrice != null;
    final discountPercent = hasPromo ? (((originalPrice! - displayPrice) / originalPrice) * 100).round() : 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.description != null && product.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      product.description!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        category.isCustomizable ? 'A partir de ${displayPrice.toCurrency}' : displayPrice.toCurrency,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (hasPromo) ...[
                        const SizedBox(width: 8),
                        Text(
                          originalPrice!.toCurrency,
                          style: const TextStyle(fontSize: 13, color: Colors.grey, decoration: TextDecoration.lineThrough),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green[600], borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            '-$discountPercent%',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildProductImage(product),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    final coverImageUrl = product.coverImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: SizedBox(
        width: 80,
        height: 80,
        child: coverImageUrl != null && coverImageUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: coverImageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
          ),
          errorWidget: (context, url, error) => _buildImagePlaceholder(),
        )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
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
    );
  }
}