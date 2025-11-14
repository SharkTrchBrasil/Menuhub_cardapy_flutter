import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

/// Navegação Desktop usando rotas GoRouter
class DesktopNavigation extends StatelessWidget {
  const DesktopNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final currentLocation = GoRouterState.of(context).uri.path;

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 80,
      child: Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildDesktopNavItem(
                context,
                icon: EvaIcons.homeOutline,
                activeIcon: EvaIcons.home,
                label: 'Home',
                route: '/',
                isActive: currentLocation == '/',
              ),
              const SizedBox(height: 16),
              _buildDesktopNavItem(
                context,
                icon: EvaIcons.shoppingBagOutline,
                activeIcon: EvaIcons.shoppingBag,
                label: 'Carrinho',
                route: '/cart',
                isActive: currentLocation == '/cart',
                badge: _buildCartBadge(context),
              ),
              const SizedBox(height: 16),
              _buildDesktopNavItem(
                context,
                icon: EvaIcons.fileTextOutline,
                activeIcon: EvaIcons.fileText,
                label: 'Pedidos',
                route: '/orders/history',
                isActive: currentLocation == '/orders/history',
              ),
              const SizedBox(height: 16),
              _buildDesktopNavItem(
                context,
                icon: EvaIcons.personOutline,
                activeIcon: EvaIcons.person,
                label: 'Perfil',
                route: '/profile',
                isActive: currentLocation == '/profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isActive,
    Widget? badge,
  }) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => context.go(route),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? theme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: theme.primaryColor, width: 2)
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? theme.primaryColor
                    : Colors.grey.shade600,
                size: 28,
              ),
              if (badge != null)
                Positioned(
                  right: 4,
                  top: 4,
                  child: badge,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildCartBadge(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      buildWhen: (previous, current) =>
          previous.cart.items.length != current.cart.items.length,
      builder: (context, state) {
        final itemCount = state.cart.items.length;
        if (itemCount == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          constraints: const BoxConstraints(
            minWidth: 16,
            minHeight: 16,
          ),
          child: Text(
            itemCount > 99 ? '99+' : '$itemCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

