import 'package:dio/dio.dart';
import 'package:flutter/material.dart';


class StoreHour  {
  const StoreHour({
    this.id,
    this.dayOfWeek = 1, // 0‑Dom … 6‑Sáb
    this.openingTime,
    this.closingTime,
    this.shiftNumber = 1,
    this.isActive = true,
  });

  /* ──────── campos ──────── */
  final int? id;
  final int? dayOfWeek;
  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;
  final int? shiftNumber;
  final bool isActive;

  factory StoreHour.fromJson(Map<String, dynamic> map) {
    return StoreHour(
      id: map['id'] as int?,
      dayOfWeek: map['day_of_week'] as int?,
      openingTime: _parseTime(map['open_time']),
      closingTime: _parseTime(map['close_time']),
      shiftNumber: map['shift_number'] as int?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  static TimeOfDay? _parseTime(String? timeString) {
    if (timeString == null) return null;
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }




  @override
  String get title => 'Hora de funcionamento $id'; // Você pode ajustar isso conforme necessário
}
