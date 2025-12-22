// lib/pages/order/order_confirmation_page.dart
// ✅ Tela de confirmação de pedido - usa OrderDetailsPage reutilizável

import 'package:flutter/material.dart';
import 'package:totem/models/order.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/pages/order/order_details_page.dart';

/// Wrapper para a página de confirmação de pedido
/// Usa OrderDetailsPage internamente, mostrando ações e sem avaliação
class OrderConfirmationPage extends StatelessWidget {
  final Order? order;
  final PlatformPaymentMethod? paymentMethod;

  const OrderConfirmationPage({
    super.key,
    this.order,
    this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    // Se tiver order, exibe a página de detalhes
    if (order != null) {
      return OrderDetailsPage(
        order: order!,
        paymentMethod: paymentMethod,
        showActions: true,  // Mostra footer com "Ver sacola"
        showRating: false,  // Não mostra avaliação (pedido acabou de ser feito)
      );
    }
    
    // Fallback para quando não tiver order
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Pedido realizado com sucesso!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Seu pedido já está sendo preparado.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
