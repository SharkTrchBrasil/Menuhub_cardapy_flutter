import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:totem/themes/classic/widgets/product_grid_card.dart';
import 'package:totem/themes/classic/widgets/product_list_card.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../ds_theme.dart';
import 'category_card.dart';

class CategoryVerticalList extends StatelessWidget {
  final List<Category> categories;
  final Category? selectedCategory;
  final List<Product> products;
  final Function(Category) onCategorySelected;
  final DsProductLayout productLayout;

  const CategoryVerticalList({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.products,
    required this.onCategorySelected,
    required this.productLayout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Sidebar de categorias
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
            width: 104,
            child: ListView.builder(
                   //     padding: const EdgeInsets.symmetric(vertical: 24),
              itemCount: categories.length,
           //   separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final category = categories[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: CategoryCard(
                    category: category,
                    isSelected: selectedCategory?.id == category.id,
                    onTap: () => onCategorySelected(category),
                  ),
                );
              },
            ),
          ),
        ),
         const VerticalDivider(width: 1),
        // // Conteúdo de produtos
        // // Conteúdo de produtos
        Expanded(
          // Este Expanded agora vai receber um limite de altura do ConstrainedBox externo
          child:
              selectedCategory == null
                  ? const Center(child: Text("Selecione uma categoria"))
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Padding(
                      //   padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      //   child: Text(
                      //     selectedCategory!.name,
                      //     style: theme.textTheme.titleLarge?.copyWith(
                      //       fontWeight: FontWeight.bold,
                      //     ),
                      //   ),
                      // ),
                      Expanded(
                        // Este Expanded garantirá que a lista de produtos ocupe o restante do espaço vertical
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildProductVerticalList(
                            context,
                            products
                                .where((p) => p.category == selectedCategory)
                                .toList(),
                            productLayout,
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildProductVerticalList(
    BuildContext context,
    List<Product> products,
    DsProductLayout layout,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isGrid = layout == DsProductLayout.grid;

        final crossAxisCount = isGrid
            ? (screenWidth < 600 ? 1 : (screenWidth / 200).floor().clamp(1, 5))
            : (screenWidth >= 800 ? 3 : 1);


        // Remove o SingleChildScrollView daqui
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
      },
    );
  }
}
