import 'package:flutter/material.dart';

class ScheduledPause {
  final int id;
  final String? reason;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;

  ScheduledPause({
    required this.id,
    this.reason,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  factory ScheduledPause.fromJson(Map<String, dynamic> json) {
    return ScheduledPause(
      id: json['id'] as int,
      reason: json['reason'] as String?,
      startTime: DateTime.parse(json['start_time'].toString()),
      endTime: DateTime.parse(json['end_time'].toString()),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reason': reason,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_active': isActive,
    };
  }
}
