import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/cubit/orders_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/services/urgent_notification_service.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

import '../home/home_tab_page_adaptive.dart';
import '../orders/orders_tab_page_adaptive.dart';
import '../profile/profile_tab_page_adaptive.dart';
import 'main_tab_controller.dart';

/// Página principal com sistema de tabs usando IndexedStack
/// Mantém estado de todas as tabs para performance otimizada
class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  late final MainTabController _tabController;
  int _selectedIndex = 0;

  // Usa IndexedStack para manter estado de todas as tabs
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabController = MainTabController();
    _tabController.addListener(_onTabChanged);

    // ✅ CORREÇÃO: 3 tabs: Home, Pedidos, Perfil (removido Notificações e Cardápio)
    _tabs = [
      const HomeTabPageAdaptive(key: PageStorageKey('home_tab')),
      const OrdersTabPageAdaptive(key: PageStorageKey('orders_tab')),
      const ProfileTabPageAdaptive(key: PageStorageKey('profile_tab')),
    ];
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // ✅ Força atualização mesmo se o índice for o mesmo
    // Isso garante que após limpar carrinho, a navegação continue funcionando
    if (mounted) {
      setState(() {
        _selectedIndex = _tabController.currentIndex;
      });
    }
  }

  void _onTabTapped(int index) {
    // ✅ Sempre chama changeTab, mesmo se for a mesma tab
    // Isso garante sincronização do estado após operações como clearCart
    _tabController.changeTab(index);

    // ✅ Força atualização imediata do estado local
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    // Mobile: usa tabs com IndexedStack
    // Desktop: não deve usar este widget (usa rotas)
    return MultiBlocProvider(
      providers: [ChangeNotifierProvider.value(value: _tabController)],
      child: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            UrgentNotificationService().setContext(context);
          });

          return Scaffold(
            body: IndexedStack(index: _selectedIndex, children: _tabs),
            bottomNavigationBar: _buildBottomNavigationBar(context, theme),
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                icon: EvaIcons.homeOutline,
                activeIcon: EvaIcons.home,
                label: 'Início',
                index: 0,
              ),
              _buildNavItem(
                context,
                icon: EvaIcons.shoppingBagOutline,
                activeIcon: EvaIcons.shoppingBag,
                label: 'Pedidos',
                index: 1,
              ),
              _buildNavItem(
                context,
                icon: EvaIcons.personOutline,
                activeIcon: EvaIcons.person,
                label: 'Perfil',
                index: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    Widget? badge,
  }) {
    final isSelected = _selectedIndex == index;
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          // ✅ Força navegação mesmo se já estiver na mesma tab
          // Isso resolve o bug onde o home não funciona após limpar carrinho
          _onTabTapped(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? theme.primaryColor : Colors.grey.shade600,
                  size: 24,
                ),
                if (badge != null) Positioned(right: -8, top: -4, child: badge),
              ],
            ),
            const SizedBox(height: 3),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.primaryColor : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNavigation(BuildContext context, theme) {
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
                index: 0,
              ),
              const SizedBox(height: 16),
              _buildDesktopNavItem(
                context,
                icon: EvaIcons.shoppingBagOutline,
                activeIcon: EvaIcons.shoppingBag,
                label: 'Pedidos',
                index: 1,
              ),
              const SizedBox(height: 16),
              _buildDesktopNavItem(
                context,
                icon: EvaIcons.personOutline,
                activeIcon: EvaIcons.person,
                label: 'Perfil',
                index: 2,
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
    required int index,
    Widget? badge,
  }) {
    final isSelected = _selectedIndex == index;
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? theme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border:
                isSelected
                    ? Border.all(color: theme.primaryColor, width: 2)
                    : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? theme.primaryColor : Colors.grey.shade600,
                size: 28,
              ),
              if (badge != null) Positioned(right: 4, top: 4, child: badge),
            ],
          ),
        ),
      ),
    );
  }
}
