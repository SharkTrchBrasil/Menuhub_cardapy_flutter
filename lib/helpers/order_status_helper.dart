// lib/helpers/order_status_helper.dart
// Helper centralizado para funções de status de pedido

import 'package:flutter/material.dart';

/// Retorna o label formatado do status do pedido
String getOrderStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Pendente';
    case 'confirmed':
      return 'Confirmado';
    case 'preparing':
      return 'Em preparo';
    case 'ready':
      return 'Pronto para entrega';
    case 'dispatched':
    case 'on_route':
    case 'out_for_delivery':
      return 'Em entrega';
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return 'Finalizado';
    case 'canceled':
    case 'cancelled':
      return 'Cancelado';
    default:
      return status;
  }
}

/// Retorna a cor correspondente ao status
Color getOrderStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange;
    case 'confirmed':
      return Colors.blue;
    case 'preparing':
      return Colors.purple;
    case 'ready':
      return Colors.cyan;
    case 'dispatched':
    case 'on_route':
    case 'out_for_delivery':
      return Colors.indigo;
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return Colors.green;
    case 'canceled':
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

/// Retorna o ícone correspondente ao status
IconData getOrderStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'canceled':
    case 'cancelled':
      return Icons.cancel;
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return Icons.check_circle;
    case 'dispatched':
    case 'on_route':
    case 'out_for_delivery':
      return Icons.delivery_dining;
    case 'preparing':
      return Icons.restaurant;
    case 'ready':
      return Icons.check_circle_outline;
    case 'confirmed':
      return Icons.check;
    case 'pending':
      return Icons.access_time;
    default:
      return Icons.info_outline;
  }
}

/// Retorna o valor de progresso (0.0 a 1.0) para a barra de progresso
double getOrderProgressValue(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 0.15;
    case 'confirmed':
      return 0.30;
    case 'preparing':
      return 0.50;
    case 'ready':
      return 0.75;
    case 'dispatched':
    case 'on_route':
    case 'out_for_delivery':
      return 0.90;
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return 1.0;
    case 'canceled':
    case 'cancelled':
      return 0.0;
    default:
      return 0.15;
  }
}
