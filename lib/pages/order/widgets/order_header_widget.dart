// lib/pages/order/widgets/order_header_widget.dart
// ✅ Widget Header do pedido - Estilo iFood
// Logo da loja, nome do cliente, número do pedido, data, link ver cardápio

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrderHeaderWidget extends StatelessWidget {
  final String? storeLogo;
  final String storeName;
  final String customerName;
  final String orderNumber;
  final DateTime orderDate;
  final VoidCallback? onViewMenu;

  const OrderHeaderWidget({
    super.key,
    this.storeLogo,
    required this.storeName,
    required this.customerName,
    required this.orderNumber,
    required this.orderDate,
    this.onViewMenu,
  });

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year às $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo da loja circular com borda amarela (estilo iFood)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: storeLogo != null && storeLogo!.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: storeLogo!,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.store,
                        color: Colors.grey[400],
                        size: 28,
                      ),
                    ),
                  )
                : Icon(Icons.store, color: Colors.grey[400], size: 28),
          ),
          const SizedBox(width: 12),
          // Informações do pedido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome do cliente (destaque principal)
                Text(
                  customerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Número do pedido e data
                Text(
                  'Pedido nº $orderNumber • ${_formatDate(orderDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                // Link "Ver cardápio"
                if (onViewMenu != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onViewMenu,
                    child: Text(
                      'Ver cardápio',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
