import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/cart/mobile/mobile_cart.dart';
import 'package:totem/pages/cart/desktop/desktop_cart.dart';

/// Entry point adaptativo para a página de Carrinho
/// Escolhe automaticamente entre mobile e desktop
class CartTabPageAdaptive extends StatelessWidget {
  const CartTabPageAdaptive({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobileBuilder: (context, constraints) => const MobileCart(),
      tabletBuilder: (context, constraints) => const MobileCart(),
      desktopBuilder: (context, constraints) => const DesktopCart(),
    );
  }
}
