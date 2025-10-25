import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/core/extensions.dart';
import 'package:collection/collection.dart'; // Importar para usar firstWhereOrNull e min

import '../../../../helpers/navigation_helper.dart';
import '../../../../models/product.dart';
import '../../../../models/category.dart'; // Precisamos da categoria para o contexto de preço

class FeaturedProductList extends StatelessWidget {
  final List<Product> products;
  final List<Category> categories; // Adicionado para obter contexto

  const FeaturedProductList({super.key, required this.products, required this.categories});

  @override
  Widget build(BuildContext context) {
    final featuredProducts = products
        .where((p) => p.featured == true)
        .take(6)
        .toList();

    if (featuredProducts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Destaques',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280, // Adjust height as needed
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: featuredProducts.length,
              itemBuilder: (context, index) {
                final product = featuredProducts[index];
                // Encontra a primeira categoria à qual o produto pertence para dar um contexto
                final firstCategoryId = product.categoryLinks.firstOrNull?.categoryId;
                final category = categories.firstWhereOrNull((c) => c.id == firstCategoryId);

                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ProductCard(
                    product: product,
                    category: category, // Passa a categoria para o card
                    onTap: () => goToProductPage(context, product),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final Category? category; // Recebe a categoria para contexto de preço
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.category,
    required this.onTap,
  });

  // Função helper para determinar o preço a ser exibido
  String _getDisplayPrice() {
    // Se for customizável (pizza, açaí), pega o menor preço dos tamanhos
    if (category?.isCustomizable ?? false) {
      if (product.prices.isNotEmpty) {
        final minPrice = product.prices.map((p) => p.price).reduce(min);
        return 'A partir de ${minPrice.toCurrency}';
      }
    }

    // Se for um produto geral, pega o preço do vínculo com a categoria
    if (category != null) {
      final link = product.categoryLinks.firstWhereOrNull((l) => l.categoryId == category!.id);
      if (link != null) {
        final price = link.isOnPromotion && link.promotionalPrice != null
            ? link.promotionalPrice!
            : link.price;
        return price.toCurrency;
      }
    }

    // Fallback: se não encontrar um preço contextual, mostra o menor preço possível
    if (product.categoryLinks.isNotEmpty) {
      final minPrice = product.categoryLinks.map((l) => l.price).reduce(min);
      return minPrice.toCurrency;
    }

    return 'Verificar';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180, // Fixed width for each card
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: CachedNetworkImage(
                // Usa o getter seguro para a URL da imagem
                imageUrl: product.coverImageUrl ?? 'https://placehold.co/180x120/e0e0e0/a0a0a0?text=Sem+Imagem',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  height: 120,
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  height: 120,
                  child: const Icon(Icons.error),
                ),
              ),
            ),

            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Product Name and Description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (product.description != null)
                          Text(
                            product.description!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),

                    // Price
                    Text(
                      _getDisplayPrice(), // Usa a função para obter o preço correto
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}