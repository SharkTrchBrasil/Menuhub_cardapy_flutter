import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// ✅ AppLogger - Sistema de Logging Completo com Sentry/Crashlytics
///
/// Features implementadas:
/// - ✅ Logging estruturado com níveis
/// - ✅ Integração com Sentry para erros
/// - ✅ Integração com Crashlytics para crashes
/// - ✅ Firebase Analytics para eventos
/// - ✅ Sanitização automática de dados sensíveis
/// - ✅ Performance tracking
/// - ✅ Contexto de usuário e sessão
/// - ✅ Configuração por ambiente

enum LogLevel { debug, info, success, warning, error, fatal }

class AppLogger {
  static bool _isInitialized = false;
  static LogLevel _currentLogLevel = LogLevel.info;
  static bool _enableConsoleLogging = true;
  static bool _enableSentry = true;
  static bool _enableCrashlytics = true;
  static bool _enableAnalytics = true;

  // Contexto da aplicação
  static String? _currentUserId;
  static String? _currentStoreId;
  static String? _sessionId;
  static Map<String, dynamic> _globalContext = {};

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🔥 INICIALIZAÇÃO
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Inicializa o sistema de logging com configurações adequadas
  static Future<void> initialize({
    LogLevel minLevel = LogLevel.info,
    bool enableConsoleLogging = true,
    bool enableSentry = true,
    bool enableCrashlytics = true,
    bool enableAnalytics = true,
    String environment = 'production',
    String? dsn,
  }) async {
    if (_isInitialized) return;

    _currentLogLevel = minLevel;
    _enableConsoleLogging = enableConsoleLogging;
    _enableSentry = enableSentry;
    _enableCrashlytics = enableCrashlytics;
    _enableAnalytics = enableAnalytics;

    // Gera ID de sessão único
    _sessionId = _generateSessionId();

    try {
      // Inicializa Sentry
      if (_enableSentry && dsn != null) {
        try {
          await SentryFlutter.init((options) {
            options.dsn = dsn;
            options.environment = environment;
            options.tracesSampleRate = kDebugMode ? 1.0 : 0.1;
            options.debug = kDebugMode;
            options.beforeSend = _beforeSendSentry;
            options.attachStacktrace = true;
          });

          // Define contexto inicial
          Sentry.configureScope((scope) {
            scope.setTag('platform', kIsWeb ? 'web' : 'mobile');
            scope.setTag('version', _getAppVersion());
            scope.setTag('build_number', _getBuildNumber());
            scope.setTag('session_id', _sessionId!);
          });
        } catch (e) {
          dev.log('⚠️ Sentry initialization failed: $e');
          _enableSentry = false;
        }
      }

      // Inicializa Crashlytics (Apenas Mobile)
      if (_enableCrashlytics && !kIsWeb) {
        try {
          await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
            true,
          );

          // Configura contexto no Crashlytics
          await FirebaseCrashlytics.instance.setCustomKey('platform', 'mobile');
          await FirebaseCrashlytics.instance.setCustomKey(
            'version',
            _getAppVersion(),
          );
          await FirebaseCrashlytics.instance.setCustomKey(
            'session_id',
            _sessionId!,
          );
        } catch (e) {
          dev.log('⚠️ Crashlytics initialization failed: $e');
          _enableCrashlytics = false;
        }
      }

      // Inicializa Analytics
      if (_enableAnalytics && !kDebugMode) {
        try {
          await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
        } catch (e) {
          dev.log('⚠️ Analytics initialization failed: $e');
          _enableAnalytics = false;
        }
      }

      _isInitialized = true;

      i(
        '✅ AppLogger initialized',
        extras: {
          'environment': environment,
          'sentry': _enableSentry,
          'crashlytics': _enableCrashlytics && !kIsWeb,
          'analytics': _enableAnalytics,
          'session_id': _sessionId,
        },
      );
    } catch (e) {
      // Fallback se inicialização falhar - NÃO propaga erro
      dev.log(
        '⚠️ AppLogger partially initialized (some services may be disabled): $e',
      );
      _isInitialized = true; // Marca como inicializado mesmo parcialmente
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🔥 MÉTODOS DE LOGGING (ALIASED)
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Log de nível DEBUG
  static void d(String message, {Map<String, dynamic>? extras, String? tag}) =>
      debug(message, extras: extras, tag: tag);
  static void debug(
    String message, {
    Map<String, dynamic>? extras,
    String? tag,
  }) {
    final Map<String, dynamic> allExtras = extras ?? {};
    if (tag != null) allExtras['tag'] = tag;
    _log(LogLevel.debug, message, allExtras);
  }

  /// Log de nível INFO
  static void i(String message, {Map<String, dynamic>? extras, String? tag}) =>
      info(message, extras: extras, tag: tag);
  static void info(
    String message, {
    Map<String, dynamic>? extras,
    String? tag,
  }) {
    final Map<String, dynamic> allExtras = extras ?? {};
    if (tag != null) allExtras['tag'] = tag;
    _log(LogLevel.info, message, allExtras);
  }

  /// Log de nível SUCCESS
  static void s(String message, {Map<String, dynamic>? extras, String? tag}) =>
      success(message, extras: extras, tag: tag);
  static void success(
    String message, {
    Map<String, dynamic>? extras,
    String? tag,
  }) {
    final Map<String, dynamic> allExtras = extras ?? {};
    if (tag != null) allExtras['tag'] = tag;
    _log(LogLevel.success, message, allExtras);
  }

  /// Log de nível WARNING
  static void w(String message, {Map<String, dynamic>? extras, String? tag}) =>
      warning(message, extras: extras, tag: tag);
  static void warning(
    String message, {
    Map<String, dynamic>? extras,
    String? tag,
  }) {
    final Map<String, dynamic> allExtras = extras ?? {};
    if (tag != null) allExtras['tag'] = tag;
    _log(LogLevel.warning, message, allExtras);
  }

  /// Log de nível ERROR
  static void e(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
    String? tag,
  }) => AppLogger.error(
    message,
    error: error,
    stackTrace: stackTrace,
    extras: extras,
    tag: tag,
  );
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
    String? tag,
  }) {
    final Map<String, dynamic> allExtras = extras ?? {};
    if (tag != null) allExtras['tag'] = tag;
    _log(LogLevel.error, message, allExtras, error, stackTrace);
  }

  /// Log de nível FATAL
  static void f(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
    String? tag,
  }) => fatal(
    message,
    error: error,
    stackTrace: stackTrace,
    extras: extras,
    tag: tag,
  );
  static void fatal(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
    String? tag,
  }) {
    final Map<String, dynamic> allExtras = extras ?? {};
    if (tag != null) allExtras['tag'] = tag;
    _log(LogLevel.fatal, message, allExtras, error, stackTrace);
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🔥 MÉTODOS DE CONTEXTO
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Define o contexto do usuário atual
  static Future<void> setUserContext({
    String? userId,
    String? email,
    String? storeId,
    Map<String, dynamic>? extras,
  }) async {
    _currentUserId = userId;
    _currentStoreId = storeId;

    if (extras != null) {
      _globalContext.addAll(extras);
    }

    // Atualiza contexto no Sentry
    if (_enableSentry && _isInitialized) {
      Sentry.configureScope((scope) {
        if (userId != null) {
          scope.setUser(SentryUser(id: userId, email: email));
        }
        if (storeId != null) {
          scope.setTag('store_id', storeId);
        }
        if (extras != null) {
          extras.forEach((key, value) {
            scope.setTag(key, value.toString());
          });
        }
      });
    }

    // Atualiza contexto no Crashlytics (Apenas Mobile)
    if (_enableCrashlytics && _isInitialized && !kIsWeb) {
      if (userId != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      }
      if (email != null) {
        await FirebaseCrashlytics.instance.setCustomKey('user_email', email);
      }
      if (storeId != null) {
        await FirebaseCrashlytics.instance.setCustomKey('store_id', storeId);
      }
      if (extras != null) {
        extras.forEach((key, value) {
          FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
        });
      }
    }
  }

  /// Limpa o contexto do usuário
  static void clearUserContext() {
    _currentUserId = null;
    _currentStoreId = null;
    _globalContext.clear();

    if (_enableSentry && _isInitialized) {
      Sentry.configureScope((scope) {
        scope.setUser(null);
      });
    }

    if (_enableCrashlytics && _isInitialized && !kIsWeb) {
      FirebaseCrashlytics.instance.setUserIdentifier('');
    }
  }

  /// Adiciona tags globais
  static void setGlobalTags(Map<String, String> tags) {
    _globalContext.addAll(tags);

    if (_enableSentry && _isInitialized) {
      Sentry.configureScope((scope) {
        tags.forEach((key, value) {
          scope.setTag(key, value);
        });
      });
    }

    if (_enableCrashlytics && _isInitialized && !kIsWeb) {
      tags.forEach((key, value) {
        FirebaseCrashlytics.instance.setCustomKey(key, value);
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🔥 MÉTODOS DE ANALYTICS
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Rastreia evento de analytics
  static void trackEvent(String name, [Map<String, dynamic>? parameters]) {
    if (!_enableAnalytics || kDebugMode) return;

    try {
      final sanitizedParams = _sanitizeAnalyticsData(parameters);

      FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: sanitizedParams.cast<String, Object>(),
      );

      // Adiciona ao Sentry como breadcrumb
      if (_enableSentry && _isInitialized) {
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: name,
            category: 'analytics',
            data: sanitizedParams,
          ),
        );
      }
    } catch (e) {
      dev.log('❌ Failed to track analytics event: $e');
    }
  }

  /// Rastreia erro de forma manual
  static void reportError(
    Object error, [
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
    bool fatal = false,
  ]) {
    if (!_isInitialized) return;

    try {
      final sanitizedExtras = _sanitizeErrorData(extras);

      // Envia para Sentry
      if (_enableSentry) {
        final level = fatal ? SentryLevel.fatal : SentryLevel.error;
        Sentry.captureException(
          error,
          stackTrace: stackTrace,
          withScope: (scope) => scope.level = level,
        );

        // Adiciona contexto extra
        if (sanitizedExtras.isNotEmpty) {
          Sentry.configureScope((scope) {
            sanitizedExtras.forEach((key, value) {
              scope.setExtra(key, value);
            });
          });
        }
      }

      // Envia para Crashlytics (Apenas Mobile)
      if (_enableCrashlytics && !kIsWeb) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: fatal,
          information:
              sanitizedExtras.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .toList(),
        );
      }
    } catch (e) {
      dev.log('❌ Failed to report error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🔥 MÉTODO PRINCIPAL DE LOGGING
  // ═══════════════════════════════════════════════════════════════════════════════

  static void _log(
    LogLevel level,
    String message,
    Map<String, dynamic>? extras, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    // Verifica se deve logar neste nível
    if (level.index < _currentLogLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final sanitizedMessage = _sanitizeLogMessage(message);
    final sanitizedExtras = _sanitizeErrorData(extras);

    // Console logging
    if (_enableConsoleLogging) {
      _logToConsole(level, timestamp, sanitizedMessage, sanitizedExtras, error);
    }

    // Envia para serviços de monitoramento apenas para erros
    if (level.index >= LogLevel.error.index) {
      _reportToMonitoring(
        sanitizedMessage,
        error,
        stackTrace,
        sanitizedExtras,
        level == LogLevel.fatal,
      );
    }

    // Adiciona breadcrumb no Sentry para eventos importantes
    if (_enableSentry &&
        _isInitialized &&
        level.index >= LogLevel.warning.index) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: sanitizedMessage,
          category: 'app',
          level: _mapLogLevelToSentry(level),
          data: sanitizedExtras,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🔥 MÉTODOS PRIVADOS
  // ═══════════════════════════════════════════════════════════════════════════════

  static void _logToConsole(
    LogLevel level,
    String timestamp,
    String message,
    Map<String, dynamic>? extras,
    Object? error,
  ) {
    final levelStr = level.name.toUpperCase();
    final extrasStr = extras?.isNotEmpty == true ? ' | $extras' : '';
    final errorStr = error != null ? ' | Error: $error' : '';

    final logMessage = '[$timestamp] $levelStr: $message$extrasStr$errorStr';

    switch (level) {
      case LogLevel.debug:
        dev.log(logMessage);
        break;
      case LogLevel.info:
        dev.log(logMessage);
        break;
      case LogLevel.success:
        dev.log('✅ $logMessage');
        break;
      case LogLevel.warning:
        dev.log('⚠️ $logMessage');
        break;
      case LogLevel.error:
        dev.log('❌ $logMessage');
        break;
      case LogLevel.fatal:
        dev.log('🔴 FATAL: $logMessage');
        break;
    }
  }

  static void _reportToMonitoring(
    String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
    bool isFatal,
  ) {
    if (!_isInitialized) return;

    try {
      // Envia para Sentry
      if (_enableSentry) {
        final level = isFatal ? SentryLevel.fatal : SentryLevel.error;
        Sentry.captureException(
          error ?? Exception(message),
          stackTrace: stackTrace,
          withScope: (scope) => scope.level = level,
        );

        if (extras?.isNotEmpty == true) {
          Sentry.configureScope((scope) {
            extras?.forEach((key, value) {
              scope.setExtra(key, value);
            });
          });
        }
      }

      // Envia para Crashlytics (Apenas Mobile)
      if (_enableCrashlytics && !kIsWeb) {
        final errorToReport = error ?? Exception(message);

        FirebaseCrashlytics.instance.recordError(
          errorToReport,
          stackTrace,
          fatal: isFatal,
          information:
              extras?.entries.map((e) => '${e.key}: ${e.value}').toList() ?? [],
        );
      }
    } catch (e) {
      dev.log('❌ Failed to report to monitoring: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🔥 MÉTODOS DE SANITIZAÇÃO
  // ═══════════════════════════════════════════════════════════════════════════════

  static String _sanitizeLogMessage(String message) {
    // Remove informações sensíveis
    return message
        .replaceAll(
          RegExp(r'password[=:]\s*\S+', caseSensitive: false),
          'password=***',
        )
        .replaceAll(
          RegExp(r'token[=:]\s*\S+', caseSensitive: false),
          'token=***',
        )
        .replaceAll(RegExp(r'key[=:]\s*\S+', caseSensitive: false), 'key=***')
        .replaceAll(
          RegExp(r'secret[=:]\s*\S+', caseSensitive: false),
          'secret=***',
        );
  }

  static Map<String, dynamic> _sanitizeErrorData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return {};

    final sanitized = <String, dynamic>{};

    data.forEach((key, value) {
      final sanitizedKey = _sanitizeKey(key);
      final sanitizedValue = _sanitizeValue(value);

      if (sanitizedKey.isNotEmpty && sanitizedValue != null) {
        sanitized[sanitizedKey] = sanitizedValue;
      }
    });

    return sanitized;
  }

  static Map<String, dynamic> _sanitizeAnalyticsData(
    Map<String, dynamic>? data,
  ) {
    if (data == null || data.isEmpty) return {};

    final sanitized = <String, dynamic>{};

    data.forEach((key, value) {
      // Para analytics, remove apenas dados muito sensíveis
      if (key.toLowerCase().contains('password') ||
          key.toLowerCase().contains('token') ||
          key.toLowerCase().contains('secret')) {
        return; // Ignora campos sensíveis
      }

      sanitized[_sanitizeKey(key)] = _sanitizeValue(value);
    });

    return sanitized;
  }

  static String _sanitizeKey(String key) {
    final sanitized = key.replaceAll(RegExp(r'[^\w\-_.]'), '');
    if (sanitized.isEmpty) return 'unknown_key';
    return sanitized.length > 32 ? sanitized.substring(0, 32) : sanitized;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      // Limita tamanho de strings
      final sanitized =
          value.length > 1000 ? '${value.substring(0, 1000)}...' : value;
      return _sanitizeLogMessage(sanitized);
    }

    if (value is Map) {
      final sanitized = <String, dynamic>{};
      value.forEach((k, v) {
        sanitized[_sanitizeKey(k.toString())] = _sanitizeValue(v);
      });
      return sanitized;
    }

    if (value is List) {
      return value
          .take(10)
          .map((item) => _sanitizeValue(item))
          .where((item) => item != null)
          .toList();
    }

    return value;
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // 🔥 UTILITÁRIOS
  // ═══════════════════════════════════════════════════════════════════════════════

  static String _generateSessionId() {
    final now = DateTime.now();
    final ms = now.millisecondsSinceEpoch;
    final us = (now.microsecond).toString().padLeft(6, '0');
    return '$ms-$us';
  }

  static String _getAppVersion() {
    // TODO: Obter do package_info
    return '1.0.0';
  }

  static String _getBuildNumber() {
    // TODO: Obter do package_info
    return '1';
  }

  static SentryLevel _mapLogLevelToSentry(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return SentryLevel.debug;
      case LogLevel.info:
        return SentryLevel.info;
      case LogLevel.success:
        return SentryLevel.info;
      case LogLevel.warning:
        return SentryLevel.warning;
      case LogLevel.error:
        return SentryLevel.error;
      case LogLevel.fatal:
        return SentryLevel.fatal;
    }
  }

  static FutureOr<SentryEvent?> _beforeSendSentry(
    SentryEvent event,
    Hint hint,
  ) {
    // Filtra eventos em modo debug
    if (kDebugMode) {
      return null;
    }

    // Remove dados sensíveis
    if (event.exceptions != null && event.exceptions!.isNotEmpty) {
      final message = _sanitizeLogMessage(event.exceptions!.first.value ?? '');

      // SentryException properties are final, we must replace the list
      final exceptions = List<SentryException>.from(event.exceptions!);
      exceptions[0] = exceptions[0].copyWith(value: message);

      return event.copyWith(exceptions: exceptions);
    }

    return event;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🔥 EXTENSIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Extension para medir tempo de execução com logging
extension LoggedExecution<T> on Future<T> {
  /// Executa e loga o tempo de execução
  Future<T> logged(String operation, {String? tag}) async {
    final stopwatch = Stopwatch()..start();

    try {
      AppLogger.d('Starting operation: $operation');

      final result = await this;

      stopwatch.stop();
      AppLogger.i(
        'Operation completed: $operation',
        extras: {'duration_ms': stopwatch.elapsedMilliseconds, 'tag': tag},
      );

      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      AppLogger.e(
        'Operation failed: $operation',
        error: error,
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }
}

/// Extension para logging em operações síncronas
extension LoggedSyncExecution<T> on T Function() {
  T logged(String operation, {String? tag}) {
    final stopwatch = Stopwatch()..start();

    try {
      AppLogger.d('Starting operation: $operation');

      final result = this();

      stopwatch.stop();
      AppLogger.i(
        'Operation completed: $operation',
        extras: {'duration_ms': stopwatch.elapsedMilliseconds, 'tag': tag},
      );

      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      AppLogger.e(
        'Operation failed: $operation',
        error: error,
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }
}
