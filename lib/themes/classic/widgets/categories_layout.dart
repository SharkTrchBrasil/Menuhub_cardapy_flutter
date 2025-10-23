import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import 'package:totem/themes/classic/widgets/product_grid_card.dart';
import 'package:totem/themes/classic/widgets/product_list_card.dart';
import '../../ds_theme.dart'; // onde está o enum DsProductLayout

class StoreCategoriesAndProducts extends StatelessWidget {
  final List<Category> categories;
  final Category? selectedCategory;
  final List<Product> products;
  final DsProductLayout productLayout;

  const StoreCategoriesAndProducts({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.products,
    required this.productLayout,
  });

  @override
  Widget build(BuildContext context) {
    final List<Product> filteredProducts = selectedCategory != null
        ? products.where((p) => p.category == selectedCategory).toList()
        : products;

    final screenWidth = MediaQuery.of(context).size.width;
    final isGrid = productLayout == DsProductLayout.grid;
    final crossAxisCount = isGrid
        ? (screenWidth / 200).floor().clamp(1, 5)
        : (screenWidth >= 800 ? 2 : 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StaggeredGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: List.generate(filteredProducts.length, (index) {
          final product = filteredProducts[index];
          return isGrid
              ? ProductGridCard(product: product)
              : ProductListCard(product: product);
        }),
      ),
    );
  }
}
