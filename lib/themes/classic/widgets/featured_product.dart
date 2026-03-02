import 'package:flutter/material.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';
import 'package:collection/collection.dart';

import '../../../helpers/navigation_helper.dart';
import '../desktop/widgets/featured_list.dart';

/// ✅ Widget de Destaques — estilo iFood profissional.
///
/// REGRAS DE NEGÓCIO:
/// - A 1ª linha só aparece com no mínimo 3 produtos com vendas (soldCount > 0).
/// - A 2ª linha só aparece quando há pelo menos 6 produtos com vendas.
/// - Apenas linhas COMPLETAS de 3 produtos são exibidas.
/// - Esta seção é independente da seção "Peça novamente".
class FeaturedProductGrid extends StatelessWidget {
  final List<Product> products;
  final List<Category> categories;

  const FeaturedProductGrid({
    super.key,
    required this.products,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return _buildDestaques(context);
  }

  Widget _buildDestaques(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    // 1. Candidatos: produtos disponíveis COM vendas registradas
    final withSales =
        products.where((p) => p.isAvailable && p.soldCount > 0).toList();

    // Ordena: promoção primeiro, depois mais vendidos
    withSales.sort((a, b) {
      if (a.isOnPromotion && !b.isOnPromotion) return -1;
      if (!a.isOnPromotion && b.isOnPromotion) return 1;
      return b.soldCount.compareTo(a.soldCount);
    });

    // 2. Aplica regra de linhas completas de 3
    // Mínimo de 3 para mostrar qualquer coisa
    if (withSales.length < 3) return const SizedBox.shrink();

    // Calcula quantas linhas completas temos (no máximo 2 linhas = 6 produtos)
    final completeRows = (withSales.length ~/ 3).clamp(1, 2);
    final displayProducts = withSales.take(completeRows * 3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;

        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Text(
                  'Destaques',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F1F1F),
                  ),
                ),
              ),
              if (isMobile)
                _buildMobileGrid(context, displayProducts)
              else
                _buildHorizontalRows(context, displayProducts),
            ],
          ),
        );
      },
    );
  }

  /// Mobile: Grid fixo de 3 colunas, N linhas completas
  Widget _buildMobileGrid(BuildContext context, List<Product> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.64,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final p = items[index];
          final cat = _findCategory(p);

          return ProductCard(
            product: p,
            category: cat,
            onTap:
                () => NavigationHelper.showProductDialog(
                  context: context,
                  product: p,
                  category: cat!,
                ),
            // Apenas o produto com maior venda (índice 0) ganha o badge "Mais pedido"
            isTopSold: index == 0,
          );
        },
      ),
    );
  }

  /// Desktop: Linhas de 3 cards lado a lado (não scroll horizontal, mas rows)
  Widget _buildHorizontalRows(BuildContext context, List<Product> items) {
    // Divide em sublistas de 3
    final rows = <List<Product>>[];
    for (int i = 0; i < items.length; i += 3) {
      rows.add(items.sublist(i, (i + 3).clamp(0, items.length)));
    }

    return Column(
      children:
          rows.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final row = entry.value;

            return Padding(
              padding: EdgeInsets.only(
                bottom: rowIndex < rows.length - 1 ? 16 : 0,
              ),
              child: SizedBox(
                height: 205,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    ...row.asMap().entries.map((item) {
                      final itemIndex = item.key;
                      final p = item.value;
                      final cat = _findCategory(p);
                      // Índice global do produto na lista
                      final globalIndex = rowIndex * 3 + itemIndex;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: itemIndex < row.length - 1 ? 12 : 0,
                          ),
                          child: ProductCard(
                            product: p,
                            category: cat,
                            onTap:
                                () => NavigationHelper.showProductDialog(
                                  context: context,
                                  product: p,
                                  category: cat!,
                                ),
                            isTopSold: globalIndex == 0,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Category? _findCategory(Product p) {
    return categories.firstWhereOrNull(
      (c) => c.id == p.categoryLinks.firstOrNull?.categoryId,
    );
  }
}
