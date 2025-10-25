import 'package:totem/models/store.dart';

import '../models/banners.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/rating_summary.dart';

class StoreState {
  StoreState({
    this.products,
    this.selectedCategory,
    this.store,
    this.banners,
    this.ratingsSummary,
  });

  final List<Product>? products;
  final Category? selectedCategory;
  final Store? store;
  final List<BannerModel>? banners;
  final RatingsSummary? ratingsSummary;

  // ✅ CORREÇÃO: Usa as categorias vindas do store, não dos produtos
  late final List<Category> categories = store?.categories ?? [];

  StoreState copyWith({
    List<Product>? products,
    Category? selectedCategory,
    Store? store,
    List<BannerModel>? banners,
    RatingsSummary? ratingsSummary,
  }) {
    return StoreState(
      products: products ?? this.products,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      store: store ?? this.store,
      banners: banners ?? this.banners,
      ratingsSummary: ratingsSummary ?? this.ratingsSummary,
    );
  }
}