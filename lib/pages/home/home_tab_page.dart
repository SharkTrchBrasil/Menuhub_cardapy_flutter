import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/themes/classic/desktop/home_body_desktop.dart';
import 'package:totem/themes/classic/mobile/home_body_mobile.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/cubit/catalog_state.dart';

/// Home Tab Page - Otimizada para funcionar como tab
/// Usa ResponsiveBuilder para adaptar mobile/desktop
class HomeTabPage extends StatelessWidget {
  const HomeTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Acompanha a loja para re-build se status mudar (aberto/fechado)
    final storeState = context.watch<StoreCubit>().state;
    final store = storeState.store;

    return BlocBuilder<CatalogCubit, CatalogState>(
      buildWhen:
          (previous, current) =>
              previous.products != current.products ||
              previous.categories != current.categories ||
              previous.selectedCategory != current.selectedCategory,
      builder: (context, state) {
        final banners = state.banners ?? [];
        final categories = state.activeCategories; // Usa apenas as ativas
        final products = state.products ?? [];
        final selectedCategory = state.selectedCategory;

        return ResponsiveBuilder(
          mobileBuilder: (context, constraints) {
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
          tabletBuilder: (context, constraints) {
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
          desktopBuilder: (context, constraints) {
            return HomeBodyDesktop(
              store: store,
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
      },
    );
  }
}
