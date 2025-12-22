import 'package:flutter/material.dart';
import 'package:totem/pages/orders/widgets/orders_content.dart';

/// Mobile Orders Page
/// Implementação específica para dispositivos móveis
/// Usa o OrdersCubit global que é carregado após o login
class MobileOrders extends StatelessWidget {
  const MobileOrders({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Usa o OrdersCubit global (carregado após login)
    // Não precisa mais criar um ProfileCubit local
    return const OrdersContent(isDesktop: false);
  }
}
