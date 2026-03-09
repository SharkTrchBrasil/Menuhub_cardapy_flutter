import 'package:flutter/material.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/models/availability_model.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';

/// ⚠️ IMPORTANTE: Este serviço é apenas para UI HINTS (mensagens ao usuário)
/// A FILTRAGEM REAL de disponibilidade é feita no BACKEND antes de enviar dados ao Totem.
///
/// O backend já remove categorias e produtos indisponíveis do payload,
/// então o Totem nunca recebe itens fora do horário.
///
/// Este serviço serve apenas para:
/// - Exibir mensagens de "Disponível a partir de X horas" (futuro)
/// - Validações locais de UI (se necessário)
class AvailabilityCheckerService {
  /// Verifica se uma categoria está disponível agora
  /// Considera:
  /// 1. Tipo de disponibilidade (ALWAYS ou SCHEDULED)
  /// 2. Dias da semana configurados
  /// 3. Horários específicos
  static bool isCategoryAvailableNow(Category category) {
    // Se for ALWAYS, está sempre disponível
    if (category.availabilityType == AvailabilityType.always) {
      return true;
    }

    // Se for SCHEDULED, verifica as regras
    if (category.availabilityType == AvailabilityType.scheduled) {
      // Se não tiver regras definidas, assume indisponível por segurança
      if (category.schedules.isEmpty) {
        return false;
      }

      return _isTimeWithinSchedules(category.schedules);
    }

    // Default: disponível
    return true;
  }

  /// Verifica se um produto está disponível agora
  /// Considera:
  /// 1. Status do produto (ACTIVE)
  /// 2. Estoque (se controlado)
  /// 3. Tipo de disponibilidade (ALWAYS ou SCHEDULED)
  /// 4. Dias da semana e horários configurados
  static bool isProductAvailableNow(Product product) {
    // 1. Verifica status
    if (product.status.name != 'ACTIVE') {
      return false;
    }

    // 2. Verifica estoque
    if (product.controlStock && product.stockQuantity <= 0) {
      return false;
    }

    // 3. Verifica disponibilidade por horário
    if (product.availabilityType == AvailabilityType.always) {
      return true;
    }

    // Se for SCHEDULED, verifica as regras
    if (product.availabilityType == AvailabilityType.scheduled) {
      // Se não tiver regras definidas, assume indisponível por segurança
      if (product.schedules.isEmpty) {
        return false;
      }

      return _isTimeWithinSchedules(product.schedules);
    }

    return true;
  }

  /// Verifica se o horário atual está dentro de alguma regra de agendamento
  static bool _isTimeWithinSchedules(List<ScheduleRule> schedules) {
    final now = DateTime.now();

    // Converte DateTime.weekday (1=Mon, 7=Sun) para índice (0=Sun, 1=Mon, ..., 6=Sat)
    final dayOfWeek = _convertWeekdayToDayIndex(now.weekday);
    final currentTime = TimeOfDay.fromDateTime(now);

    // Verifica se alguma regra bate com o dia e hora atuais
    for (final rule in schedules) {
      // Verifica se o dia atual está na lista de dias da regra
      if (dayOfWeek < rule.days.length && rule.days[dayOfWeek]) {
        // Verifica se o horário atual está dentro de algum turno
        for (final shift in rule.shifts) {
          if (_isTimeWithinShift(currentTime, shift)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Converte DateTime.weekday (1=Mon, 7=Sun) para índice (0=Sun, 1=Mon, ..., 6=Sat)
  static int _convertWeekdayToDayIndex(int weekday) {
    // DateTime.weekday: 1=Monday, 2=Tuesday, ..., 7=Sunday
    // Índice esperado: 0=Sunday, 1=Monday, ..., 6=Saturday
    if (weekday == 7) {
      return 0; // Domingo
    } else {
      return weekday; // 1=Segunda, 2=Terça, ..., 6=Sábado
    }
  }

  /// Verifica se um horário está dentro de um turno
  static bool _isTimeWithinShift(TimeOfDay current, TimeShift shift) {
    final nowMinutes = current.hour * 60 + current.minute;
    final startMinutes = shift.startTime.hour * 60 + shift.startTime.minute;
    final endMinutes = shift.endTime.hour * 60 + shift.endTime.minute;

    if (startMinutes <= endMinutes) {
      // Turno normal (ex: 08:00 às 18:00)
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Turno que vira a noite (ex: 22:00 às 02:00)
      // É válido se for >= start (ex: 23:00) OU < end (ex: 01:00)
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }

  /// Filtra categorias disponíveis agora
  static List<Category> filterAvailableCategories(List<Category> categories) {
    return categories
        .where((category) => isCategoryAvailableNow(category))
        .toList();
  }

  /// Filtra produtos disponíveis agora dentro de uma categoria
  static List<Product> filterAvailableProducts(
    List<Product> products,
    Category category,
  ) {
    // Se a categoria não está disponível, nenhum produto dela está
    if (!isCategoryAvailableNow(category)) {
      return [];
    }

    // Filtra produtos que estão vinculados à categoria e disponíveis
    return products.where((product) {
      // Verifica se o produto está vinculado à categoria
      final isLinkedToCategory = product.categoryLinks.any(
        (link) => link.categoryId == category.id,
      );

      if (!isLinkedToCategory) {
        return false;
      }

      // Verifica se o produto está disponível
      return isProductAvailableNow(product);
    }).toList();
  }

  /// Retorna mensagem de indisponibilidade para exibir ao usuário
  static String getUnavailabilityReason(Category category) {
    if (category.availabilityType == AvailabilityType.always) {
      return 'Categoria disponível';
    }

    if (category.schedules.isEmpty) {
      return 'Categoria indisponível no momento';
    }

    // Tenta encontrar o próximo horário disponível
    final nextAvailable = _getNextAvailableTime(category.schedules);
    if (nextAvailable != null) {
      return 'Disponível a partir de ${nextAvailable.format(null)}';
    }

    return 'Categoria indisponível no momento';
  }

  /// Retorna mensagem de indisponibilidade para um produto
  static String getProductUnavailabilityReason(Product product) {
    if (product.status.name != 'ACTIVE') {
      return 'Produto indisponível';
    }

    if (product.controlStock && product.stockQuantity <= 0) {
      return 'Fora de estoque';
    }

    if (product.availabilityType == AvailabilityType.always) {
      return 'Produto disponível';
    }

    if (product.schedules.isEmpty) {
      return 'Produto indisponível no momento';
    }

    // Tenta encontrar o próximo horário disponível
    final nextAvailable = _getNextAvailableTime(product.schedules);
    if (nextAvailable != null) {
      return 'Disponível a partir de ${nextAvailable.format(null)}';
    }

    return 'Produto indisponível no momento';
  }

  /// Encontra o próximo horário disponível baseado nas regras de agendamento
  static TimeOfDay? _getNextAvailableTime(List<ScheduleRule> schedules) {
    if (schedules.isEmpty) return null;

    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    final currentDayIndex = _convertWeekdayToDayIndex(now.weekday);

    // Coleta todos os horários de início disponíveis
    final availableTimes = <TimeOfDay>[];

    for (final rule in schedules) {
      for (int dayIndex = 0; dayIndex < rule.days.length; dayIndex++) {
        if (rule.days[dayIndex]) {
          for (final shift in rule.shifts) {
            availableTimes.add(shift.startTime);
          }
        }
      }
    }

    if (availableTimes.isEmpty) return null;

    // Ordena os horários
    availableTimes.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });

    // Retorna o primeiro horário disponível
    return availableTimes.first;
  }
}
