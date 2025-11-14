import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/themes/classic/desktop/home_body_desktop.dart';
import 'package:totem/themes/classic/mobile/home_body_mobile.dart';

import '../../cubit/store_state.dart';

/// Home Page Simples - Sem sistema de temas
/// Usa HomeBodyMobile para mobile e HomeBodyDesktop para desktop
class SimpleHomePage extends StatelessWidget {
  const SimpleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, StoreState>(
      buildWhen: (previous, current) =>
          previous.products != current.products ||
          previous.categories != current.categories ||
          previous.selectedCategory != current.selectedCategory,
      builder: (context, state) {
        final banners = state.banners ?? [];
        final categories = state.categories ?? [];
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
                  context.read<StoreCubit>().selectCategory(c);
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
                  context.read<StoreCubit>().selectCategory(c);
                }
              },
            );
          },
          desktopBuilder: (context, constraints) {
            return HomeBodyDesktop(
              store: state.store,
              banners: banners,
              categories: categories,
              products: products,
              selectedCategory: selectedCategory,
              onCategorySelected: (c) {
                if (c != null) {
                  context.read<StoreCubit>().selectCategory(c);
                }
              },
            );
          },
        );
      },
    );
  }
}

