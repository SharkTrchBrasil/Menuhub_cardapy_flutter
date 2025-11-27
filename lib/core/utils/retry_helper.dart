/// 🔄 RETRY HELPER - RESILIÊNCIA ENTERPRISE
/// =========================================
/// Implementa retry com backoff exponencial para operações críticas.
/// Previne perda de pedidos em caso de instabilidade de rede.

import 'dart:async';
import 'dart:math';

/// Configuração de retry
class RetryConfig {
  /// Número máximo de tentativas
  final int maxAttempts;

  /// Delay inicial em milissegundos
  final int initialDelayMs;

  /// Fator de multiplicação para backoff exponencial
  final double backoffMultiplier;

  /// Delay máximo em milissegundos
  final int maxDelayMs;

  /// Adiciona jitter aleatório para evitar thundering herd
  final bool addJitter;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelayMs = 1000,
    this.backoffMultiplier = 2.0,
    this.maxDelayMs = 30000,
    this.addJitter = true,
  });

  /// Configuração para operações de pagamento (mais tentativas, delays maiores)
  static const payment = RetryConfig(
    maxAttempts: 5,
    initialDelayMs: 2000,
    backoffMultiplier: 2.0,
    maxDelayMs: 60000,
    addJitter: true,
  );

  /// Configuração para operações de pedido
  static const order = RetryConfig(
    maxAttempts: 4,
    initialDelayMs: 1500,
    backoffMultiplier: 2.0,
    maxDelayMs: 30000,
    addJitter: true,
  );

  /// Configuração para operações de rede gerais
  static const network = RetryConfig(
    maxAttempts: 3,
    initialDelayMs: 1000,
    backoffMultiplier: 2.0,
    maxDelayMs = 10000,
    addJitter: true,
  );

  /// Configuração agressiva para operações críticas
  static const critical = RetryConfig(
    maxAttempts: 5,
    initialDelayMs: 500,
    backoffMultiplier: 1.5,
    maxDelayMs = 15000,
    addJitter: true,
  );
}

/// Resultado de uma operação com retry
class RetryResult<T> {
  final T? value;
  final Object? error;
  final StackTrace? stackTrace;
  final int attempts;
  final bool success;

  const RetryResult._({
    this.value,
    this.error,
    this.stackTrace,
    required this.attempts,
    required this.success,
  });

  factory RetryResult.success(T value, int attempts) {
    return RetryResult._(
      value: value,
      attempts: attempts,
      success: true,
    );
  }

  factory RetryResult.failure(Object error, StackTrace stackTrace, int attempts) {
    return RetryResult._(
      error: error,
      stackTrace: stackTrace,
      attempts: attempts,
      success: false,
    );
  }
}

/// Helper para executar operações com retry e backoff exponencial
class RetryHelper {
  static final _random = Random();

  /// Executa uma operação com retry automático
  ///
  /// [operation] - Função assíncrona a ser executada
  /// [config] - Configuração de retry
  /// [shouldRetry] - Função opcional para determinar se deve tentar novamente
  /// [onRetry] - Callback opcional chamado antes de cada retry
  ///
  /// Retorna o resultado da operação ou lança exceção após todas as tentativas
  static Future<T> execute<T>(
    Future<T> Function() operation, {
    RetryConfig config = const RetryConfig(),
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Object error, int delayMs)? onRetry,
  }) async {
    int attempt = 0;
    Object? lastError;
    StackTrace? lastStackTrace;

    while (attempt < config.maxAttempts) {
      attempt++;

      try {
        return await operation();
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        // Verifica se deve tentar novamente
        if (shouldRetry != null && !shouldRetry(error)) {
          rethrow;
        }

        // Última tentativa - não faz retry
        if (attempt >= config.maxAttempts) {
          break;
        }

        // Calcula delay com backoff exponencial
        final baseDelay = config.initialDelayMs *
            pow(config.backoffMultiplier, attempt - 1).toInt();
        var delay = min(baseDelay, config.maxDelayMs);

        // Adiciona jitter (0-25% do delay)
        if (config.addJitter) {
          final jitter = (_random.nextDouble() * 0.25 * delay).toInt();
          delay += jitter;
        }

        // Callback de retry
        onRetry?.call(attempt, error, delay);

        // Aguarda antes de tentar novamente
        await Future.delayed(Duration(milliseconds: delay));
      }
    }

    // Todas as tentativas falharam
    throw RetryException(
      'Operação falhou após $attempt tentativas',
      lastError: lastError,
      lastStackTrace: lastStackTrace,
      attempts: attempt,
    );
  }

  /// Executa uma operação com retry e retorna um Result
  ///
  /// Nunca lança exceção, sempre retorna um RetryResult
  static Future<RetryResult<T>> executeWithResult<T>(
    Future<T> Function() operation, {
    RetryConfig config = const RetryConfig(),
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Object error, int delayMs)? onRetry,
  }) async {
    int attempt = 0;
    Object? lastError;
    StackTrace? lastStackTrace;

    while (attempt < config.maxAttempts) {
      attempt++;

      try {
        final result = await operation();
        return RetryResult.success(result, attempt);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        // Verifica se deve tentar novamente
        if (shouldRetry != null && !shouldRetry(error)) {
          return RetryResult.failure(error, stackTrace, attempt);
        }

        // Última tentativa
        if (attempt >= config.maxAttempts) {
          break;
        }

        // Calcula delay
        final baseDelay = config.initialDelayMs *
            pow(config.backoffMultiplier, attempt - 1).toInt();
        var delay = min(baseDelay, config.maxDelayMs);

        if (config.addJitter) {
          final jitter = (_random.nextDouble() * 0.25 * delay).toInt();
          delay += jitter;
        }

        onRetry?.call(attempt, error, delay);
        await Future.delayed(Duration(milliseconds: delay));
      }
    }

    return RetryResult.failure(lastError!, lastStackTrace!, attempt);
  }
}

/// Exceção lançada quando todas as tentativas falham
class RetryException implements Exception {
  final String message;
  final Object? lastError;
  final StackTrace? lastStackTrace;
  final int attempts;

  const RetryException(
    this.message, {
    this.lastError,
    this.lastStackTrace,
    required this.attempts,
  });

  @override
  String toString() => 'RetryException: $message (tentativas: $attempts)';
}

/// Extension para facilitar uso com Either
extension RetryFutureExtension<T> on Future<T> {
  /// Adiciona retry automático a qualquer Future
  Future<T> withRetry({
    RetryConfig config = const RetryConfig(),
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Object error, int delayMs)? onRetry,
  }) {
    return RetryHelper.execute(
      () => this,
      config: config,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
  }
}

