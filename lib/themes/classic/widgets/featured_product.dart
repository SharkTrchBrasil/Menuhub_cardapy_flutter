import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:totem/models/product.dart';
import 'package:totem/themes/classic/widgets/product_item_featured.dart';

import '../../../helpers/navigation_helper.dart';

class FeaturedProductGrid extends StatelessWidget {
  final List<Product> products;

  const FeaturedProductGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    // Filtra e limita a 6 itens
    final featuredProducts = products
        .where((p) => p.featured == true)
        .take(6)
        .toList();

    if (featuredProducts.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Destaques',
            style: TextStyle(fontWeight: FontWeight.w700),

          ),
          const SizedBox(height: 12),

          StaggeredGrid.count(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 12,
            children: List.generate(featuredProducts.length, (index) {
              final product = featuredProducts[index];
              return StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1.7, // Altura proporcional, ajuste conforme necessário
                child: IfoodProductCard(product: product, onTap: () => goToProductPage(context, product),),
              );
            }),
          ),




        ],
      ),
    );
  }
}

