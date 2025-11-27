/// ⚠️ ERROR HANDLING PADRONIZADO - FLUTTER
/// ========================================
/// Sistema de tratamento de erros consistente para o app.

import 'package:flutter/material.dart';

/// Códigos de erro padronizados (espelha o backend)
enum ErrorCode {
  // Geral
  internalError('INTERNAL_ERROR'),
  validationError('VALIDATION_ERROR'),
  notFound('NOT_FOUND'),
  unauthorized('UNAUTHORIZED'),
  forbidden('FORBIDDEN'),
  rateLimited('RATE_LIMITED'),
  serviceUnavailable('SERVICE_UNAVAILABLE'),
  networkError('NETWORK_ERROR'),
  timeout('TIMEOUT'),

  // Negócio
  insufficientStock('INSUFFICIENT_STOCK'),
  invalidCoupon('INVALID_COUPON'),
  couponExpired('COUPON_EXPIRED'),
  minimumOrderNotMet('MINIMUM_ORDER_NOT_MET'),
  storeClosed('STORE_CLOSED'),
  deliveryUnavailable('DELIVERY_UNAVAILABLE'),
  productUnavailable('PRODUCT_UNAVAILABLE'),

  // Pagamento
  paymentFailed('PAYMENT_FAILED'),
  paymentDeclined('PAYMENT_DECLINED'),
  invalidPaymentMethod('INVALID_PAYMENT_METHOD'),
  duplicatePayment('DUPLICATE_PAYMENT'),

  // Autenticação
  invalidCredentials('INVALID_CREDENTIALS'),
  tokenExpired('TOKEN_EXPIRED'),
  tokenInvalid('TOKEN_INVALID'),
  sessionExpired('SESSION_EXPIRED');

  final String value;
  const ErrorCode(this.value);

  static ErrorCode fromString(String value) {
    return ErrorCode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ErrorCode.internalError,
    );
  }
}

/// Exceção base da aplicação
class AppException implements Exception {
  final ErrorCode code;
  final String message;
  final Map<String, dynamic>? details;
  final int? statusCode;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
    this.originalError,
    this.stackTrace,
  });

  /// Cria exceção a partir de resposta da API
  factory AppException.fromApiResponse(Map<String, dynamic> response, {int? statusCode}) {
    final error = response['error'] as Map<String, dynamic>?;
    
    if (error == null) {
      return AppException(
        code: ErrorCode.internalError,
        message: 'Erro desconhecido',
        statusCode: statusCode,
      );
    }

    return AppException(
      code: ErrorCode.fromString(error['code'] ?? 'INTERNAL_ERROR'),
      message: error['message'] ?? 'Erro desconhecido',
      details: error['details'] as Map<String, dynamic>?,
      statusCode: statusCode,
    );
  }

  /// Mensagem amigável para o usuário
  String get userMessage {
    switch (code) {
      case ErrorCode.networkError:
        return 'Sem conexão com a internet. Verifique sua conexão.';
      case ErrorCode.timeout:
        return 'A operação demorou muito. Tente novamente.';
      case ErrorCode.unauthorized:
      case ErrorCode.tokenExpired:
      case ErrorCode.sessionExpired:
        return 'Sua sessão expirou. Faça login novamente.';
      case ErrorCode.rateLimited:
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case ErrorCode.storeClosed:
        return 'A loja está fechada no momento.';
      case ErrorCode.insufficientStock:
        return 'Produto sem estoque disponível.';
      case ErrorCode.invalidCoupon:
        return 'Cupom inválido ou não aplicável.';
      case ErrorCode.couponExpired:
        return 'Este cupom expirou.';
      case ErrorCode.minimumOrderNotMet:
        return 'Pedido mínimo não atingido.';
      case ErrorCode.deliveryUnavailable:
        return 'Entrega não disponível para seu endereço.';
      case ErrorCode.paymentFailed:
        return 'Falha no pagamento. Tente novamente.';
      case ErrorCode.paymentDeclined:
        return 'Pagamento recusado. Verifique os dados.';
      default:
        return message;
    }
  }

  /// Ícone apropriado para o erro
  IconData get icon {
    switch (code) {
      case ErrorCode.networkError:
        return Icons.wifi_off;
      case ErrorCode.timeout:
        return Icons.timer_off;
      case ErrorCode.unauthorized:
      case ErrorCode.tokenExpired:
      case ErrorCode.sessionExpired:
        return Icons.lock;
      case ErrorCode.storeClosed:
        return Icons.store;
      case ErrorCode.insufficientStock:
        return Icons.inventory;
      case ErrorCode.paymentFailed:
      case ErrorCode.paymentDeclined:
        return Icons.payment;
      case ErrorCode.deliveryUnavailable:
        return Icons.local_shipping;
      default:
        return Icons.error_outline;
    }
  }

  /// Cor apropriada para o erro
  Color get color {
    switch (code) {
      case ErrorCode.networkError:
      case ErrorCode.timeout:
        return Colors.orange;
      case ErrorCode.unauthorized:
      case ErrorCode.forbidden:
        return Colors.red;
      case ErrorCode.storeClosed:
      case ErrorCode.deliveryUnavailable:
        return Colors.grey;
      case ErrorCode.paymentFailed:
      case ErrorCode.paymentDeclined:
        return Colors.red;
      default:
        return Colors.red;
    }
  }

  /// Se o erro é recuperável (pode tentar novamente)
  bool get isRetryable {
    switch (code) {
      case ErrorCode.networkError:
      case ErrorCode.timeout:
      case ErrorCode.serviceUnavailable:
      case ErrorCode.internalError:
        return true;
      default:
        return false;
    }
  }

  /// Se deve fazer logout
  bool get requiresLogout {
    switch (code) {
      case ErrorCode.unauthorized:
      case ErrorCode.tokenExpired:
      case ErrorCode.tokenInvalid:
      case ErrorCode.sessionExpired:
        return true;
      default:
        return false;
    }
  }

  @override
  String toString() => 'AppException(${code.value}): $message';
}

// ═══════════════════════════════════════════════════════════
// EXCEÇÕES ESPECÍFICAS
// ═══════════════════════════════════════════════════════════

class NetworkException extends AppException {
  const NetworkException({String? message})
      : super(
          code: ErrorCode.networkError,
          message: message ?? 'Erro de conexão',
        );
}

class TimeoutException extends AppException {
  const TimeoutException({String? message})
      : super(
          code: ErrorCode.timeout,
          message: message ?? 'Tempo esgotado',
        );
}

class UnauthorizedException extends AppException {
  const UnauthorizedException({String? message})
      : super(
          code: ErrorCode.unauthorized,
          message: message ?? 'Não autorizado',
        );
}

class PaymentException extends AppException {
  const PaymentException({
    ErrorCode code = ErrorCode.paymentFailed,
    required String message,
    Map<String, dynamic>? details,
  }) : super(code: code, message: message, details: details);
}

class ValidationException extends AppException {
  final String? field;

  const ValidationException({
    required String message,
    this.field,
    Map<String, dynamic>? details,
  }) : super(
          code: ErrorCode.validationError,
          message: message,
          details: details,
        );
}

// ═══════════════════════════════════════════════════════════
// ERROR HANDLER GLOBAL
// ═══════════════════════════════════════════════════════════

class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// Callback para erros que requerem logout
  void Function()? onLogoutRequired;

  /// Callback para mostrar erro ao usuário
  void Function(AppException error)? onShowError;

  /// Trata exceção e retorna AppException
  AppException handle(dynamic error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      _processError(error);
      return error;
    }

    // Converte erros comuns
    AppException appError;

    if (error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused')) {
      appError = const NetworkException();
    } else if (error.toString().contains('TimeoutException')) {
      appError = const TimeoutException();
    } else {
      appError = AppException(
        code: ErrorCode.internalError,
        message: 'Erro inesperado. Tente novamente.',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    _processError(appError);
    return appError;
  }

  void _processError(AppException error) {
    // Log do erro (usar SecureLogger em produção)
    debugPrint('🔴 ${error.code.value}: ${error.message}');

    // Verifica se precisa fazer logout
    if (error.requiresLogout && onLogoutRequired != null) {
      onLogoutRequired!();
    }

    // Mostra erro ao usuário se callback configurado
    if (onShowError != null) {
      onShowError!(error);
    }
  }
}

/// Instância global
final errorHandler = ErrorHandler();

// ═══════════════════════════════════════════════════════════
// WIDGETS DE ERRO
// ═══════════════════════════════════════════════════════════

/// Widget para exibir erro com retry
class ErrorView extends StatelessWidget {
  final AppException error;
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(error.icon, size: 64, color: error.color),
            const SizedBox(height: 16),
            Text(
              error.userMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (error.isRetryable && onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// SnackBar para erros
void showErrorSnackBar(BuildContext context, AppException error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(error.icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(error.userMessage)),
        ],
      ),
      backgroundColor: error.color,
      behavior: SnackBarBehavior.floating,
      action: error.isRetryable
          ? SnackBarAction(
              label: 'Tentar',
              textColor: Colors.white,
              onPressed: () {
                // Implementar retry se necessário
              },
            )
          : null,
    ),
  );
}

