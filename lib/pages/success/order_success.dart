// lib/pages/order/order_confirmation_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/order.dart';

class OrderConfirmationPage extends StatelessWidget {
  final Order? order;

  const OrderConfirmationPage({super.key, this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        // Remove o botão de voltar padrão
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícone de sucesso
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

              // Título principal
              Text(
                'Pedido realizado com sucesso!',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Mensagem de subtítulo com o número do pedido
              if (order != null)
                Text(
                  'Seu pedido #${order!.id.toString().padLeft(4, '0')} já está sendo preparado e logo sairá para entrega.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                )
              else
                Text(
                  'Seu pedido já está sendo preparado e logo sairá para entrega.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),

              const Spacer(), // Ocupa o espaço para empurrar os botões para baixo

              // Botão principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // No futuro, pode levar para uma tela de rastreio: context.go('/order/${order.id}')
                  onPressed: () => context.go('/'),
                  child: const Text('Acompanhar pedido'),
                ),
              ),
              const SizedBox(height: 12),

              // Botão secundário
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => context.go('/'),
                  child: const Text(
                    'Voltar para o início',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), // Espaço extra na parte inferior
            ],
          ),
        ),
      ),
    );
  }
}