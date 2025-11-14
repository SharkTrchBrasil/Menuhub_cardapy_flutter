// lib/services/product_filter_service.dart
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';

enum SortOption {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
  ratingDesc,
  newest,
  bestSelling,
}

class ProductFilterOptions {
  final String? searchQuery;
  final Category? category;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final bool? inPromotion;
  final bool? bestSelling;
  final SortOption sortBy;

  const ProductFilterOptions({
    this.searchQuery,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.inPromotion,
    this.bestSelling,
    this.sortBy = SortOption.nameAsc,
  });

  ProductFilterOptions copyWith({
    String? Function()? searchQuery,
    Category? Function()? category,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    double? Function()? minRating,
    bool? Function()? inPromotion,
    bool? Function()? bestSelling,
    SortOption? sortBy,
  }) {
    return ProductFilterOptions(
      searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
      category: category != null ? category() : this.category,
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      minRating: minRating != null ? minRating() : this.minRating,
      inPromotion: inPromotion != null ? inPromotion() : this.inPromotion,
      bestSelling: bestSelling != null ? bestSelling() : this.bestSelling,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class ProductFilterService {
  /// Filtra e ordena produtos baseado nas opções
  static List<Product> filterAndSort(
    List<Product> products,
    ProductFilterOptions options,
  ) {
    var filtered = List<Product>.from(products);

    // Busca por nome ou ingredientes
    if (options.searchQuery != null && options.searchQuery!.isNotEmpty) {
      final query = options.searchQuery!.toLowerCase();
      filtered = filtered.where((product) {
        final nameMatch = product.name.toLowerCase().contains(query);
        final descMatch = product.description?.toLowerCase().contains(query) ?? false;
        // Adicionar busca por ingredientes quando disponível
        return nameMatch || descMatch;
      }).toList();
    }

    // Filtro por categoria
    if (options.category != null) {
      filtered = filtered.where((product) {
        return product.categoryLinks.any(
          (link) => link.categoryId == options.category!.id,
        );
      }).toList();
    }

    // Filtro por preço mínimo
    if (options.minPrice != null) {
      filtered = filtered.where((product) {
        final price = _getProductPrice(product);
        return price >= options.minPrice!;
      }).toList();
    }

    // Filtro por preço máximo
    if (options.maxPrice != null) {
      filtered = filtered.where((product) {
        final price = _getProductPrice(product);
        return price <= options.maxPrice!;
      }).toList();
    }

    // Filtro por rating mínimo
    if (options.minRating != null) {
      filtered = filtered.where((product) {
        final rating = product.rating?.averageRating ?? 0.0;
        return rating >= options.minRating!;
      }).toList();
    }

    // Filtro por promoção
    if (options.inPromotion == true) {
      // Implementar lógica de promoção quando disponível
    }

    // Ordenação
    filtered = _sortProducts(filtered, options.sortBy);

    return filtered;
  }

  static double _getProductPrice(Product product) {
    // Retorna o menor preço disponível do produto
    if (product.variantLinks.isEmpty) {
      return product.prices.isNotEmpty ? product.prices.first.price / 100.0 : 0.0;
    }

    double minPrice = double.infinity;
    for (var variantLink in product.variantLinks) {
      for (var option in variantLink.variant.options) {
        final price = (option.price_override ?? option.resolvedPrice) / 100.0;
        if (price < minPrice) {
          minPrice = price;
        }
      }
    }

    return minPrice == double.infinity ? 0.0 : minPrice;
  }

  static List<Product> _sortProducts(List<Product> products, SortOption sortBy) {
    final sorted = List<Product>.from(products);

    switch (sortBy) {
      case SortOption.nameAsc:
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.nameDesc:
        sorted.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.priceAsc:
        sorted.sort((a, b) {
          final priceA = _getProductPrice(a);
          final priceB = _getProductPrice(b);
          return priceA.compareTo(priceB);
        });
        break;
      case SortOption.priceDesc:
        sorted.sort((a, b) {
          final priceA = _getProductPrice(a);
          final priceB = _getProductPrice(b);
          return priceB.compareTo(priceA);
        });
        break;
      case SortOption.ratingDesc:
        sorted.sort((a, b) {
          final ratingA = a.rating?.averageRating ?? 0.0;
          final ratingB = b.rating?.averageRating ?? 0.0;
          return ratingB.compareTo(ratingA);
        });
        break;
      case SortOption.newest:
        // Ordenar por ID (assumindo que IDs maiores são mais recentes)
        sorted.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        break;
      case SortOption.bestSelling:
        // Implementar quando tiver dados de vendas
        break;
    }

    return sorted;
  }
}

