import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/store.dart';
import '../../../models/store_hour.dart';
import '../../../services/store_status_service.dart';

class StoreOpeningHours extends StatefulWidget {
  final List<StoreHour> hours;
  final Store? store; // ✅ Opcional para compatibilidade

  const StoreOpeningHours({
    super.key, 
    required this.hours,
    this.store,
  });

  @override
  State<StoreOpeningHours> createState() => _StoreOpeningHoursState();
}

class _StoreOpeningHoursState extends State<StoreOpeningHours> {
  bool expanded = false;
  Timer? _statusTimer;  // ✅ Timer para atualização automática
  Timer? _countdownTimer; // ✅ Timer para countdown em tempo real

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
  }

  @override
  void didUpdateWidget(StoreOpeningHours oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Reconfigura timers se a store mudou
    if (oldWidget.store?.store_operation_config?.pausedUntil != 
        widget.store?.store_operation_config?.pausedUntil) {
      _setupAutoRefresh();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// ✅ Configura atualização automática baseada no pausedUntil
  void _setupAutoRefresh() {
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    
    final pausedUntil = widget.store?.store_operation_config?.pausedUntil;
    
    if (pausedUntil != null && pausedUntil.isAfter(DateTime.now())) {
      // ✅ Calcula tempo até a pausa expirar
      final duration = pausedUntil.difference(DateTime.now());
      
      // Timer para atualizar quando a pausa expirar
      _statusTimer = Timer(duration + const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {}); // Força rebuild para mostrar "Aberto"
          _setupAutoRefresh(); // Reconfigura para próxima verificação
        }
      });
      
      // ✅ Timer de countdown - atualiza a cada minuto para mostrar tempo restante
      _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) {
          setState(() {}); // Atualiza o tempo restante exibido
        }
      });
    } else {
      // ✅ Verifica a cada 5 minutos para mudanças de horário de funcionamento
      _statusTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

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

  /// ✅ Usa o StoreStatusService para obter o status real da loja
  StoreStatusResult? _getStoreStatus() {
    if (widget.store != null) {
      return StoreStatusService.validateStoreStatus(widget.store);
    }
    return null;
  }

  /// ✅ Fallback: Verifica apenas horários (para compatibilidade quando store é null)
  bool _checkIfOpenByHours() {
    final now = TimeOfDay.now();
    final todayHours = widget.hours.where((h) => h.dayOfWeek == today && h.isActive);

    for (final period in todayHours) {
      if (period.openingTime != null && period.closingTime != null) {
        if (_isTimeWithinPeriod(now, period.openingTime!, period.closingTime!)) {
          return true;
        }
      }
    }
    return false;
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

    // ✅ Usa o serviço centralizado se a store estiver disponível
    final status = _getStoreStatus();
    
    // Determina o estado real da loja
    final bool isOpen;
    final String statusText;
    final Color statusColor;
    String? additionalInfo;
    
    if (status != null) {
      // ✅ Usa o StoreStatusService para status completo
      isOpen = status.canReceiveOrders;
      
      if (isOpen) {
        statusText = 'Aberto agora';
        statusColor = Colors.green.shade700;
      } else {
        // Determina a mensagem baseada no motivo
        switch (status.reason) {
          case 'scheduled_quick_pause':
          case 'scheduled_pause':
            statusText = 'Loja pausada';
            statusColor = Colors.orange.shade700;
            // ✅ Mostra tempo restante se for pausa rápida
            if (status.message != null && status.message!.contains('Reabre')) {
              additionalInfo = status.message;
            }
            break;
          case 'outside_hours':
            statusText = 'Fechado';
            statusColor = Colors.red.shade700;
            break;
          case 'store_closed':
            statusText = 'Loja fechada';
            statusColor = Colors.red.shade700;
            break;
          case 'not_operational':
            statusText = 'Indisponível';
            statusColor = Colors.grey.shade700;
            break;
          default:
            statusText = 'Fechado';
            statusColor = Colors.red.shade700;
        }
      }
    } else {
      // Fallback: verifica apenas horários
      isOpen = _checkIfOpenByHours();
      statusText = isOpen ? 'Aberto agora' : 'Fechado';
      statusColor = isOpen ? Colors.green.shade700 : Colors.red.shade700;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => expanded = !expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: statusColor,
                          ),
                        ),
                        // ✅ Mostra info adicional (ex: "Reabre em 12 min")
                        if (additionalInfo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              additionalInfo,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor.withAlpha(180),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Ver horários',
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
