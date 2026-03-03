import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/cubit/catalog_state.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/themes/classic/desktop/home_body_desktop.dart';
import 'package:totem/widgets/desktop_app_bar.dart';

/// Wrapper para HomeBodyDesktop com o novo AppBar
class DesktopHomeWithAppBar extends StatefulWidget {
  const DesktopHomeWithAppBar({super.key});

  @override
  State<DesktopHomeWithAppBar> createState() => _DesktopHomeWithAppBarState();
}

class _DesktopHomeWithAppBarState extends State<DesktopHomeWithAppBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Acompanha a loja para re-build se status mudar
    final store = context.watch<StoreCubit>().state.store;

    return BlocBuilder<CatalogCubit, CatalogState>(
      buildWhen:
          (previous, current) =>
              previous.products != current.products ||
              previous.categories != current.categories ||
              previous.selectedCategory != current.selectedCategory,
      builder: (context, state) {
        final banners = state.banners ?? [];
        final categories = state.activeCategories;
        final products = state.products ?? [];
        final selectedCategory = state.selectedCategory;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: DesktopAppBar(
            searchController: _searchController,
            onSearchChanged: () {
              // Aqui você pode implementar a lógica de filtro de busca
              setState(() {});
            },
          ),
          body: HomeBodyDesktop(
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
          ),
        );
      },
    );
  }
}
