import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/core/extensions.dart';
import 'package:collection/collection.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import '../../../models/option_group.dart';
import '../../../services/availability_service.dart';

class ProductItem extends StatelessWidget {
  final Product product;
  final Category category;
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

    // 1. Lógica de preço para pizzas/customizáveis
    if (category.isCustomizable) {
      final sizeGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.size,
      );

      if (sizeGroup != null && sizeGroup.items.isNotEmpty) {
        int minP = 99999999;
        bool found = false;

        for (var size in sizeGroup.items.where((s) => s.isActive)) {
          if (size.price > 0 && size.price < minP) {
            minP = size.price;
            found = true;
          }
        }

        if (found) {
          displayPrice = minP;
          showAsStartingFrom = true;
        }
      }

      if (displayPrice == null && product.prices.isNotEmpty) {
        final validPrices = product.prices
            .where((p) => p.price > 0)
            .map((p) => p.price);
        if (validPrices.isNotEmpty) {
          displayPrice = validPrices.reduce(min);
          showAsStartingFrom = true;
        }
      }
    } else {
      // 2. Lógica para categorias gerais (com suporte a promoção)
      print('=== DEBUG PROMOTIONAL PRICES ===');
      print('DEBUG: product=${product.name}');
      print('DEBUG: productId=${product.id}');
      print('DEBUG: categoryLinks count=${product.categoryLinks.length}');

      final link = product.categoryLinks.firstWhereOrNull(
        (l) => l.categoryId == category.id,
      );

      print('DEBUG: searching for categoryId=${category.id}');
      print('DEBUG: link found=${link != null}');

      if (link != null) {
        print('DEBUG: link.price=${link.price} (${link.price.runtimeType})');
        print(
          'DEBUG: link.promotionalPrice=${link.promotionalPrice} (${link.promotionalPrice.runtimeType})',
        );
        print(
          'DEBUG: link.isOnPromotion=${link.isOnPromotion} (${link.isOnPromotion.runtimeType})',
        );

        // Usa diretamente price e promotional_price do link
        if (link.isOnPromotion &&
            link.promotionalPrice != null &&
            link.promotionalPrice! > 0 &&
            link.promotionalPrice! < link.price) {
          displayPrice = link.promotionalPrice!; // preço com desconto
          originalPrice = link.price; // preço original para riscar

          print('DEBUG: PROMOÇÃO ATIVADA!');
          print('DEBUG: displayPrice=$displayPrice');
          print('DEBUG: originalPrice=$originalPrice');
        } else {
          // Sem promoção no link: usa price normal do link
          displayPrice = link.price;
          originalPrice = null;

          print('DEBUG: SEM PROMOÇÃO NO LINK - usando preço normal');
          print('DEBUG: displayPrice=$displayPrice');
        }
      } else {
        // Fallback: Se não tem link para esta categoria, usa o preço base do produto
        displayPrice = product.price ?? 0;
        originalPrice = null;
        print('DEBUG: LINK NULO - usando preço base do produto: $displayPrice');
      }

      print('=== END DEBUG ===\n');
    }

    displayPrice ??= 0;
    final isAvailable = AvailabilityService.isProductAvailableNow(product);

    print('DEBUG: CÁLCULO FINAL ===');
    print('DEBUG: displayPrice=$displayPrice');
    print('DEBUG: originalPrice=$originalPrice');
    print('DEBUG: isAvailable=$isAvailable');

    final hasPromo = originalPrice != null && originalPrice > displayPrice;
    print('DEBUG: hasPromo=$hasPromo');

    final discount =
        (hasPromo
            ? ((originalPrice - displayPrice) / originalPrice * 100).round()
            : 0);

    print('DEBUG: discount=$discount%');

    if (hasPromo) {
      print('DEBUG: UI FORMATADA ===');
      print(
        'DEBUG: Preco original: R' + (originalPrice / 100).toStringAsFixed(2),
      );
      print(
        'DEBUG: Preco promocional: R' + (displayPrice / 100).toStringAsFixed(2),
      );
      print('DEBUG: Desconto: ' + discount.toString() + '% OFF');
    }

    print('=== END DEBUG FINAL ===\n');

    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.5,
        child: Column(
          children: [
            // Divider suave entre itens
            Divider(
              height: 1,
              thickness: 0.3,
              color: Colors.grey.shade200,
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nome do Produto (Peso maior que descrição)
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (product.description != null &&
                            product.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          // Descrição (Cor suave/grey)
                          Text(
                            product.description!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Seção de Preço
                        Row(
                          children: [
                            if (isAvailable) ...[
                              if (hasPromo) ...[
                                Text(
                                  displayPrice.toCurrency,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  originalPrice.toCurrency,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                                    '-$discount%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  showAsStartingFrom
                                      ? 'A partir de ${displayPrice.toCurrency}'
                                      : displayPrice.toCurrency,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ] else ...[
                              const Text(
                                'Indisponível',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildImage(context, product, isAvailable),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, Product product, bool isAvailable) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 80,
            height: 80,
            child:
                product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder:
                          (c, u) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                      errorWidget: (c, u, e) => _placeholder(),
                    )
                    : _placeholder(),
          ),
        ),
        if (!isAvailable)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.block, color: Colors.red, size: 24),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/burguer.svg',
          width: 40,
          colorFilter: ColorFilter.mode(Colors.grey.shade300, BlendMode.srcIn),
        ),
      ),
    );
  }
}
