import 'package:equatable/equatable.dart';
import 'package:totem/models/notification.dart';

enum NotificationsStatus {
  initial,
  loading,
  loaded,
  error,
}

class NotificationsState extends Equatable {
  final NotificationsStatus status;
  final List<NotificationItem> notifications;
  final int unreadCount;
  final String? errorMessage;

  const NotificationsState({
    required this.status,
    required this.notifications,
    required this.unreadCount,
    this.errorMessage,
  });

  factory NotificationsState.initial() {
    return const NotificationsState(
      status: NotificationsStatus.initial,
      notifications: [],
      unreadCount: 0,
    );
  }

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationItem>? notifications,
    int? unreadCount,
    String? errorMessage,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, notifications, unreadCount, errorMessage];
}

