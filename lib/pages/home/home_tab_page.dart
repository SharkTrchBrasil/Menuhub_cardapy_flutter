import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/themes/classic/desktop/home_body_desktop.dart';
import 'package:totem/themes/classic/mobile/home_body_mobile.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/cubit/catalog_state.dart';
import 'package:totem/main.dart' show homeReadySignal;

/// Home Tab Page - Otimizada para funcionar como tab
/// Usa ResponsiveBuilder para adaptar mobile/desktop
///
/// ✅ CORREÇÃO: homeReadySignal só dispara quando dados estão prontos
class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  @override
  void initState() {
    super.initState();
    // ✅ Verifica se os dados já estão disponíveis no primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSignalReady();
    });
  }

  /// ✅ Verifica se CatalogCubit + StoreCubit já possuem dados
  /// e só então sinaliza homeReady para o overlay fazer fade-out.
  void _checkAndSignalReady() {
    if (!mounted || homeReadySignal.value) return;

    final catalogState = context.read<CatalogCubit>().state;
    final storeState = context.read<StoreCubit>().state;

    final hasProducts =
        catalogState.products != null && catalogState.products!.isNotEmpty;
    final hasStore = storeState.store != null;

    if (hasProducts && hasStore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !homeReadySignal.value) {
          print('✅ [HomeTabPage] Dados prontos! Sinalizando homeReady.');
          homeReadySignal.value = true;
        }
      });
    }
  }

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
