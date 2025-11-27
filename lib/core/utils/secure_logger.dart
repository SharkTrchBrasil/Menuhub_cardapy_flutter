/// 🔒 SECURE LOGGER - LGPD COMPLIANT
/// ==================================
/// Logger seguro que sanitiza dados sensíveis automaticamente.
/// Use em vez de print() em produção.

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Padrões de dados sensíveis para sanitização
final List<MapEntry<RegExp, String>> _sensitivePatterns = [
  // CPF
  MapEntry(RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b'), '[CPF_REDACTED]'),
  // CNPJ
  MapEntry(RegExp(r'\b\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}\b'), '[CNPJ_REDACTED]'),
  // Cartão de crédito
  MapEntry(RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'), '[CARD_REDACTED]'),
  // Email
  MapEntry(
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
    '[EMAIL_REDACTED]',
  ),
  // Telefone brasileiro
  MapEntry(
    RegExp(r'\b(?:\+55\s?)?\(?\d{2}\)?\s?\d{4,5}-?\d{4}\b'),
    '[PHONE_REDACTED]',
  ),
  // Tokens JWT
  MapEntry(
    RegExp(r'eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*'),
    '[JWT_REDACTED]',
  ),
  // Bearer tokens
  MapEntry(RegExp(r'Bearer\s+[A-Za-z0-9_-]+'), 'Bearer [TOKEN_REDACTED]'),
  // PIX keys (chaves aleatórias UUID)
  MapEntry(
    RegExp(r'\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b'),
    '[PIX_KEY_REDACTED]',
  ),
];

/// Campos sensíveis em Maps
const Set<String> _sensitiveFields = {
  'password',
  'senha',
  'secret',
  'token',
  'api_key',
  'access_token',
  'refresh_token',
  'cpf',
  'cnpj',
  'card_number',
  'cvv',
  'phone',
  'telefone',
  'email',
  'pix_key',
};

/// Sanitiza uma string removendo dados sensíveis
String _sanitize(String text) {
  String result = text;
  for (final pattern in _sensitivePatterns) {
    result = result.replaceAll(pattern.key, pattern.value);
  }
  return result;
}

/// Sanitiza um Map removendo valores de campos sensíveis
Map<String, dynamic> _sanitizeMap(Map<String, dynamic> data, [int depth = 0]) {
  if (depth > 10) return data;

  final result = <String, dynamic>{};
  for (final entry in data.entries) {
    final keyLower = entry.key.toLowerCase();

    if (_sensitiveFields.contains(keyLower)) {
      result[entry.key] = '[${entry.key.toUpperCase()}_REDACTED]';
    } else if (entry.value is Map<String, dynamic>) {
      result[entry.key] = _sanitizeMap(entry.value, depth + 1);
    } else if (entry.value is String) {
      result[entry.key] = _sanitize(entry.value);
    } else {
      result[entry.key] = entry.value;
    }
  }
  return result;
}

/// Logger seguro para uso em produção
class SecureLogger {
  final String name;

  SecureLogger(this.name);

  /// Log de debug (apenas em modo debug)
  void debug(String message, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      final sanitizedMessage = _sanitize(message);
      final sanitizedData = data != null ? _sanitizeMap(data) : null;
      developer.log(
        '🐛 $sanitizedMessage',
        name: name,
        error: sanitizedData,
      );
    }
  }

  /// Log de informação
  void info(String message, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      final sanitizedMessage = _sanitize(message);
      developer.log(
        'ℹ️ $sanitizedMessage',
        name: name,
      );
    }
  }

  /// Log de aviso
  void warning(String message, [Map<String, dynamic>? data]) {
    final sanitizedMessage = _sanitize(message);
    if (kDebugMode) {
      developer.log(
        '⚠️ $sanitizedMessage',
        name: name,
        level: 900,
      );
    }
  }

  /// Log de erro
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final sanitizedMessage = _sanitize(message);
    if (kDebugMode) {
      developer.log(
        '❌ $sanitizedMessage',
        name: name,
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }

  /// Log de evento de segurança (sempre logado, mesmo em release)
  void securityEvent(String eventType, Map<String, dynamic> details) {
    final sanitizedDetails = _sanitizeMap(details);
    developer.log(
      '🔒 SECURITY: $eventType',
      name: 'SECURITY_AUDIT',
      error: sanitizedDetails,
      level: 1200,
    );
  }
}

/// Logger global para uso rápido
final logger = SecureLogger('Totem');

/// Função de conveniência para substituir print()
/// 
/// ✅ Use: log('Mensagem')
/// ❌ Não use: print('Mensagem')
void log(String message, [Map<String, dynamic>? data]) {
  logger.debug(message, data);
}

/// Log de erro com stack trace
void logError(String message, [Object? error, StackTrace? stackTrace]) {
  logger.error(message, error, stackTrace);
}

/// Log de evento de segurança
void logSecurityEvent(String eventType, Map<String, dynamic> details) {
  logger.securityEvent(eventType, details);
}

