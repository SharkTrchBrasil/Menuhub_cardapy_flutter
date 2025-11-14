// lib/widgets/advanced_product_search.dart
import 'package:flutter/material.dart';
import 'package:totem/models/category.dart';
import 'package:totem/services/product_filter_service.dart';

class AdvancedProductSearch extends StatefulWidget {
  final List<Category> categories;
  final ProductFilterOptions initialFilters;
  final Function(ProductFilterOptions) onFiltersChanged;

  const AdvancedProductSearch({
    super.key,
    required this.categories,
    required this.initialFilters,
    required this.onFiltersChanged,
  });

  @override
  State<AdvancedProductSearch> createState() => _AdvancedProductSearchState();
}

class _AdvancedProductSearchState extends State<AdvancedProductSearch> {
  late TextEditingController _searchController;
  late ProductFilterOptions _currentFilters;
  bool _showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.initialFilters;
    _searchController = TextEditingController(text: widget.initialFilters.searchQuery);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _currentFilters = _currentFilters.copyWith(
      searchQuery: () => _searchController.text,
    );
    widget.onFiltersChanged(_currentFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de busca principal
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar produtos...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showAdvancedFilters)
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () => setState(() => _showAdvancedFilters = false),
                  ),
                IconButton(
                  icon: Icon(_showAdvancedFilters ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
                ),
              ],
            ),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        // Filtros avançados
        if (_showAdvancedFilters) ...[
          const SizedBox(height: 16),
          _buildAdvancedFilters(),
        ],
      ],
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Categoria
          DropdownButtonFormField<Category?>(
            value: _currentFilters.category,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              const DropdownMenuItem<Category?>(value: null, child: Text('Todas')),
              ...widget.categories.map((cat) => DropdownMenuItem(
                value: cat,
                child: Text(cat.name),
              )),
            ],
            onChanged: (category) {
              setState(() {
                _currentFilters = _currentFilters.copyWith(category: () => category);
              });
              widget.onFiltersChanged(_currentFilters);
            },
          ),

          const SizedBox(height: 16),

          // Faixa de preço
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Preço mínimo',
                    hintText: 'R\$ 0,00',
                  ),
                  onChanged: (value) {
                    final price = double.tryParse(value.replaceAll(',', '.'));
                    setState(() {
                      _currentFilters = _currentFilters.copyWith(minPrice: () => price);
                    });
                    widget.onFiltersChanged(_currentFilters);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Preço máximo',
                    hintText: 'R\$ 100,00',
                  ),
                  onChanged: (value) {
                    final price = double.tryParse(value.replaceAll(',', '.'));
                    setState(() {
                      _currentFilters = _currentFilters.copyWith(maxPrice: () => price);
                    });
                    widget.onFiltersChanged(_currentFilters);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Rating mínimo
          Row(
            children: [
              const Text('Avaliação mínima: '),
              Expanded(
                child: Slider(
                  value: _currentFilters.minRating ?? 0.0,
                  min: 0.0,
                  max: 5.0,
                  divisions: 5,
                  label: '${(_currentFilters.minRating ?? 0.0).toStringAsFixed(1)} ⭐',
                  onChanged: (value) {
                    setState(() {
                      _currentFilters = _currentFilters.copyWith(minRating: () => value);
                    });
                    widget.onFiltersChanged(_currentFilters);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ordenação
          DropdownButtonFormField<SortOption>(
            value: _currentFilters.sortBy,
            decoration: const InputDecoration(labelText: 'Ordenar por'),
            items: const [
              DropdownMenuItem(value: SortOption.nameAsc, child: Text('Nome (A-Z)')),
              DropdownMenuItem(value: SortOption.nameDesc, child: Text('Nome (Z-A)')),
              DropdownMenuItem(value: SortOption.priceAsc, child: Text('Preço: Menor')),
              DropdownMenuItem(value: SortOption.priceDesc, child: Text('Preço: Maior')),
              DropdownMenuItem(value: SortOption.ratingDesc, child: Text('Melhor avaliados')),
              DropdownMenuItem(value: SortOption.newest, child: Text('Mais recentes')),
            ],
            onChanged: (sortBy) {
              setState(() {
                _currentFilters = _currentFilters.copyWith(sortBy: sortBy);
              });
              widget.onFiltersChanged(_currentFilters);
            },
          ),
        ],
      ),
    );
  }
}

