import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/models/notification.dart';
import 'package:totem/pages/notifications/notifications_cubit.dart';
import 'package:totem/pages/notifications/notifications_state.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

/// Notifications Tab Page - Página de notificações do sistema
class NotificationsTabPage extends StatelessWidget {
  const NotificationsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBuilder.isDesktop(context);
    final theme = context.watch<DsThemeSwitcher>().theme;

    return BlocProvider(
      create: (context) => NotificationsCubit()..loadNotifications(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notificações'),
          centerTitle: !isDesktop,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<NotificationsCubit>().loadNotifications();
              },
            ),
          ],
        ),
        body: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            if (state.status == NotificationsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == NotificationsStatus.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? 'Erro ao carregar notificações',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<NotificationsCubit>().loadNotifications();
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }

            final notifications = state.notifications;

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma novidade por enquanto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Volte novamente mais tarde',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                if (state.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: theme.primaryColor.withOpacity(0.1),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${state.unreadCount} notificação${state.unreadCount == 1 ? '' : 'ões'} não lida${state.unreadCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child:
                      isDesktop
                          ? _buildDesktopList(notifications, context)
                          : _buildMobileList(notifications, context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopList(
    List<NotificationItem> notifications,
    BuildContext context,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        return _NotificationCard(
          notification: notifications[index],
          onTap: () {
            context.read<NotificationsCubit>().markAsRead(
              notifications[index].id,
            );
          },
        );
      },
    );
  }

  Widget _buildMobileList(
    List<NotificationItem> notifications,
    BuildContext context,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        return _NotificationCard(
          notification: notifications[index],
          onTap: () {
            context.read<NotificationsCubit>().markAsRead(
              notifications[index].id,
            );
          },
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

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
    if (icon == null) return Icons.notifications;

    // Se for emoji, retorna ícone padrão
    if (icon.length > 2) return Icons.notifications;

    // Tenta mapear tipos de notificação para ícones
    switch (notification.notificationType.toUpperCase()) {
      case 'LOW_STOCK':
        return Icons.inventory_2_outlined;
      case 'UPCOMING_HOLIDAY':
        return Icons.celebration_outlined;
      case 'UPCOMING_PAYABLE':
        return Icons.payment_outlined;
      case 'PENDING_ORDER':
        return Icons.shopping_bag_outlined;
      case 'LOW_MOVER':
        return Icons.trending_down_outlined;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final isRead = notification.isRead;
    final priorityColor = _getPriorityColor(notification.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRead ? Colors.white : Colors.blue.shade50.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  _getIcon(notification.icon),
                  color: priorityColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: priorityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          dateFormat.format(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            notification.priority,
                            style: TextStyle(
                              fontSize: 10,
                              color: priorityColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (notification.actionText != null &&
                        notification.actionUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            // TODO: Navegar para actionUrl
                          },
                          child: Text(notification.actionText!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
