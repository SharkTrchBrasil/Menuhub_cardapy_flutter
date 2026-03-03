// lib/cubit/catalog_cubit.dart

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/utils/app_logger.dart';
import 'package:totem/cubit/catalog_state.dart';
import 'package:totem/models/banners.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/repositories/realtime_repository.dart';

/// CatalogCubit — responsável exclusivamente pelo catálogo do menu:
/// - Lista de produtos
/// - Lista de categorias (com filtragem de inativas)
/// - Categoria selecionada pelo usuário
/// - Banners do menu
///
/// Separado do StoreCubit para que mudanças no catálogo
/// não causem rebuilds em widgets que só usam dados da loja.
class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._realtimeRepository) : super(const CatalogState()) {
    // Escuta atualizações de produtos
    _productsSub = _realtimeRepository.productsController.listen((products) {
      AppLogger.d('📦 [CatalogCubit] ${products.length} produtos recebidos');
      final newState = state.copyWith(products: products);
      emit(newState);

      // Seleciona categoria padrão se ainda não há nenhuma selecionada
      _maybeSelectDefaultCategory();
    });

    // Escuta atualizações de categorias
    _categoriesSub = _realtimeRepository.categoriesController.listen((
      categories,
    ) {
      AppLogger.d(
        '📁 [CatalogCubit] ${categories.length} categorias recebidas',
      );

      // Determina a selectedCategory no novo estado
      final previousSelected = state.selectedCategory;
      final activeCategories = categories.where((c) => c.isActive).toList();
      Category? newSelected;

      if (previousSelected != null) {
        // Tenta manter a categoria atual se ela ainda está ativa
        final updated = activeCategories.firstWhereOrNull(
          (c) => c.id == previousSelected.id,
        );
        if (updated != null) {
          newSelected = updated;
        } else if (activeCategories.isNotEmpty) {
          AppLogger.d(
            '⚠️ [CatalogCubit] Categoria "${previousSelected.name}" ficou inativa. Resetando para a primeira.',
          );
          newSelected = activeCategories.first;
        }
      } else if (activeCategories.isNotEmpty) {
        newSelected = activeCategories.first;
        AppLogger.d(
          '⚙️ [CatalogCubit] Selecionando categoria padrão: ${newSelected.name}',
        );
      }

      AppLogger.d(
        '🚀 [CatalogCubit] Emitindo novo estado: ${activeCategories.length} categorias ativas, Selecionada: ${newSelected?.name}',
      );

      emit(
        state.copyWith(categories: categories, selectedCategory: newSelected),
      );
    });

    // Escuta atualizações de banners
    _bannersSub = _realtimeRepository.bannersController.listen((banners) {
      AppLogger.d('🎨 [CatalogCubit] ${banners.length} banners recebidos');
      emit(state.copyWith(banners: banners));
    });
  }

  final RealtimeRepository _realtimeRepository;
  late final StreamSubscription<List<Product>> _productsSub;
  late final StreamSubscription<List<Category>> _categoriesSub;
  late final StreamSubscription<List<BannerModel>> _bannersSub;

  /// Seleciona uma categoria manualmente (ação do usuário)
  void selectCategory(Category category) {
    if (state.selectedCategory?.id == category.id) return;
    AppLogger.d('👆 [CatalogCubit] Categoria selecionada: ${category.name}');
    emit(state.copyWith(selectedCategory: category));
  }

  /// Seleciona a primeira categoria ativa se nenhuma estiver selecionada
  void _maybeSelectDefaultCategory() {
    if (state.selectedCategory == null && state.activeCategories.isNotEmpty) {
      AppLogger.d(
        '⚙️ [CatalogCubit] Selecionando categoria padrão: ${state.activeCategories.first.name}',
      );
      emit(state.copyWith(selectedCategory: state.activeCategories.first));
    }
  }

  @override
  Future<void> close() {
    _productsSub.cancel();
    _categoriesSub.cancel();
    _bannersSub.cancel();
    return super.close();
  }
}
