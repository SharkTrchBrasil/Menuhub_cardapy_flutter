import 'package:flutter/material.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/models/availability_model.dart';
import 'package:totem/models/product.dart';

class AvailabilityService {
  /// Verifica se um produto está disponível agora com base em seus agendamentos
  static bool isProductAvailableNow(Product product) {
    // 1. Verifica Estoque
    if (product.controlStock) {
      if (product.stockQuantity <= 0) {
        return false;
      }
    }

    // 2. Verifica Agendamento
    // Se o tipo for ALWAYS, está sempre disponível (respeitando o status ACTIVE que já é filtrado pelo backend/frontend)
    if (product.availabilityType == AvailabilityType.always) {
      return true;
    }

    // Se for SCHEDULED, verifica as regras
    if (product.availabilityType == AvailabilityType.scheduled) {
      // Se não tiver regras definidas, assume indisponível por segurança (ou disponível? Backend define. Vamos assumir indisponível se marcado como scheduled mas sem regras)
      if (product.schedules.isEmpty) {
        return false;
      }

      final now = DateTime.now();
      final currentDayOfWeek = now.weekday == 7 ? 0 : now.weekday; // DateTime: 1=Mon, 7=Sun. Backend/App: 0=Sun, 1=Mon...6=Sat
      // Ajuste: DateTime.weekday retorna 1 (Segunda) a 7 (Domingo).
      // Nosso modelo (ScheduleRule) usa 0 (Domingo) a 6 (Sábado) ou 1(Segunda) a 7(Domingo)?
      // Vamos verificar ScheduleRule.fromJson:
      // final daysFromApi = List<int>.from(json['days_of_week'] ?? []);
      // final daysForUi = List.generate(7, (index) => daysFromApi.contains(index));
      // Geralmente backend usa 0=Domingo.
      // Vamos assumir 0=Domingo, 1=Segunda, ..., 6=Sábado.
      
      // DateTime.weekday: 1=Mon, ..., 7=Sun.
      // Conversão:
      int todayIndex;
      if (now.weekday == 7) {
        todayIndex = 0; // Domingo
      } else {
        todayIndex = now.weekday; // 1=Segunda ... 6=Sábado
      }

      final currentTime = TimeOfDay.fromDateTime(now);

      // Verifica se alguma regra bate com o dia e hora atuais
      for (final rule in product.schedules) {
        // Verifica o dia da semana
        if (rule.days.length > todayIndex && rule.days[todayIndex]) {
          // Verifica os turnos (shifts)
          for (final shift in rule.shifts) {
            if (_isTimeWithinShift(currentTime, shift)) {
              return true;
            }
          }
        }
      }

      return false;
    }

    return true;
  }

  static bool _isTimeWithinShift(TimeOfDay current, TimeShift shift) {
    final nowMinutes = current.hour * 60 + current.minute;
    final startMinutes = shift.startTime.hour * 60 + shift.startTime.minute;
    final endMinutes = shift.endTime.hour * 60 + shift.endTime.minute;

    if (startMinutes <= endMinutes) {
      // Turno normal (ex: 08:00 as 18:00)
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Turno que vira a noite (ex: 22:00 as 02:00)
      // É válido se for >= start (ex: 23:00) OU < end (ex: 01:00)
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }
}
