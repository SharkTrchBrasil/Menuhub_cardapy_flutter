import 'package:totem/models/store.dart';

import '../models/banners.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/rating_summary.dart';

class StoreState {
  StoreState( {
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

  late final List<Category> categories = (products
      ?.map((e) => e.category)
      .toSet()
      .toList()
    ?..sort((a, b) => b.priority.compareTo(a.priority))) ??
      [];

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
      ratingsSummary: ratingsSummary ?? this.ratingsSummary

    );
  }
}
