import 'package:flutter/material.dart';
import 'package:totem/models/store_hour.dart'; // Garanta que este import esteja correto

// Classe auxiliar para guardar a informação do próximo horário de funcionamento
class _NextOpeningInfo {
  final TimeOfDay time;
  final int dayOfWeek; // 0=Domingo, 1=Segunda, ..., 6=Sábado

  _NextOpeningInfo(this.time, this.dayOfWeek);
}

class StoreHoursWidget extends StatelessWidget {
  const StoreHoursWidget({super.key, required this.hours});
  final List<StoreHour> hours;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // O backend envia 0-6 (dom-sab), mas DateTime.weekday é 1-7 (seg-dom).
    // Usamos a conversão `% 7` para alinhar (0=dom, 1=seg, etc.)
    final todayWeekday = now.weekday % 7;
    final currentTime = TimeOfDay.fromDateTime(now);

    // 1. Verifica se a loja está ABERTA AGORA
    final currentOpeningPeriod = _findCurrentOpeningPeriod(todayWeekday, currentTime);
    final bool isOpen = currentOpeningPeriod != null;

    // 2. Determina os textos de status e horário
    String statusText;
    String hourText;

    if (isOpen) {
      statusText = "Aberto";
      // Se estiver aberto, mostra até que horas fica aberto hoje.
      hourText = "Fecha às ${formatTime(currentOpeningPeriod.closingTime!)}";
    } else {
      statusText = "Fechado";
      // Se estiver fechado, procura o PRÓXIMO horário de funcionamento.
      final nextOpening = _findNextOpening(todayWeekday, currentTime);

      if (nextOpening != null) {
        final dayName = _getDayName(nextOpening.dayOfWeek, todayWeekday);
        hourText = "Abre $dayName às ${formatTime(nextOpening.time)}";
      } else {
        // Fallback se não houver nenhum horário cadastrado para os próximos 7 dias.
        hourText = "Consulte os horários";
      }
    }

    // 3. Constrói a interface
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(hourText, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: TextStyle(
            color: isOpen ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Procura o período de funcionamento ATUAL.
  StoreHour? _findCurrentOpeningPeriod(int today, TimeOfDay currentTime) {
    final todayHours = hours.where((h) => h.dayOfWeek == today && h.isActive);
    for (final period in todayHours) {
      if (_isTimeWithinPeriod(currentTime, period.openingTime!, period.closingTime!)) {
        return period;
      }
    }
    return null;
  }

  /// Procura o PRÓXIMO período de funcionamento nos próximos 7 dias.
  _NextOpeningInfo? _findNextOpening(int today, TimeOfDay currentTime) {
    // Primeiro, procura por um horário mais tarde HOJE
    final todaysFutureOpenings = hours
        .where((h) => h.dayOfWeek == today && h.isActive && _compareTime(h.openingTime!, currentTime) > 0)
        .toList()
      ..sort((a, b) => _compareTime(a.openingTime!, b.openingTime!)); // Ordena para pegar o mais cedo

    if (todaysFutureOpenings.isNotEmpty) {
      return _NextOpeningInfo(todaysFutureOpenings.first.openingTime!, today);
    }

    // Se não encontrar hoje, procura nos próximos 6 dias
    for (int i = 1; i <= 6; i++) {
      final nextDayWeekday = (today + i) % 7;
      final nextDayOpenings = hours
          .where((h) => h.dayOfWeek == nextDayWeekday && h.isActive)
          .toList()
        ..sort((a, b) => _compareTime(a.openingTime!, b.openingTime!));

      if (nextDayOpenings.isNotEmpty) {
        return _NextOpeningInfo(nextDayOpenings.first.openingTime!, nextDayWeekday);
      }
    }

    return null; // Não encontrou nenhum horário nos próximos 7 dias
  }

  /// Retorna o nome do dia de forma inteligente ("hoje", "amanhã", etc.)
  String _getDayName(int targetWeekday, int todayWeekday) {
    if (targetWeekday == todayWeekday) return "hoje";
    if (targetWeekday == (todayWeekday + 1) % 7) return "amanhã";

    const days = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"];
    return days[targetWeekday];
  }

  /// Verifica se um horário está entre um período de abertura e fechamento.
  bool _isTimeWithinPeriod(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    // Lida com horários que viram a noite (ex: 18:00 - 02:00)
    if (endMinutes < startMinutes) {
      return timeMinutes >= startMinutes || timeMinutes < endMinutes;
    }
    return timeMinutes >= startMinutes && timeMinutes < endMinutes;
  }

  /// Compara dois TimeOfDay. Retorna > 0 se t1 for depois de t2.
  int _compareTime(TimeOfDay t1, TimeOfDay t2) {
    return (t1.hour * 60 + t1.minute) - (t2.hour * 60 + t2.minute);
  }

  /// Formata TimeOfDay para "HH:mm".
  String formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}