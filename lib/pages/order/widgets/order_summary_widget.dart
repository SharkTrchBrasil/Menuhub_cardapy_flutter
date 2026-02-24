// lib/pages/order/widgets/order_summary_widget.dart
// ✅ Widget Resumo de valores - Estilo Menuhub
// Subtotal, taxa de entrega, taxa de serviço, total

import 'package:flutter/material.dart';

class OrderSummaryWidget extends StatelessWidget {
  final int subtotalCents;
  final int deliveryFeeCents;
  final int serviceFeeCents;
  final int discountCents;
  final int totalCents;
  final VoidCallback? onAddToCart;

  const OrderSummaryWidget({
    super.key,
    required this.subtotalCents,
    this.deliveryFeeCents = 0,
    this.serviceFeeCents = 0,
    this.discountCents = 0,
    required this.totalCents,
    this.onAddToCart,
  });

  String _formatPrice(int cents) {
    final value = cents / 100.0;
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          const Text(
            'Resumo de valores',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Subtotal
          _buildValueRow('Subtotal', _formatPrice(subtotalCents)),
          
          // Taxa de entrega
          _buildValueRow(
            'Taxa de entrega',
            deliveryFeeCents == 0 ? 'Grátis' : _formatPrice(deliveryFeeCents),
            valueColor: deliveryFeeCents == 0 ? Colors.green : null,
          ),
          
          // Taxa de serviço (se houver)
          if (serviceFeeCents > 0)
            _buildValueRow(
              'Taxa de serviço',
              _formatPrice(serviceFeeCents),
              hasInfo: true,
            ),
          
          // Desconto (se houver)
          if (discountCents > 0)
            _buildValueRow(
              'Desconto',
              '- ${_formatPrice(discountCents)}',
              valueColor: Colors.green,
            ),
          
          const SizedBox(height: 8),
          
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatPrice(totalCents),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // Botão "Adicionar à sacola" (para pedir novamente)
          if (onAddToCart != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onAddToCart,
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text('Pedir novamente'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValueRow(String label, String value, {Color? valueColor, bool hasInfo = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              if (hasInfo) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.help_outline,
                  size: 16,
                  color: Colors.grey[500],
                ),
              ],
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? Colors.grey[800],
              fontWeight: valueColor != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
