import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/themes/classic/mobile/home_body_mobile.dart';

/// Mobile Home Page
/// Implementação específica para dispositivos móveis
class MobileHome extends StatelessWidget {
  const MobileHome({super.key});

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
    );
  }
}
