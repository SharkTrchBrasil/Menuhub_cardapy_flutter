import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/orders/mobile/mobile_orders.dart';
import 'package:totem/pages/orders/desktop/desktop_orders.dart';

/// Entry point adaptativo para a página de Pedidos
/// Escolhe automaticamente entre mobile e desktop
class OrdersTabPageAdaptive extends StatelessWidget {
  const OrdersTabPageAdaptive({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobileBuilder: (context, constraints) => const MobileOrders(),
      tabletBuilder: (context, constraints) => const MobileOrders(),
      desktopBuilder: (context, constraints) => const DesktopOrders(),
    );
  }
}
