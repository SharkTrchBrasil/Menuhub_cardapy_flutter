import 'package:flutter/material.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/product.dart';
import 'package:intl/intl.dart';

class IfoodProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const IfoodProductCard({
    super.key,
    required this.product,
    this.onTap,
  });























  @override
  Widget build(BuildContext context) {
    final imageUrl = product.coverImageUrl ?? '';
    final hasPromo = product.activatePromotion == true;
    final oldPrice = product.basePrice;
    final newPrice = product.promotionPrice ?? product.basePrice;
    final discountPercent = hasPromo
        ? (((oldPrice - newPrice) / oldPrice) * 100).round()
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Preços
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: hasPromo
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    newPrice.toCurrency,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          oldPrice.toCurrency,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '-$discountPercent%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              )
                  : Text(
                oldPrice.toCurrency,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Nome do produto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: hasPromo ? 1: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
