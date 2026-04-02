/// ✅ TIMEZONE SERVICE - Serviço Centralizado de Gestão de Fusos Horários
///
/// Este serviço centraliza TODA a lógica de conversão de fusos horários
/// para garantir consistência em todo o sistema.
///
/// REGRAS DE OURO:
/// 1. BANCO DE DADOS: Sempre armazena em UTC
/// 2. BACKEND: Processa em UTC
/// 3. FRONTEND: Recebe UTC e converte para timezone DA LOJA (NÃO do dispositivo!)
/// 4. LOJA: Tem seu próprio timezone (store.timezone)
///
/// ⚠️ NUNCA use .toLocal() - isso converte para o timezone do DISPOSITIVO!
/// ✅ SEMPRE use este serviço para converter para o timezone da LOJA

import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class TimezoneService {
  /// Inicializa o sistema de timezones
  /// Deve ser chamado no main() antes de runApp()
  static Future<void> initialize() async {
    // Carrega dados de fuso horário
    tz_data.initializeTimeZones();
  }

  /// Converte um DateTime UTC (do backend) para o timezone da loja
  ///
  /// Exemplo:
  /// - Backend envia: "2026-01-03T13:00:00+00:00" (UTC)
  /// - Store timezone: "America/Sao_Paulo" (UTC-3)
  /// - Resultado: 2026-01-03 10:00:00 -03:00 (horário da loja)
  ///
  /// ⚠️ NÃO use .toLocal() que converte para timezone do dispositivo!
  static DateTime parseUTCWithStoreTimezone(
    String utcString,
    String storeTimezone,
  ) {
    try {
      // Parse UTC string
      final utc = DateTime.parse(utcString).toUtc();

      // Converte para timezone da loja
      final location = tz.getLocation(storeTimezone);
      return tz.TZDateTime.from(utc, location);
    } catch (e) {
      // Fallback para São Paulo se timezone inválido
      print(
        '⚠️ Erro ao converter timezone: $e. Usando America/Sao_Paulo como fallback.',
      );
      final location = tz.getLocation('America/Sao_Paulo');
      final utc = DateTime.parse(utcString).toUtc();
      return tz.TZDateTime.from(utc, location);
    }
  }

  /// Sobrecarga que aceita DateTime já parseado
  static DateTime convertUTCToStoreTimezone(
    DateTime utc,
    String storeTimezone,
  ) {
    try {
      final location = tz.getLocation(storeTimezone);
      return tz.TZDateTime.from(utc.toUtc(), location);
    } catch (e) {
      print(
        '⚠️ Erro ao converter timezone: $e. Usando America/Sao_Paulo como fallback.',
      );
      final location = tz.getLocation('America/Sao_Paulo');
      return tz.TZDateTime.from(utc.toUtc(), location);
    }
  }

  /// Formata DateTime UTC para exibição no timezone da loja
  ///
  /// Exemplo:
  /// ```dart
  /// final display = TimezoneService.formatStoreDateTime(
  ///   order.createdAt,
  ///   store.timezone,
  ///   format: 'dd/MM/yyyy HH:mm'
  /// );
  /// // "03/01/2026 10:30"
  /// ```
  static String formatStoreDateTime(
    DateTime utc,
    String storeTimezone, {
    String format = 'dd/MM/yyyy HH:mm',
    String locale = 'pt_BR',
  }) {
    try {
      final location = tz.getLocation(storeTimezone);
      final storeTime = tz.TZDateTime.from(utc.toUtc(), location);
      return DateFormat(format, locale).format(storeTime);
    } catch (e) {
      print('⚠️ Erro ao formatar timezone: $e');
      return DateFormat(format, locale).format(utc);
    }
  }

  /// Converte um DateTime do timezone da loja para UTC (para enviar ao backend)
  ///
  /// Usado quando o usuário seleciona uma data/hora no frontend e você
  /// precisa enviar ao backend
  static DateTime convertStoreTimezoneToUTC(
    DateTime localDateTime,
    String storeTimezone,
  ) {
    try {
      final location = tz.getLocation(storeTimezone);
      final tzDateTime = tz.TZDateTime.from(localDateTime, location);
      return tzDateTime.toUtc();
    } catch (e) {
      print('⚠️ Erro ao converter para UTC: $e');
      return localDateTime.toUtc();
    }
  }

  /// Retorna o DateTime atual no timezone da loja
  static DateTime nowInStoreTimezone(String storeTimezone) {
    try {
      final location = tz.getLocation(storeTimezone);
      return tz.TZDateTime.now(location);
    } catch (e) {
      print('⚠️ Erro ao obter now() no timezone da loja: $e');
      return DateTime.now();
    }
  }

  /// Retorna o início do dia (00:00:00) no timezone da loja
  /// Útil para queries de "pedidos de hoje"
  static DateTime getStartOfDayInStoreTimezone(
    DateTime date,
    String storeTimezone,
  ) {
    try {
      final location = tz.getLocation(storeTimezone);
      final localDate = tz.TZDateTime.from(date, location);
      return tz.TZDateTime(
        location,
        localDate.year,
        localDate.month,
        localDate.day,
        0,
        0,
        0,
      );
    } catch (e) {
      print('⚠️ Erro ao obter início do dia: $e');
      return DateTime(date.year, date.month, date.day, 0, 0, 0);
    }
  }

  /// Retorna o fim do dia (23:59:59) no timezone da loja
  static DateTime getEndOfDayInStoreTimezone(
    DateTime date,
    String storeTimezone,
  ) {
    try {
      final location = tz.getLocation(storeTimezone);
      final localDate = tz.TZDateTime.from(date, location);
      return tz.TZDateTime(
        location,
        localDate.year,
        localDate.month,
        localDate.day,
        23,
        59,
        59,
        999,
      );
    } catch (e) {
      print('⚠️ Erro ao obter fim do dia: $e');
      return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    }
  }

  /// Verifica se dois DateTimes são do mesmo dia no timezone da loja
  static bool isSameDayInStoreTimezone(
    DateTime dt1,
    DateTime dt2,
    String storeTimezone,
  ) {
    try {
      final location = tz.getLocation(storeTimezone);
      final local1 = tz.TZDateTime.from(dt1.toUtc(), location);
      final local2 = tz.TZDateTime.from(dt2.toUtc(), location);

      return local1.year == local2.year &&
          local1.month == local2.month &&
          local1.day == local2.day;
    } catch (e) {
      print('⚠️ Erro ao comparar datas: $e');
      return dt1.year == dt2.year &&
          dt1.month == dt2.month &&
          dt1.day == dt2.day;
    }
  }

  /// Lista de timezones comuns suportados
  static const Map<String, String> commonTimezones = {
    // Brasil
    'America/Sao_Paulo': '🇧🇷 Brasil - São Paulo (UTC-3)',
    'America/Manaus': '🇧🇷 Brasil - Manaus (UTC-4)',
    'America/Recife': '🇧🇷 Brasil - Recife (UTC-3)',
    'America/Fortaleza': '🇧🇷 Brasil - Fortaleza (UTC-3)',
    'America/Belem': '🇧🇷 Brasil - Belém (UTC-3)',

    // Portugal
    'Europe/Lisbon': '🇵🇹 Portugal - Lisboa (UTC+0/+1)',
    'Atlantic/Azores': '🇵🇹 Portugal - Açores (UTC-1/0)',

    // Outros
    'Europe/Madrid': '🇪🇸 Espanha - Madrid (UTC+1/+2)',
    'America/New_York': '🇺🇸 EUA - Nova York (UTC-5/-4)',
    'America/Los_Angeles': '🇺🇸 EUA - Los Angeles (UTC-8/-7)',
    'Europe/London': '🇬🇧 Reino Unido - Londres (UTC+0/+1)',
  };

  /// Timezone padrão (Brasil)
  static const String defaultTimezone = 'America/Sao_Paulo';

  /// Valida se um timezone é válido
  static bool isValidTimezone(String timezone) {
    try {
      tz.getLocation(timezone);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Retorna o offset do timezone em relação ao UTC
  /// Exemplo: America/Sao_Paulo retorna "-03:00"
  static String getTimezoneOffset(String timezone) {
    try {
      final location = tz.getLocation(timezone);
      final now = tz.TZDateTime.now(location);
      final offset = now.timeZoneOffset;

      final hours = offset.inHours;
      final minutes = offset.inMinutes.remainder(60).abs();

      final sign = hours >= 0 ? '+' : '';
      return '$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } catch (e) {
      return '+00:00';
    }
  }
}
