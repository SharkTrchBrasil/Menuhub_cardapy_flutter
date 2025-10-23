import 'package:flutter/material.dart';
import '../../../models/store_hour.dart'; // Garanta que o import esteja correto

class StoreOpeningHours extends StatefulWidget {
  final List<StoreHour> hours;

  const StoreOpeningHours({super.key, required this.hours});

  @override
  State<StoreOpeningHours> createState() => _StoreOpeningHoursState();
}

class _StoreOpeningHoursState extends State<StoreOpeningHours> {
  bool expanded = false;

  int get today => DateTime.now().weekday % 7; // 0 = Domingo

  final Map<int, String> weekDays = {
    0: 'Domingo',
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
  };

  /// ✅ LÓGICA CORRIGIDA E ROBUSTA
  /// Verifica se a loja está aberta agora, lidando com horários noturnos.
  bool _checkIfOpenNow() {
    final now = TimeOfDay.now();
    final todayHours = widget.hours.where((h) => h.dayOfWeek == today && h.isActive);

    for (final period in todayHours) {
      if (_isTimeWithinPeriod(now, period.openingTime!, period.closingTime!)) {
        return true; // Encontrou um período válido, está aberto.
      }
    }
    return false; // Nenhum período de hoje corresponde ao horário atual.
  }

  /// ✅ FUNÇÃO AUXILIAR CORRIGIDA que entende horários "virados" (ex: 18:00 - 02:00)
  bool _isTimeWithinPeriod(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    // Se o horário de fechamento é "menor" que o de abertura, significa que vira a noite
    if (endMinutes < startMinutes) {
      // O horário atual é válido se for depois da abertura OU antes do fechamento do dia seguinte
      return timeMinutes >= startMinutes || timeMinutes < endMinutes;
    }

    // Caso normal (ex: 08:00 - 18:00)
    return timeMinutes >= startMinutes && timeMinutes < endMinutes;
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final todayHours = widget.hours
        .where((h) => h.dayOfWeek == today && h.isActive)
        .toList();

    // Chama a nova função corrigida
    final bool isOpen = _checkIfOpenNow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => expanded = !expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0), // Ajuste de padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOpen ? 'Aberto agora' : 'Fechado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16, // Aumentando um pouco a fonte
                        color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Ver horários', // Texto mais claro para o usuário
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 24,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
                if (!expanded && todayHours.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Hoje: ${todayHours.map((h) => '${formatTime(h.openingTime!)} às ${formatTime(h.closingTime!)}').join(' / ')}',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  )
                ]
              ],
            ),
          ),
        ),

        // A lista expandida da semana
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              children: List.generate(7, (index) {
                final dayHours = widget.hours
                    .where((h) => h.dayOfWeek == index && h.isActive)
                    .toList();

                final horarios = dayHours.isNotEmpty
                    ? dayHours
                    .map((h) => '${formatTime(h.openingTime!)} - ${formatTime(h.closingTime!)}')
                    .join(' / ')
                    : 'Fechado';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${weekDays[index]}:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: today == index ? FontWeight.bold : FontWeight.normal,
                          color: today == index ? Theme.of(context).primaryColor : Colors.black87,
                        ),
                      ),
                      Text(
                        horarios,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: today == index ? FontWeight.bold : FontWeight.normal,
                          color: today == index ? Theme.of(context).primaryColor : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}