// lib/cubit/catalog_state.dart

import 'package:equatable/equatable.dart';
import '../models/banners.dart';
import '../models/category.dart';
import '../models/product.dart';

/// Estado do catálogo: categorias, produtos, banners e categoria selecionada.
/// Separado do StoreState para que mudanças no catálogo não disparem
/// rebuilds em widgets que só consomem dados da loja (horários, config, etc).
class CatalogState extends Equatable {
  const CatalogState({
    this.products,
    this.categories,
    this.selectedCategory,
    this.banners,
  });

  final List<Product>? products;
  final List<Category>? categories;
  final Category? selectedCategory;
  final List<BannerModel>? banners;

  @override
  List<Object?> get props => [products, categories, selectedCategory, banners];

  /// Categorias ativas (filtradas)
  List<Category> get activeCategories =>
      (categories ?? []).where((c) => c.isActive).toList();

  CatalogState copyWith({
    List<Product>? products,
    List<Category>? categories,
    Category? selectedCategory,
    List<BannerModel>? banners,
  }) {
    return CatalogState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      banners: banners ?? this.banners,
    );
  }
}
