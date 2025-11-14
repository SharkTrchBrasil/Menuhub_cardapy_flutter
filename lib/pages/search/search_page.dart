// lib/pages/search/search_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';
import 'package:totem/services/product_filter_service.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import '../../cubit/store_state.dart';
import '../../helpers/navigation_helper.dart';
import '../../cubit/store_cubit.dart';
import '../../models/image_model.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  late ProductFilterOptions _filterOptions;

  @override
  void initState() {
    super.initState();
    _filterOptions = const ProductFilterOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _getFilteredProducts(List<Product> allProducts) {
    return ProductFilterService.filterAndSort(allProducts, _filterOptions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Buscar produtos...',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _filterOptions = _filterOptions.copyWith(searchQuery: () => null);
                });
              },
            ),
          ),
          onChanged: (value) {
            setState(() {
              _filterOptions = _filterOptions.copyWith(
                searchQuery: () => value.isEmpty ? null : value,
              );
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showAdvancedFilters(context),
          ),
        ],
      ),
      body: BlocBuilder<StoreCubit, StoreState>(
        builder: (context, state) {
          final products = state.products ?? [];
          final filtered = _getFilteredProducts(products);

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum produto encontrado',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              if (_filterOptions.sortBy != SortOption.nameAsc ||
                  _filterOptions.category != null ||
                  _filterOptions.minPrice != null ||
                  _filterOptions.maxPrice != null ||
                  _filterOptions.minRating != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_filterOptions.category != null)
                              Chip(
                                label: Text(_filterOptions.category!.name),
                                onDeleted: () {
                                  setState(() {
                                    _filterOptions = _filterOptions.copyWith(category: () => null);
                                  });
                                },
                              ),
                            if (_filterOptions.minPrice != null)
                              Chip(
                                label: Text('Min: R\$ ${_filterOptions.minPrice!.toStringAsFixed(2)}'),
                                onDeleted: () {
                                  setState(() {
                                    _filterOptions = _filterOptions.copyWith(minPrice: () => null);
                                  });
                                },
                              ),
                            if (_filterOptions.maxPrice != null)
                              Chip(
                                label: Text('Max: R\$ ${_filterOptions.maxPrice!.toStringAsFixed(2)}'),
                                onDeleted: () {
                                  setState(() {
                                    _filterOptions = _filterOptions.copyWith(maxPrice: () => null);
                                  });
                                },
                              ),
                            if (_filterOptions.minRating != null)
                              Chip(
                                label: Text('⭐ ${_filterOptions.minRating!.toStringAsFixed(1)}+'),
                                onDeleted: () {
                                  setState(() {
                                    _filterOptions = _filterOptions.copyWith(minRating: () => null);
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterOptions = const ProductFilterOptions();
                            _searchController.clear();
                          });
                        },
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return _ProductCard(product: product);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAdvancedFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AdvancedFiltersSheet(
        filterOptions: _filterOptions,
        categories: context.read<StoreCubit>().state.categories ?? [],
        onFiltersChanged: (newFilters) {
          setState(() {
            _filterOptions = newFilters;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final price = product.prices.isNotEmpty 
        ? product.prices.first.price / 100.0 
        : 0.0;
    
    final firstImage = product.images.isNotEmpty 
        ? product.images.first.url 
        : null;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => goToProductPage(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: firstImage != null && firstImage.isNotEmpty
                  ? Image.network(
                      firstImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.image_not_supported, size: 48),
                    )
                  : const Icon(Icons.image_not_supported, size: 48),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedFiltersSheet extends StatefulWidget {
  final ProductFilterOptions filterOptions;
  final List<Category> categories;
  final Function(ProductFilterOptions) onFiltersChanged;

  const _AdvancedFiltersSheet({
    required this.filterOptions,
    required this.categories,
    required this.onFiltersChanged,
  });

  @override
  State<_AdvancedFiltersSheet> createState() => _AdvancedFiltersSheetState();
}

class _AdvancedFiltersSheetState extends State<_AdvancedFiltersSheet> {
  late ProductFilterOptions _currentFilters;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  late TextEditingController _minRatingController;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.filterOptions;
    _minPriceController = TextEditingController(
      text: _currentFilters.minPrice?.toStringAsFixed(2) ?? '',
    );
    _maxPriceController = TextEditingController(
      text: _currentFilters.maxPrice?.toStringAsFixed(2) ?? '',
    );
    _minRatingController = TextEditingController(
      text: _currentFilters.minRating?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minRatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtros',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          _buildCategoryFilter(),
          const SizedBox(height: 16),
          _buildPriceFilter(),
          const SizedBox(height: 16),
          _buildRatingFilter(),
          const SizedBox(height: 16),
          _buildSortFilter(),
          const SizedBox(height: 24),
          DsPrimaryButton(
            label: 'Aplicar Filtros',
            onPressed: () => widget.onFiltersChanged(_currentFilters),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<Category?>(
          value: _currentFilters.category,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: const Text('Todas as categorias'),
          items: [
            const DropdownMenuItem<Category?>(value: null, child: Text('Todas as categorias')),
            ...widget.categories.map(
              (cat) => DropdownMenuItem<Category?>(value: cat, child: Text(cat.name)),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _currentFilters = _currentFilters.copyWith(category: () => value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Preço', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minPriceController,
                decoration: const InputDecoration(
                  labelText: 'Mínimo',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  final price = double.tryParse(value);
                  setState(() {
                    _currentFilters = _currentFilters.copyWith(
                      minPrice: () => price,
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _maxPriceController,
                decoration: const InputDecoration(
                  labelText: 'Máximo',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  final price = double.tryParse(value);
                  setState(() {
                    _currentFilters = _currentFilters.copyWith(
                      maxPrice: () => price,
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Avaliação Mínima', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _minRatingController,
          decoration: const InputDecoration(
            labelText: 'Rating mínimo (0-5)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.star),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            final rating = double.tryParse(value);
            if (rating != null && rating >= 0 && rating <= 5) {
              setState(() {
                _currentFilters = _currentFilters.copyWith(minRating: () => rating);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildSortFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ordenar por', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<SortOption>(
          value: _currentFilters.sortBy,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: SortOption.nameAsc, child: Text('Nome A-Z')),
            DropdownMenuItem(value: SortOption.nameDesc, child: Text('Nome Z-A')),
            DropdownMenuItem(value: SortOption.priceAsc, child: Text('Menor preço')),
            DropdownMenuItem(value: SortOption.priceDesc, child: Text('Maior preço')),
            DropdownMenuItem(value: SortOption.ratingDesc, child: Text('Melhor avaliação')),
            DropdownMenuItem(value: SortOption.newest, child: Text('Mais recentes')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _currentFilters = _currentFilters.copyWith(sortBy: value);
              });
            }
          },
        ),
      ],
    );
  }
}

