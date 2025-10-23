import 'package:flutter/material.dart';
// Importe apenas o que é estritamente necessário para este widget
import '../../../models/category.dart';
// import '../../../models/product.dart'; // Removido, não é mais necessário aqui
// import '../../ds_theme.dart'; // Removido, não é mais necessário aqui
import 'category_card.dart'; // O widget do card de categoria individual



class CategoryHorizontalList extends StatelessWidget {
  final List<Category> categories;
  final Category? selectedCategory;
  // A função onCategorySelected é mantida para que o card possa comunicar a seleção
  final Function(Category) onCategorySelected;
  // Removidos 'products' e 'productLayout' do construtor, pois este widget não lida mais com produtos
  // final List<Product> products;
  // final DsProductLayout productLayout;

  const CategoryHorizontalList({
    super.key, // Adicione super.key
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    // Removidos os parâmetros de produtos
    // required this.products,
    // required this.productLayout,
  });

  @override
  Widget build(BuildContext context) {
    // Este widget agora retorna diretamente a lista horizontal de categorias
    // dentro de um SizedBox com a altura definida para o cabeçalho fixo.
    return SizedBox(
      height: 60, // <--- Altura definida para o cabeçalho fixo
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // O padding foi ajustado para permitir que os CategoryCards caibam
        // considerando o novo design de ícone+texto na mesma linha.
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0), // Ajuste o padding vertical
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final category = categories[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0), // Padding ao redor de cada card
            child: CategoryCard(
              isSelected: selectedCategory?.id == category.id,
              onTap: () => onCategorySelected(category),
              category: category,
            ),
          );
        },
      ),
    );
  }

// O método _buildProductList foi removido, pois este widget não lida mais com produtos.
}