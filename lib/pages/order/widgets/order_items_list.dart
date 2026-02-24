// lib/pages/order/widgets/order_items_list.dart
// ✅ Widget Lista de itens do pedido - Estilo Menuhub
// Imagem com badge de quantidade, nome, opções indentadas, preço

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/models/order.dart';

class OrderItemsList extends StatelessWidget {
  final List<BagItem> items;

  const OrderItemsList({
    super.key,
    required this.items,
  });

  String _formatPrice(int cents) {
    final value = cents / 100.0;
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => _buildItemRow(context, item)).toList(),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, BagItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem com badge de quantidade
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Imagem do produto
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: item.logoUrl != null && item.logoUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: item.logoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Icon(
                            Icons.restaurant,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.restaurant,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.restaurant,
                        color: Colors.grey[400],
                        size: 24,
                      ),
              ),
              // Badge de quantidade (vermelho no canto)
              Positioned(
                bottom: -4,
                left: -4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Nome e opções
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome do produto
                Text(
                  item.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Sub-itens / Opções
                if (item.subItems.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...item.subItems.map((subItem) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quantidade do sub-item em box
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${subItem.quantity}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Nome do sub-item
                        Expanded(
                          child: Text(
                            subItem.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
                // Observações
                if (item.hasNotes) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Preço
          Text(
            _formatPrice(item.totalPrice),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
