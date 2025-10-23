import 'package:flutter/material.dart';
import 'package:totem/models/store_hour.dart'; // Garanta que o import do seu modelo está correto

class StoreStatusHelper {
  final List<StoreHour> hours;
  final DateTime now;
  final int todayWeekday;
  final TimeOfDay currentTime;

  StoreStatusHelper({required this.hours}) : now = DateTime.now(),
        todayWeekday = DateTime.now().weekday % 7,
        currentTime = TimeOfDay.fromDateTime(DateTime.now());

  /// Verifica se a loja está aberta neste exato momento.
  bool get isOpen {
    final currentOpeningPeriod = _findCurrentOpeningPeriod();
    return currentOpeningPeriod != null;
  }

  /// Retorna a mensagem de status completa e inteligente.
  String get statusMessage {
    if (isOpen) {
      final currentPeriod = _findCurrentOpeningPeriod()!;
      return "Fecha às ${formatTime(currentPeriod.closingTime!)}";
    } else {
      final nextOpening = _findNextOpening();
      if (nextOpening != null) {
        final dayName = _getDayName(nextOpening.dayOfWeek);
        return "Abre $dayName às ${formatTime(nextOpening.time)}";
      }
      return "Fechado";
    }
  }

  // --- Funções privadas (lógica que já tínhamos) ---

  StoreHour? _findCurrentOpeningPeriod() {
    final todayHours = hours.where((h) => h.dayOfWeek == todayWeekday && h.isActive);
    for (final period in todayHours) {
      if (_isTimeWithinPeriod(currentTime, period.openingTime!, period.closingTime!)) {
        return period;
      }
    }
    return null;
  }

  _NextOpeningInfo? _findNextOpening() {
    final todaysFutureOpenings = hours
        .where((h) => h.dayOfWeek == todayWeekday && h.isActive && _compareTime(h.openingTime!, currentTime) > 0)
        .toList()
      ..sort((a, b) => _compareTime(a.openingTime!, b.openingTime!));

    if (todaysFutureOpenings.isNotEmpty) {
      return _NextOpeningInfo(todaysFutureOpenings.first.openingTime!, todayWeekday);
    }

    for (int i = 1; i <= 6; i++) {
      final nextDayWeekday = (todayWeekday + i) % 7;
      final nextDayOpenings = hours
          .where((h) => h.dayOfWeek == nextDayWeekday && h.isActive)
          .toList()
        ..sort((a, b) => _compareTime(a.openingTime!, b.openingTime!));

      if (nextDayOpenings.isNotEmpty) {
        return _NextOpeningInfo(nextDayOpenings.first.openingTime!, nextDayWeekday);
      }
    }
    return null;
  }

  String _getDayName(int targetWeekday) {
    if (targetWeekday == todayWeekday) return "hoje";
    if (targetWeekday == (todayWeekday + 1) % 7) return "amanhã";

    const days = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"];
    return days[targetWeekday];
  }

  bool _isTimeWithinPeriod(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (endMinutes < startMinutes) {
      return timeMinutes >= startMinutes || timeMinutes < endMinutes;
    }
    return timeMinutes >= startMinutes && timeMinutes < endMinutes;
  }

  int _compareTime(TimeOfDay t1, TimeOfDay t2) {
    return (t1.hour * 60 + t1.minute) - (t2.hour * 60 + t2.minute);
  }

  String formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _NextOpeningInfo {
  final TimeOfDay time;
  final int dayOfWeek;
  _NextOpeningInfo(this.time, this.dayOfWeek);
}