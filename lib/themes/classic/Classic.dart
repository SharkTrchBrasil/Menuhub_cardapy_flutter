import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/themes/classic/desktop/home_body_desktop.dart';



import '../../core/responsive_builder.dart';
import '../../cubit/store_state.dart';
import '../../helpers/constants.dart';


import '../../pages/cart/cart_cubit.dart';

import '../../cubit/store_cubit.dart';



import '../../pages/cart/cart_state.dart';
import 'mobile/home_body_mobile.dart';

import '../ds_theme.dart';
import '../ds_theme_switcher.dart';


class ClassicTheme extends StatefulWidget {
  const ClassicTheme({super.key});

  @override
  State<ClassicTheme> createState() => _ClassicThemeState();
}

class _ClassicThemeState extends State<ClassicTheme> {
  final GlobalKey<ScaffoldState> _key = GlobalKey();
  bool isCartExpanded = false;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    final categoryLayout = DsCategoryLayout.fromString(
      theme.categoryLayout.name,
    );

    final productLayout = DsProductLayout.fromString(theme.productLayout.name);

    return BlocBuilder<StoreCubit, StoreState>(
      builder: (_, state) {
        final banners = state.banners ?? [];

        return Scaffold(
          key: _key,

          // --- BOTTOM NAVIGATION BAR ---
          bottomNavigationBar:
              ResponsiveBuilder.isMobile(context)
                  ? BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    currentIndex: _selectedIndex,
                    onTap: (index) {
                      setState(() {
                        _selectedIndex = index;

                        if (index == 2) {
                          context.go('/cart');
                        }
                      });
                    },
                    items: <BottomNavigationBarItem>[
                      const BottomNavigationBarItem(
                        icon: Icon(EvaIcons.homeOutline),
                        label: 'Home',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(EvaIcons.gridOutline),
                        label: 'Categorias',
                      ),
                      BottomNavigationBarItem(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(EvaIcons.shoppingBagOutline),
                            // Badge de contador de itens no carrinho
                            Positioned(
                              right: -6,
                              top: -3,
                              child: BlocBuilder<CartCubit, CartState>(
                                builder: (context, state) {
                                  if (state.cart.items == 0)
                                    return const SizedBox(); // Esconde se vazio

                                  return Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 14,
                                      minHeight: 14,
                                    ),
                                    child: Text(
                                      '${state.cart.items.length}',
                                      // Mostra a quantidade real
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        label: 'Sacola',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(EvaIcons.personOutline),
                        label: 'Perfil',
                      ),
                    ],
                  )
                  : null,

          body: ResponsiveBuilder(
            mobileBuilder: (context, constraints) {
              return HomeBodyMobile(
                banners: state.banners ?? [],
                categories: state.categories ?? [],
                products: state.products ?? [],
                selectedCategory: state.selectedCategory,

                onCategorySelected: (c) {
                  context.read<StoreCubit>().selectCategory(c!);
                  // Adicione qualquer lógica adicional necessária aqui
                },
              );
            },
            tabletBuilder: (context, constraints) {
              return
              HomeBodyMobile(
                banners: state.banners ?? [],
                categories: state.categories ?? [],
                products: state.products ?? [],

                onCategorySelected: (c) {
                  context.read<StoreCubit>().selectCategory(c!);
                  // Adicione qualquer lógica adicional necessária aqui
                }, selectedCategory: null,
              );
            },
            desktopBuilder: (context, constraints) {



              return HomeBodyDesktop(
                banners: state.banners ?? [],
                categories: state.categories ?? [],
                products: state.products ?? [],
                selectedCategory: state.selectedCategory,

                onCategorySelected: (c) {
                  context.read<StoreCubit>().selectCategory(c!);
                  // Adicione qualquer lógica adicional necessária aqui
                }, store: state.store,
              );
            },
          ),
        );
      },
    );
  }

  void _showCartModalBottomSheet(DsTheme theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Mantém como true para flexibilidade
      backgroundColor: theme.cartBackgroundColor,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      shape: OutlineInputBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        borderSide: BorderSide(color: theme.backgroundColor),
      ),

      builder: (BuildContext ctx) {
        return ConstrainedBox(
          // Adicione um ConstrainedBox aqui
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(ctx).size.height *
                0.85, // Exemplo: 75% da altura da tela
            // Ou uma altura fixa: height: 500.0,
          ),
        );
      },
    );
  }
}
