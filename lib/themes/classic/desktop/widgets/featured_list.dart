import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/core/extensions.dart';
import 'package:collection/collection.dart';

import '../../../../helpers/navigation_helper.dart';
import '../../../../models/product.dart';
import '../../../../models/category.dart';

class FeaturedProductList extends StatelessWidget {
  final List<Product> products;
  final List<Category> categories;

  const FeaturedProductList({
    super.key,
    required this.products,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final availableItems =
        products.where((p) => p.isAvailable && p.soldCount > 0).toList();
    availableItems.sort((a, b) => b.soldCount.compareTo(a.soldCount));

    int limit =
        availableItems.length >= 6 ? 6 : (availableItems.length >= 3 ? 3 : 0);
    if (limit == 0) return const SizedBox.shrink();

    final displayProducts = availableItems.take(limit).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Destaques',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  displayProducts.map((p) {
                    final cat = categories.firstWhereOrNull(
                      (c) => c.id == p.categoryLinks.firstOrNull?.categoryId,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 140,
                        child: ProductCard(
                          product: p,
                          category: cat,
                          onTap:
                              () => NavigationHelper.showProductDialog(
                                context: context,
                                product: p,
                                category: cat!,
                              ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final Category? category;
  final VoidCallback onTap;
  final bool isTopSold;

  const ProductCard({
    super.key,
    required this.product,
    this.category,
    required this.onTap,
    this.isTopSold = false,
  });

  @override
  Widget build(BuildContext context) {
    int? displayPrice;
    int? originalPrice;
    bool showAsStartingFrom = false;

    // Lógica de Preço
    if (category?.isCustomizable ?? false) {
      final valid = product.prices
          .where((p) => p.price > 0)
          .map((p) => p.price);
      if (valid.isNotEmpty) {
        displayPrice = valid.reduce(min);
        showAsStartingFrom = true;
      }
    } else if (category != null) {
      final link = product.categoryLinks.firstWhereOrNull(
        (l) => l.categoryId == category!.id,
      );
      final lp = link?.price ?? 0;
      final lop = link?.originalPrice ?? 0;
      final pp = product.price ?? 0;
      final lpp =
          (link?.hasPromotion ?? false) ? (link?.promotionalPrice ?? 0) : 0;
      final ppp =
          (product.isOnPromotion && (product.promotionalPrice ?? 0) > 0)
              ? product.promotionalPrice!
              : 0;

      if (lpp > 0 || ppp > 0) {
        displayPrice =
            (lpp > 0 && ppp > 0)
                ? (lpp < ppp ? lpp : ppp)
                : (lpp > 0 ? lpp : ppp);
        if (lop > displayPrice!) {
          originalPrice = lop;
        } else {
          final candidate = lp > pp ? lp : pp;
          if (candidate > displayPrice!) originalPrice = candidate;
        }
      } else {
        displayPrice = lp > 0 ? lp : pp;
      }
    }

    displayPrice ??= 0;
    final hasPromo = originalPrice != null && originalPrice! > displayPrice!;
    final discount =
        hasPromo
            ? (((originalPrice! - displayPrice!) / originalPrice!) * 100)
                .round()
            : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl:
                        product.imageUrl ??
                        'https://placehold.co/180x120/e0e0e0/a0a0a0?text=Sem+Imagem',
                    height: 90,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  if (isTopSold)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Mais pedido',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Preço Primeiro (Versão Preferida pelo Usuário - Imagem 2)
            if (showAsStartingFrom)
              Text(
                'a partir de',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  height: 1.0,
                ),
              ),
            Text(
              displayPrice.toCurrency,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            if (hasPromo)
              Row(
                children: [
                  Text(
                    originalPrice!.toCurrency,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 6),
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 2),
            // Nome Segundo
            Text(
              product.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade700,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
