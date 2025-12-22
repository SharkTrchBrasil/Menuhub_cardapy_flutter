import 'package:flutter/material.dart';
import 'package:totem/pages/orders/widgets/orders_content.dart';

/// Desktop Orders Page
/// Implementação específica para desktop
/// Usa o OrdersCubit global que é carregado após o login
class DesktopOrders extends StatelessWidget {
  const DesktopOrders({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Usa o OrdersCubit global (carregado após login)
    // Não precisa mais criar um ProfileCubit local
    return const OrdersContent(isDesktop: true);
  }
}
