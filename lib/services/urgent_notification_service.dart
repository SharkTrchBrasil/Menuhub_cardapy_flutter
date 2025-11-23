// lib/services/urgent_notification_service.dart

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:totem/models/notification.dart';
import 'package:totem/repositories/notification_repository.dart';
import '../core/di.dart';

class UrgentNotificationService {
  static final UrgentNotificationService _instance = UrgentNotificationService._internal();
  factory UrgentNotificationService() => _instance;
  UrgentNotificationService._internal();

  final NotificationRepository _notificationRepository = getIt<NotificationRepository>();
  
  // Fila de notificações urgentes pendentes
  final List<NotificationItem> _pendingNotifications = [];
  bool _isShowingDialog = false;
  BuildContext? _currentContext;

  /// Processa notificações urgentes recebidas via socket
  void processUrgentNotifications(List<NotificationItem> notifications) {
    _pendingNotifications.addAll(notifications);
    _showNextNotification();
  }

  /// Mostra a próxima notificação urgente da fila
  Future<void> _showNextNotification() async {
    if (_isShowingDialog || _pendingNotifications.isEmpty || _currentContext == null) {
      return;
    }

    final context = _currentContext!;
    if (!context.mounted) {
      return;
    }

    _isShowingDialog = true;
    final notification = _pendingNotifications.removeAt(0);

    await showDialog(
      context: context,
      barrierDismissible: false, // Não permite fechar clicando fora
      builder: (BuildContext dialogContext) {
        return _UrgentNotificationDialog(
          notification: notification,
          onView: () async {
            // Marca como lida
            await _notificationRepository.markAsRead(notification.id);
            
            // Fecha o dialog
            Navigator.of(dialogContext).pop();
            _isShowingDialog = false;
            
            // Mostra próxima notificação
            _showNextNotification();
          },
        );
      },
    );
  }

  /// Define o contexto para mostrar os dialogs
  void setContext(BuildContext context) {
    _currentContext = context;
    _showNextNotification();
  }

  /// Remove o contexto
  void clearContext() {
    _currentContext = null;
  }
}

/// Widget de dialog para exibir notificação urgente
class _UrgentNotificationDialog extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onView;

  const _UrgentNotificationDialog({
    required this.notification,
    required this.onView,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getIcon(String? icon) {
    if (icon == null) return Icons.warning_rounded;
    
    // Se for emoji, retorna ícone padrão
    if (icon.length > 2) return Icons.warning_rounded;
    
    // Tenta mapear tipos de notificação para ícones
    switch (notification.notificationType.toUpperCase()) {
      case 'LOW_STOCK':
        return Icons.inventory_2_rounded;
      case 'UPCOMING_HOLIDAY':
        return Icons.celebration_rounded;
      case 'UPCOMING_PAYABLE':
        return Icons.payment_rounded;
      case 'PENDING_ORDER':
        return Icons.shopping_bag_rounded;
      case 'LOW_MOVER':
        return Icons.trending_down_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor(notification.priority);
    final icon = _getIcon(notification.icon);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com ícone e título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: priorityColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          notification.priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: priorityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Mensagem
            Text(
              notification.message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            // Botão de ação
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onView,
                style: ElevatedButton.styleFrom(
                  backgroundColor: priorityColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Visualizar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

