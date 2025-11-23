import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/menu/mobile/mobile_menu.dart';
import 'package:totem/pages/menu/desktop/desktop_menu.dart';

/// Entry point adaptativo para a página de Menu
/// Escolhe automaticamente entre mobile e desktop
class MenuTabPageAdaptive extends StatelessWidget {
  const MenuTabPageAdaptive({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobileBuilder: (context, constraints) => const MobileMenu(),
      tabletBuilder: (context, constraints) => const MobileMenu(),
      desktopBuilder: (context, constraints) => const DesktopMenu(),
    );
  }
}
