import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/core/extensions.dart';
import 'package:collection/collection.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import '../../../services/availability_service.dart';

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
    bool showAsStartingFrom = false;

    // Lógica de preço para categoria customizável (sabores)
    if (category.isCustomizable) {
      if (product.prices.isNotEmpty) {
        final validPrices = product.prices.where((p) => p.price > 0).map((p) => p.price);
        displayPrice = validPrices.isNotEmpty ? validPrices.reduce(min) : 0;
        showAsStartingFrom = true;
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
      
      // ✅ Se preço é 0, busca menor preço nos grupos de complementos
      if ((displayPrice == null || displayPrice == 0) && product.variantLinks.isNotEmpty) {
        int minVariantPrice = 0;
        for (final variantLink in product.variantLinks) {
          final variant = variantLink.variant;
          if (variant.options.isNotEmpty) {
            for (final option in variant.options) {
              if (option.resolvedPrice > 0 && (minVariantPrice == 0 || option.resolvedPrice < minVariantPrice)) {
                minVariantPrice = option.resolvedPrice;
              }
            }
          }
        }
        if (minVariantPrice > 0) {
          displayPrice = minVariantPrice;
          showAsStartingFrom = true;
        }
      }
    }

    displayPrice ??= 0;
    final hasPromo = originalPrice != null;
    final discountPercent = hasPromo ? (((originalPrice! - displayPrice) / originalPrice) * 100).round() : 0;

    // ✅ VERIFICAÇÃO DE DISPONIBILIDADE
    final isAvailable = AvailabilityService.isProductAvailableNow(product);

    return GestureDetector(
      onTap: isAvailable ? onTap : null, // Desabilita clique se indisponível
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.5, // Efeito visual de desabilitado
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
                        if (isAvailable) ...[
                          Text(
                            (category.isCustomizable || showAsStartingFrom) ? 'A partir de ${displayPrice.toCurrency}' : displayPrice.toCurrency,
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
                        ] else ...[
                          // Texto de indisponível
                          const Text(
                            'Indisponível no momento',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildProductImage(product, isAvailable),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product, bool isAvailable) {
    final coverImageUrl = product.coverImageUrl;
    return Stack(
      children: [
        ClipRRect(
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
        ),
        if (!isAvailable)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Center(
                child: Icon(Icons.block, color: Colors.red, size: 30),
              ),
            ),
          ),
      ],
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