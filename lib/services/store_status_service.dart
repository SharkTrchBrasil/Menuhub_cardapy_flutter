// lib/services/store_status_service.dart
import 'package:flutter/material.dart';
import 'package:totem/models/store.dart';
import 'package:totem/models/store_operation_config.dart';
import 'package:totem/models/store_hour.dart';
import 'package:totem/models/scheduled_pause.dart';
import 'package:totem/helpers/store_hours_helper.dart';

/// Resultado da validação de status da loja
class StoreStatusResult {
  final bool canReceiveOrders;
  final String reason;
  final String? message;
  final bool isStoreOpen;
  final bool deliveryEnabled;
  final bool pickupEnabled;
  final bool tableEnabled;
  final bool withinOpeningHours;

  StoreStatusResult({
    required this.canReceiveOrders,
    required this.reason,
    this.message,
    required this.isStoreOpen,
    required this.deliveryEnabled,
    required this.pickupEnabled,
    required this.tableEnabled,
    required this.withinOpeningHours,
  });

  bool get canOrderDelivery => canReceiveOrders && deliveryEnabled;
  bool get canOrderPickup => canReceiveOrders && pickupEnabled;
  bool get canOrderTable => canReceiveOrders && tableEnabled;
}

/// Serviço centralizado para validação de status da loja
class StoreStatusService {
  /// Valida se a loja pode receber pedidos
  /// Verifica: horários, status operacional, modelos ativos
  static StoreStatusResult validateStoreStatus(Store? store) {
    // 1. Verifica se a loja existe
    if (store == null) {
      return StoreStatusResult(
        canReceiveOrders: false,
        reason: 'store_not_found',
        message: 'Loja não encontrada',
        isStoreOpen: false,
        deliveryEnabled: false,
        pickupEnabled: false,
        tableEnabled: false,
        withinOpeningHours: false,
      );
    }

    final config = store.store_operation_config;
    final hours = store.hours;
    final pauses = store.scheduledPauses;

    // 2. Verifica se a loja está aberta manualmente
    final isStoreOpen = config?.isStoreOpen ?? true;
    if (!isStoreOpen) {
      // ✅ PAUSA RÁPIDA: Verifica se tem paused_until definido
      final pausedUntil = config?.pausedUntil;
      String message = 'Loja está fechada temporariamente';

      if (pausedUntil != null && pausedUntil.isAfter(DateTime.now())) {
        // Calcula tempo restante
        final remaining = pausedUntil.difference(DateTime.now());
        if (remaining.inMinutes < 60) {
          message = 'Loja pausada. Reabre em ${remaining.inMinutes} min';
        } else {
          final hours = remaining.inHours;
          final mins = remaining.inMinutes % 60;
          message =
              'Loja pausada. Reabre em ${hours}h${mins > 0 ? ' ${mins}min' : ''}';
        }
      }

      return StoreStatusResult(
        canReceiveOrders: false,
        reason: pausedUntil != null ? 'scheduled_quick_pause' : 'store_closed',
        message: message,
        isStoreOpen: false,
        deliveryEnabled: config?.isDeliveryAvailable ?? false,
        pickupEnabled: config?.isPickupAvailable ?? false,
        tableEnabled: config?.isTableAvailable ?? false,
        withinOpeningHours: false,
      );
    }

    // 3. Verifica se está dentro dos horários de funcionamento
    final isWithinHours =
        hours.isNotEmpty ? _checkWithinOpeningHours(hours) : true;

    if (!isWithinHours && hours.isNotEmpty) {
      final helper = StoreStatusHelper(hours: hours);
      return StoreStatusResult(
        canReceiveOrders: false,
        reason: 'outside_hours',
        message: helper.statusMessage,
        isStoreOpen: true,
        deliveryEnabled: config?.isDeliveryAvailable ?? false,
        pickupEnabled: config?.isPickupAvailable ?? false,
        tableEnabled: config?.isTableAvailable ?? false,
        withinOpeningHours: false,
      );
    }

    // 4. Verifica se está em uma pausa agendada ativa
    final now = DateTime.now();
    final isInPause = _checkIfInScheduledPause(pauses, now);
    if (isInPause != null) {
      return StoreStatusResult(
        canReceiveOrders: false,
        reason: 'scheduled_pause',
        message: isInPause,
        isStoreOpen: true,
        deliveryEnabled: config?.isDeliveryAvailable ?? false,
        pickupEnabled: config?.isPickupAvailable ?? false,
        tableEnabled: config?.isTableAvailable ?? false,
        withinOpeningHours: isWithinHours,
      );
    }

    // 5. Verifica se está operacional
    final isOperational = config?.is_operational ?? true;
    if (!isOperational) {
      return StoreStatusResult(
        canReceiveOrders: false,
        reason: 'not_operational',
        message: 'Loja temporariamente indisponível',
        isStoreOpen: true,
        deliveryEnabled: config?.isDeliveryAvailable ?? false,
        pickupEnabled: config?.isPickupAvailable ?? false,
        tableEnabled: config?.isTableAvailable ?? false,
        withinOpeningHours: isWithinHours,
      );
    }

    // 6. Verifica se pelo menos uma modalidade está DISPONÍVEL
    // ✅ CORREÇÃO: Usa os getters que consideram tanto enabled quanto paused
    // isDeliveryAvailable = deliveryEnabled && !deliveryPaused
    final deliveryAvailable = config?.isDeliveryAvailable ?? false;
    final pickupAvailable = config?.isPickupAvailable ?? false;
    final tableAvailable = config?.isTableAvailable ?? false;

    if (!deliveryAvailable && !pickupAvailable && !tableAvailable) {
      return StoreStatusResult(
        canReceiveOrders: false,
        reason: 'no_delivery_methods',
        message: 'Nenhum método de entrega disponível no momento',
        isStoreOpen: true,
        deliveryEnabled: false,
        pickupEnabled: false,
        tableEnabled: false,
        withinOpeningHours: isWithinHours,
      );
    }

    // ✅ Loja pode receber pedidos
    return StoreStatusResult(
      canReceiveOrders: true,
      reason: 'ok',
      message: null,
      isStoreOpen: true,
      deliveryEnabled:
          deliveryAvailable, // ✅ Retorna disponibilidade real (enabled && !paused)
      pickupEnabled: pickupAvailable,
      tableEnabled: tableAvailable,
      withinOpeningHours: isWithinHours,
    );
  }

  /// ✅ Retorna informações se a loja está prestes a fechar (dentro de 10 min)
  static Map<String, dynamic>? getClosingSoonInfo(Store? store) {
    if (store == null) return null;
    final hours = store.hours;
    if (hours.isEmpty) return null;

    final now = DateTime.now();
    final todayWeekday = now.weekday % 7;
    final currentTime = TimeOfDay.fromDateTime(now);
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    final todayHours = hours.where(
      (h) => h.dayOfWeek == todayWeekday && h.isActive,
    );

    for (final period in todayHours) {
      if (period.openingTime == null || period.closingTime == null) continue;

      final openMinutes =
          period.openingTime!.hour * 60 + period.openingTime!.minute;
      final closeMinutes =
          period.closingTime!.hour * 60 + period.closingTime!.minute;

      // Verifica se está aberta no momento
      bool isOpen = false;
      if (closeMinutes < openMinutes) {
        isOpen = currentMinutes >= openMinutes || currentMinutes < closeMinutes;
      } else {
        isOpen = currentMinutes >= openMinutes && currentMinutes < closeMinutes;
      }

      if (isOpen) {
        // Calcula minutos restantes
        int diff;
        if (closeMinutes < openMinutes) {
          // Vira a noite
          if (currentMinutes >= openMinutes) {
            diff = (24 * 60 - currentMinutes) + closeMinutes;
          } else {
            diff = closeMinutes - currentMinutes;
          }
        } else {
          diff = closeMinutes - currentMinutes;
        }

        // Se falta 10 minutos ou menos
        if (diff > 0 && diff <= 10) {
          return {'closingTime': period.closingTime, 'minutesRemaining': diff};
        }
      }
    }
    return null;
  }

  /// Valida se um método específico está disponível
  static bool isDeliveryMethodAvailable(
    Store? store,
    String method, // 'delivery', 'pickup', 'table'
  ) {
    final status = validateStoreStatus(store);
    if (!status.canReceiveOrders) return false;

    switch (method.toLowerCase()) {
      case 'delivery':
        return status.deliveryEnabled;
      case 'pickup':
        return status.pickupEnabled;
      case 'table':
        return status.tableEnabled;
      default:
        return false;
    }
  }

  /// Retorna mensagem amigável baseada no motivo
  static String getFriendlyMessage(StoreStatusResult result) {
    switch (result.reason) {
      case 'store_not_found':
        return 'Loja não encontrada.';
      case 'store_closed':
        return 'Loja está fechada temporariamente.';
      case 'outside_hours':
        return result.message ?? 'Fora do horário de funcionamento.';
      case 'not_operational':
        return 'Loja temporariamente indisponível. Tente novamente em instantes.';
      case 'no_delivery_methods':
        return 'Nenhum método de entrega disponível. Entre em contato com a loja.';
      case 'scheduled_pause':
        return result.message ??
            'Loja em pausa temporária. Tente novamente mais tarde.';
      case 'scheduled_quick_pause':
        return result.message ??
            'Loja pausada temporariamente. Reabrirá em breve.';
      case 'ok':
        return 'Loja aberta!';
      default:
        return 'Loja indisponível no momento.';
    }
  }

  /// Verifica se está dentro dos horários de funcionamento
  static bool _checkWithinOpeningHours(List<StoreHour> hours) {
    if (hours.isEmpty) return true;

    final now = DateTime.now();
    final todayWeekday = now.weekday % 7; // 0 = Dom, 6 = Sáb
    final currentTime = TimeOfDay.fromDateTime(now);

    final todayHours = hours.where(
      (h) => h.dayOfWeek == todayWeekday && h.isActive,
    );

    for (final period in todayHours) {
      if (period.openingTime == null || period.closingTime == null) continue;

      if (_isTimeWithinPeriod(
        currentTime,
        period.openingTime!,
        period.closingTime!,
      )) {
        return true;
      }
    }

    return false;
  }

  /// Verifica se o horário atual está dentro de um período
  static bool _isTimeWithinPeriod(
    TimeOfDay time,
    TimeOfDay start,
    TimeOfDay end,
  ) {
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

  /// Verifica se está em uma pausa agendada
  static String? _checkIfInScheduledPause(
    List<ScheduledPause> pauses,
    DateTime now,
  ) {
    for (final pause in pauses) {
      if (!pause.isActive) continue;
      if (now.isAfter(pause.startTime) && now.isBefore(pause.endTime)) {
        return pause.reason ?? 'Loja em pausa temporária';
      }
    }
    return null;
  }

  /// Verifica se pode abrir o carrinho
  static bool canOpenCart(Store? store) {
    final status = validateStoreStatus(store);
    return status.canReceiveOrders;
  }

  /// Verifica se pode adicionar ao carrinho
  static bool canAddToCart(Store? store) {
    return canOpenCart(store);
  }

  /// Verifica se pode fazer checkout
  static StoreStatusResult canCheckout(
    Store? store,
    String? selectedDeliveryMethod,
  ) {
    final status = validateStoreStatus(store);

    if (!status.canReceiveOrders) {
      return status;
    }

    // Verifica se o método selecionado está disponível
    if (selectedDeliveryMethod != null) {
      if (selectedDeliveryMethod.toLowerCase() == 'delivery' &&
          !status.deliveryEnabled) {
        return StoreStatusResult(
          canReceiveOrders: false,
          reason: 'delivery_disabled',
          message: 'Delivery não está disponível no momento',
          isStoreOpen: status.isStoreOpen,
          deliveryEnabled: false,
          pickupEnabled: status.pickupEnabled,
          tableEnabled: status.tableEnabled,
          withinOpeningHours: status.withinOpeningHours,
        );
      }

      if (selectedDeliveryMethod.toLowerCase() == 'pickup' &&
          !status.pickupEnabled) {
        return StoreStatusResult(
          canReceiveOrders: false,
          reason: 'pickup_disabled',
          message: 'Retirada não está disponível no momento',
          isStoreOpen: status.isStoreOpen,
          deliveryEnabled: status.deliveryEnabled,
          pickupEnabled: false,
          tableEnabled: status.tableEnabled,
          withinOpeningHours: status.withinOpeningHours,
        );
      }

      if (selectedDeliveryMethod.toLowerCase() == 'table' &&
          !status.tableEnabled) {
        return StoreStatusResult(
          canReceiveOrders: false,
          reason: 'table_disabled',
          message: 'Consumo no local não está disponível no momento',
          isStoreOpen: status.isStoreOpen,
          deliveryEnabled: status.deliveryEnabled,
          pickupEnabled: status.pickupEnabled,
          tableEnabled: false,
          withinOpeningHours: status.withinOpeningHours,
        );
      }
    }

    return status;
  }
}
