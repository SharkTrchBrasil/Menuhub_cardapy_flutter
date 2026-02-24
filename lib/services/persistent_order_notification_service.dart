// lib/services/persistent_order_notification_service.dart
// ✅ Serviço para exibir notificação persistente do pedido ativo
// Similar ao iFood, mostra banner fixo no topo da tela com status do pedido

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/order.dart';

class PersistentOrderNotificationService {
  static final PersistentOrderNotificationService _instance = 
      PersistentOrderNotificationService._internal();
  factory PersistentOrderNotificationService() => _instance;
  PersistentOrderNotificationService._internal();

  BuildContext? _currentContext;
  OverlayEntry? _overlayEntry;
  Order? _currentActiveOrder;

  /// Define o contexto do app para criar overlays
  void setContext(BuildContext context) {
    _currentContext = context;
  }

  /// Mostra a notificação persistente para um pedido ativo
  void showNotification(Order order) {
    if (_currentContext == null) return;
    if (_overlayEntry != null) {
      // Atualiza o pedido existente
      _currentActiveOrder = order;
      _updateOverlay();
      return;
    }

    _currentActiveOrder = order;
    _createOverlay();
  }

  /// Remove a notificação persistente
  void hideNotification() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _currentActiveOrder = null;
    }
  }

  /// Atualiza a notificação existente
  void updateNotification(Order? order) {
    if (order == null || !order.isActive) {
      hideNotification();
      return;
    }

    if (_overlayEntry == null) {
      showNotification(order);
    } else {
      _currentActiveOrder = order;
      _updateOverlay();
    }
  }

  /// Cria o overlay da notificação
  void _createOverlay() {
    if (_currentContext == null || _currentActiveOrder == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _PersistentOrderNotificationWidget(
        order: _currentActiveOrder!,
        onDismiss: hideNotification,
      ),
    );

    Overlay.of(_currentContext!).insert(_overlayEntry!);
  }

  /// Atualiza o overlay existente
  void _updateOverlay() {
    if (_currentContext == null || _currentActiveOrder == null) return;
    
    _overlayEntry?.markNeedsBuild();
  }

  /// Verifica se há notificação ativa
  bool get isShowing => _overlayEntry != null;
}

/// Widget da notificação persistente
class _PersistentOrderNotificationWidget extends StatelessWidget {
  final Order order;
  final VoidCallback onDismiss;

  const _PersistentOrderNotificationWidget({
    required this.order,
    required this.onDismiss,
  });

  /// Retorna informações do status para exibição
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'CONFIRMED':
        return {
          'text': 'Aguardando confirmação da loja',
          'color': Colors.orange,
          'icon': Icons.schedule,
        };
      case 'PREPARING':
        return {
          'text': 'Pedido sendo preparado',
          'color': Colors.blue,
          'icon': Icons.restaurant,
        };
      case 'READY':
        return {
          'text': 'Pedido pronto!',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'DISPATCHED':
        return {
          'text': 'Pedido saiu para entrega',
          'color': Colors.purple,
          'icon': Icons.delivery_dining,
        };
      default:
        return {
          'text': 'Processando pedido',
          'color': Colors.grey,
          'icon': Icons.info,
        };
    }
  }

  /// Calcula previsão de entrega
  String _getEstimatedTime() {
    final eta = order.delivery?.estimatedTimeOfArrival;
    if (eta == null || order.delivery == null) {
      final now = DateTime.now();
      final min = now.add(const Duration(minutes: 30));
      final max = now.add(const Duration(minutes: 45));
      return '${min.hour}:${min.minute.toString().padLeft(2, '0')} - ${max.hour}:${max.minute.toString().padLeft(2, '0')}';
    }

    final start = eta.deliversAt;
    final end = eta.deliversEndAt ?? start.add(const Duration(minutes: 10));
    
    final startStr = '${start.hour}:${start.minute.toString().padLeft(2, '0')}';
    final endStr = '${end.hour}:${end.minute.toString().padLeft(2, '0')}';
    
    return '$startStr - $endStr';
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(order.lastStatus);
    final theme = Theme.of(context);
    final isDelivery = order.isDelivery;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                // ✅ Navegar para tela de detalhes do pedido usando go_router
                // A rota /order/:id espera o Order via extra
                context.push('/order/${order.id}', extra: order);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Ícone de status
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (statusInfo['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusInfo['icon'] as IconData,
                            color: statusInfo['color'] as Color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Texto do status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusInfo['text'] as String,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDelivery
                                    ? 'Previsão de entrega: ${_getEstimatedTime()}'
                                    : 'Previsão para retirada: ${_getEstimatedTime()}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Botão fechar
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: onDismiss,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Barra de progresso
                    _buildProgressBar(context, statusInfo['color'] as Color),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Barra de progresso do pedido
  Widget _buildProgressBar(BuildContext context, Color color) {
    final statuses = order.isDelivery
        ? ['PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'DISPATCHED']
        : ['PENDING', 'CONFIRMED', 'PREPARING', 'READY'];
    
    final currentStatus = order.lastStatus.toUpperCase();
    final currentIndex = statuses.indexOf(currentStatus);
    final progress = currentIndex < 0 ? 0.0 : (currentIndex + 1) / statuses.length.toDouble();

    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress as double,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}