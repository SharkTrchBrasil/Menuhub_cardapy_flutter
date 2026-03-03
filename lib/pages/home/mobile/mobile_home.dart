import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/cubit/catalog_state.dart';
import 'package:totem/themes/classic/mobile/home_body_mobile.dart';

/// Mobile Home Page
/// Implementação específica para dispositivos móveis
class MobileHome extends StatelessWidget {
  const MobileHome({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogCubit, CatalogState>(
      buildWhen: (previous, current) {
        // ✅ SMART REBUILD: Verifica se banners, categorias ATIVAS ou produtos mudaram
        final bool categoriesChanged =
            !const ListEquality().equals(
              previous.activeCategories,
              current.activeCategories,
            );
        final bool productsChanged =
            !const ListEquality().equals(previous.products, current.products);
        final bool selectedChanged =
            previous.selectedCategory?.id != current.selectedCategory?.id;
        final bool bannersChanged =
            !const ListEquality().equals(previous.banners, current.banners);

        return categoriesChanged ||
            productsChanged ||
            selectedChanged ||
            bannersChanged;
      },
      builder: (context, state) {
        final banners = state.banners ?? [];
        final categories = state.activeCategories;
        final products = state.products ?? [];
        final selectedCategory = state.selectedCategory;

        return HomeBodyMobile(
          banners: banners,
          categories: categories,
          products: products,
          selectedCategory: selectedCategory,
          onCategorySelected: (c) {
            if (c != null) {
              context.read<CatalogCubit>().selectCategory(c);
            }
          },
        );
      },
    );
  }
}
