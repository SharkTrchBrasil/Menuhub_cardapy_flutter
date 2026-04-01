// lib/pages/order/widgets/order_status_badge.dart
// ✅ Widget Status do pedido - Estilo Menuhub
// Badge com ícone e mensagem contextual

import 'package:flutter/material.dart';

class OrderStatusBadge extends StatelessWidget {
  final String status;
  final DateTime? completedAt;
  final String? cancelReason;

  const OrderStatusBadge({
    super.key,
    required this.status,
    this.completedAt,
    this.cancelReason,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusInfo['bgColor'] as Color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone do status
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: statusInfo['iconBgColor'] as Color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusInfo['icon'] as IconData,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          // Mensagem do status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusInfo['message'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: statusInfo['textColor'] as Color,
                    height: 1.4,
                  ),
                ),
                if (statusInfo['submessage'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    statusInfo['submessage'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: (statusInfo['textColor'] as Color).withValues(
                        alpha: 0.8,
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

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return {
          'icon': Icons.access_time,
          'iconBgColor': Colors.orange,
          'bgColor': Colors.orange.shade50,
          'textColor': Colors.orange.shade900,
          'message': 'Aguardando confirmação da loja.',
          'submessage': 'Você será notificado quando o pedido for aceito.',
        };
      case 'confirmed':
        return {
          'icon': Icons.check,
          'iconBgColor': Colors.blue,
          'bgColor': Colors.blue.shade50,
          'textColor': Colors.blue.shade900,
          'message': 'Pedido confirmado!',
          'submessage': 'A loja começará a preparar em breve.',
        };
      case 'preparing':
        return {
          'icon': Icons.restaurant,
          'iconBgColor': Colors.purple,
          'bgColor': Colors.purple.shade50,
          'textColor': Colors.purple.shade900,
          'message': 'Seu pedido está sendo preparado.',
          'submessage': null,
        };
      case 'ready':
        return {
          'icon': Icons.check_circle,
          'iconBgColor': Colors.cyan,
          'bgColor': Colors.cyan.shade50,
          'textColor': Colors.cyan.shade900,
          'message': 'Pedido pronto!',
          'submessage': 'Aguardando entregador ou retirada.',
        };
      case 'dispatched':
      case 'out_for_delivery':
        return {
          'icon': Icons.delivery_dining,
          'iconBgColor': Colors.indigo,
          'bgColor': Colors.indigo.shade50,
          'textColor': Colors.indigo.shade900,
          'message': 'Seu pedido saiu para entrega!',
          'submessage': 'O entregador está a caminho.',
        };
      case 'delivered':
      case 'finalized':
      case 'concluded':
        return {
          'icon': Icons.check_circle,
          'iconBgColor': Colors.green,
          'bgColor': Colors.green.shade50,
          'textColor': Colors.green.shade900,
          'message': 'Pedido entregue com sucesso!',
          'submessage':
              completedAt != null
                  ? 'Entregue às ${_formatTime(completedAt!)}'
                  : null,
        };
      case 'canceled':
      case 'cancelled':
        return {
          'icon': Icons.close,
          'iconBgColor': Colors.grey.shade600,
          'bgColor': Colors.grey.shade100,
          'textColor': Colors.grey.shade800,
          'message':
              'A loja não confirmou seu pedido e ele foi cancelado. Nenhuma cobrança será feita.',
          'submessage': 'Que tal fazer um novo pedido?',
        };
      default:
        return {
          'icon': Icons.info_outline,
          'iconBgColor': Colors.grey,
          'bgColor': Colors.grey.shade100,
          'textColor': Colors.grey.shade800,
          'message': 'Processando...',
          'submessage': null,
        };
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
