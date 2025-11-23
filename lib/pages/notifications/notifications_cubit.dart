import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/di.dart';
import 'package:totem/models/notification.dart';
import 'package:totem/pages/notifications/notifications_state.dart';
import 'package:totem/repositories/notification_repository.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationRepository _notificationRepository;

  NotificationsCubit() : _notificationRepository = getIt<NotificationRepository>(), super(NotificationsState.initial()) {
    loadNotificationCount();
  }

  /// Carrega notificações
  Future<void> loadNotifications({bool includeRead = false}) async {
    emit(state.copyWith(status: NotificationsStatus.loading));

    final result = await _notificationRepository.getNotifications(
      includeRead: includeRead,
      limit: 50,
    );

    result.fold(
      (error) {
        emit(state.copyWith(
          status: NotificationsStatus.error,
          errorMessage: error,
        ));
      },
      (response) {
        emit(state.copyWith(
          status: NotificationsStatus.loaded,
          notifications: response.items,
          unreadCount: response.unreadCount,
        ));
      },
    );
  }

  /// Carrega contagem de notificações não lidas
  Future<void> loadNotificationCount() async {
    final result = await _notificationRepository.getNotificationCount();

    result.fold(
      (error) {
        // Ignora erro silenciosamente para não interromper UI
        debugPrint('Erro ao carregar contagem: $error');
      },
      (response) {
        emit(state.copyWith(unreadCount: response.unreadCount));
      },
    );
  }

  /// Marca uma notificação como lida
  Future<void> markAsRead(String notificationId) async {
    final result = await _notificationRepository.markAsRead(notificationId);

    result.fold(
      (error) {
        debugPrint('Erro ao marcar como lida: $error');
      },
      (_) {
        // Atualiza estado local
        final updatedNotifications = state.notifications.map((n) {
          if (n.id == notificationId) {
            return NotificationItem(
              id: n.id,
              source: n.source,
              notificationType: n.notificationType,
              title: n.title,
              message: n.message,
              priority: n.priority,
              actionUrl: n.actionUrl,
              actionText: n.actionText,
              icon: n.icon,
              isRead: true,
              createdAt: n.createdAt,
              details: n.details,
            );
          }
          return n;
        }).toList();

        final newUnreadCount = state.unreadCount > 0 ? state.unreadCount - 1 : 0;

        emit(state.copyWith(
          notifications: updatedNotifications,
          unreadCount: newUnreadCount,
        ));

        // Recarrega contagem para garantir sincronização
        loadNotificationCount();
      },
    );
  }
}

