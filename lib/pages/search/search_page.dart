// lib/pages/search/search_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';
import 'package:totem/themes/classic/widgets/product_item.dart';
import '../../cubit/store_state.dart';
import '../../helpers/navigation_helper.dart';
import '../../cubit/store_cubit.dart';

/// Tela de Busca Fullscreen no estilo Menuhub
/// - Campo de busca no topo com botão Cancelar
/// - Resultados agrupados por categoria (lista, não grid)
/// - Ao clicar em um item, abre a tela de detalhes normal
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Foca automaticamente no campo de busca
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  /// Filtra produtos pelo termo de busca
  List<Product> _filterProducts(List<Product> products) {
    if (_searchQuery.isEmpty) return [];

    return products.where((product) {
      final nameMatch = product.name.toLowerCase().contains(_searchQuery);
      final descMatch =
          product.description?.toLowerCase().contains(_searchQuery) ?? false;
      return nameMatch || descMatch;
    }).toList();
  }

  /// Agrupa produtos por categoria
  Map<Category, List<Product>> _groupByCategory(
    List<Product> filteredProducts,
    List<Category> categories,
  ) {
    final Map<Category, List<Product>> grouped = {};

    for (final product in filteredProducts) {
      // Encontra a categoria do produto
      Category? category;

      // Tenta encontrar pelo primaryCategoryId
      if (product.primaryCategoryId != null) {
        category = categories.firstWhereOrNull(
          (c) => c.id == product.primaryCategoryId,
        );
      }

      // Tenta encontrar pelos categoryLinks
      if (category == null && product.categoryLinks.isNotEmpty) {
        final firstLinkCategoryId = product.categoryLinks.first.categoryId;
        category = categories.firstWhereOrNull(
          (c) => c.id == firstLinkCategoryId,
        );
      }

      // Se encontrou categoria, adiciona ao grupo
      if (category != null) {
        grouped.putIfAbsent(category, () => []);
        grouped[category]!.add(product);
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ Header com campo de busca e botão Cancelar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Campo de busca
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText: 'Buscar no cardápio...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade600,
                          ),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                  : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botão Cancelar
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Conteúdo dos resultados
            Expanded(
              child: BlocBuilder<StoreCubit, StoreState>(
                builder: (context, state) {
                  final allProducts = state.products ?? [];
                  final categories = state.categories ?? [];

                  // Se não há busca, mostra placeholder
                  if (_searchQuery.isEmpty) {
                    return _buildEmptySearchState();
                  }

                  // Filtra produtos
                  final filtered = _filterProducts(allProducts);

                  // Se não encontrou nada
                  if (filtered.isEmpty) {
                    return _buildNoResultsState();
                  }

                  // Agrupa por categoria
                  final grouped = _groupByCategory(filtered, categories);

                  // Constrói a lista
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        for (final entry in grouped.entries)
                          _buildCategorySection(entry.key, entry.value),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Placeholder quando não há busca
  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 60, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'O que você está procurando?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  /// Quando não encontra resultados
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Nenhum item encontrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  /// Seção de categoria com produtos
  Widget _buildCategorySection(Category category, List<Product> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header da categoria
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            '${category.name} (${products.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F1F1F),
            ),
          ),
        ),
        // Lista de produtos simplificada (Imagem 5)
        ...products.map((product) => _buildSearchResultItem(product, category)),
      ],
    );
  }

  Widget _buildSearchResultItem(Product product, Category category) {
    return ProductItem(
      product: product,
      category: category,
      onTap:
          () => NavigationHelper.showProductDialog(
            context: context,
            product: product,
            category: category,
          ),
    );
  }
}
