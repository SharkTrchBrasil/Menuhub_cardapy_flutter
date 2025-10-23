
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:totem/themes/classic/widgets/product_grid_card.dart';
import 'package:totem/themes/classic/widgets/product_list_card.dart';

import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../ds_theme.dart';

class AllCategoriesWithProductsList extends StatelessWidget {
  final List<Category> categories;
  final List<Product> products;
  final DsProductLayout productLayout;

  const AllCategoriesWithProductsList({
    required this.categories,
    required this.products,
    required this.productLayout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.map((category) {
        final categoryProducts = products
            .where((p) => p.category == category)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildProductList(
                context,
                categoryProducts,
                productLayout,
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProductList(
      BuildContext context,
      List<Product> products,
      DsProductLayout layout,
      ) {


    final screenWidth = MediaQuery.of(context).size.width;
    final isGrid = layout == DsProductLayout.grid;

    final crossAxisCount =
    isGrid
        ? (screenWidth / 200).floor().clamp(1, 5)
        : (screenWidth >= 800 ? 3 : 1); // Lista: 1 no mobile, 2 no desktop

    return StaggeredGrid.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,

      children: List.generate(products.length, (index) {
        final product = products[index];
        return layout == DsProductLayout.list
            ? ProductListCard(product: product)
            : ProductGridCard(product: product);
      }),
    );


  }
}


