// 📋 APP LOGGER - Logging centralizado para produção
// =================================================
// Substitui print() por logs estruturados que:
// - Só aparecem em debug mode
// - São enviados para analytics em produção
// - Incluem contexto útil para debugging

import 'package:flutter/foundation.dart';

/// Logger centralizado para o app.
/// 
/// Em DEBUG: mostra logs coloridos no console
/// Em RELEASE: envia erros para Crashlytics/Sentry
class AppLogger {
  // Singleton
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();
  
  /// Habilita/desabilita logs (útil para testes)
  static bool enabled = true;
  
  /// Só loga em debug mode
  static bool get _shouldLog => enabled && kDebugMode;
  
  /// Log informativo (operações normais)
  /// Ex: "Usuário logado", "Carrinho atualizado"
  static void info(String message, {String? tag}) {
    if (_shouldLog) {
      debugPrint('ℹ️ [${tag ?? 'INFO'}] $message');
    }
  }
  
  /// Log de debug (detalhes técnicos)
  /// Ex: "Payload enviado: {...}", "Response recebida"
  static void debug(String message, {String? tag, Object? data}) {
    if (_shouldLog) {
      debugPrint('🔍 [${tag ?? 'DEBUG'}] $message');
      if (data != null) {
        debugPrint('   📦 Data: $data');
      }
    }
  }
  
  /// Log de warning (algo suspeito mas não crítico)
  /// Ex: "Cache expirado", "Retry automático"
  static void warning(String message, {String? tag}) {
    if (_shouldLog) {
      debugPrint('⚠️ [${tag ?? 'WARN'}] $message');
    }
  }
  
  /// Log de erro (falhas que precisam atenção)
  /// Em produção, envia para Crashlytics/Sentry
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    Map<String, dynamic>? extras,
  }) {
    if (_shouldLog) {
      debugPrint('❌ [${tag ?? 'ERROR'}] $message');
      if (error != null) {
        debugPrint('   💥 Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   📚 Stack: $stackTrace');
      }
      if (extras != null) {
        debugPrint('   📎 Extras: $extras');
      }
    }
    
    // Em produção, reporta para serviço de monitoramento
    if (!kDebugMode && error != null) {
      _reportToMonitoring(message, error, stackTrace, extras);
    }
  }
  
  /// Log de sucesso (operações concluídas)
  static void success(String message, {String? tag}) {
    if (_shouldLog) {
      debugPrint('✅ [${tag ?? 'SUCCESS'}] $message');
    }
  }
  
  /// Log de rede (requests/responses)
  static void network(
    String method,
    String url, {
    int? statusCode,
    Duration? duration,
    String? tag,
  }) {
    if (_shouldLog) {
      final status = statusCode != null ? ' → $statusCode' : '';
      final time = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
      debugPrint('🌐 [${tag ?? 'NETWORK'}] $method $url$status$time');
    }
  }
  
  /// Log de WebSocket
  static void socket(String event, {String? tag, Object? data}) {
    if (_shouldLog) {
      debugPrint('🔌 [${tag ?? 'SOCKET'}] $event');
      if (data != null) {
        debugPrint('   📦 Data: $data');
      }
    }
  }
  
  /// Log de navegação
  static void navigation(String route, {String? from, String? tag}) {
    if (_shouldLog) {
      final fromStr = from != null ? ' (de: $from)' : '';
      debugPrint('🧭 [${tag ?? 'NAV'}] → $route$fromStr');
    }
  }
  
  /// Log de performance
  static void performance(String operation, Duration duration, {String? tag}) {
    if (_shouldLog) {
      final emoji = duration.inMilliseconds > 500 ? '🐌' : '⚡';
      debugPrint('$emoji [${tag ?? 'PERF'}] $operation: ${duration.inMilliseconds}ms');
    }
  }
  
  /// Log de analytics (eventos de usuário)
  static void analytics(String event, {Map<String, dynamic>? params, String? tag}) {
    if (_shouldLog) {
      debugPrint('📊 [${tag ?? 'ANALYTICS'}] $event');
      if (params != null) {
        debugPrint('   📎 Params: $params');
      }
    }
    
    // Em produção, envia para Firebase Analytics
    if (!kDebugMode) {
      _trackAnalytics(event, params);
    }
  }
  
  // Métodos privados para integração com serviços externos
  
  static void _reportToMonitoring(
    String message,
    Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  ) {
    // TODO: Implementar integração com Sentry/Crashlytics
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
    // Sentry.captureException(error, stackTrace: stackTrace);
  }
  
  static void _trackAnalytics(String event, Map<String, dynamic>? params) {
    // TODO: Implementar integração com Firebase Analytics
    // FirebaseAnalytics.instance.logEvent(name: event, parameters: params);
  }
}

/// Extension para medir tempo de execução
extension LoggedExecution<T> on Future<T> {
  /// Executa e loga o tempo de execução
  Future<T> logged(String operation, {String? tag}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await this;
      stopwatch.stop();
      AppLogger.performance(operation, stopwatch.elapsed, tag: tag);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'Falha em $operation',
        error: e,
        stackTrace: stackTrace,
        tag: tag,
        extras: {'duration_ms': stopwatch.elapsedMilliseconds},
      );
      rethrow;
    }
  }
}
















