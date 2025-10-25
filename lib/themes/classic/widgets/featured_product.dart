import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart'; // Import necessário

import 'package:collection/collection.dart'; // Import necessário

import '../../../helpers/navigation_helper.dart';
import '../desktop/widgets/fetrured_list.dart';

class FeaturedProductGrid extends StatelessWidget {
  final List<Product> products;
  final List<Category> categories; // Adicionado para obter contexto

  const FeaturedProductGrid({super.key, required this.products, required this.categories});

  @override
  Widget build(BuildContext context) {
    final featuredProducts = products.where((p) => p.featured).take(6).toList();

    if (featuredProducts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Destaques',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          StaggeredGrid.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: List.generate(featuredProducts.length, (index) {
              final product = featuredProducts[index];
              // Encontra a categoria para dar contexto ao preço
              final categoryId = product.categoryLinks.firstOrNull?.categoryId;
              final category = categories.firstWhereOrNull((c) => c.id == categoryId);

              return StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1.7,
                child: ProductCard(
                  product: product,
                  category: category, // Passa a categoria
                  onTap: () => goToProductPage(context, product),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// Nota: Assumi que `IfoodProductCard` é o `product_item_featured.dart`
// Você precisará garantir que `IfoodProductCard` também aceite `Category? category`
// e tenha a lógica de preço corrigida, similar ao `ProductCard` e `ProductItem`.