// lib/models/notification.dart

class NotificationItem {
  final String id;
  final String source; // "system" or "dashboard"
  final String notificationType;
  final String title;
  final String message;
  final String priority; // "HIGH", "MEDIUM", "LOW"
  final String? actionUrl;
  final String? actionText;
  final String? icon;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? details;

  NotificationItem({
    required this.id,
    required this.source,
    required this.notificationType,
    required this.title,
    required this.message,
    required this.priority,
    this.actionUrl,
    this.actionText,
    this.icon,
    required this.isRead,
    required this.createdAt,
    this.details,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      source: json['source'] as String,
      notificationType: json['notification_type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      priority: json['priority'] as String,
      actionUrl: json['action_url'] as String?,
      actionText: json['action_text'] as String?,
      icon: json['icon'] as String?,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'notification_type': notificationType,
      'title': title,
      'message': message,
      'priority': priority,
      'action_url': actionUrl,
      'action_text': actionText,
      'icon': icon,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'details': details,
    };
  }
}

class NotificationListResponse {
  final List<NotificationItem> items;
  final int total;
  final int unreadCount;

  NotificationListResponse({
    required this.items,
    required this.total,
    required this.unreadCount,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    return NotificationListResponse(
      items: (json['items'] as List)
          .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      unreadCount: json['unread_count'] as int,
    );
  }
}

class NotificationCountResponse {
  final int unreadCount;
  final int totalCount;

  NotificationCountResponse({
    required this.unreadCount,
    required this.totalCount,
  });

  factory NotificationCountResponse.fromJson(Map<String, dynamic> json) {
    return NotificationCountResponse(
      unreadCount: json['unread_count'] as int,
      totalCount: json['total_count'] as int,
    );
  }
}

