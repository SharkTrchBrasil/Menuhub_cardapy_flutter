// 🚨 APP EXCEPTIONS - Exceções estruturadas para o app
// =====================================================
// Substitui catch(e) genéricos por tratamento específico

/// Exceção base do app - todas as outras herdam desta
abstract class AppException implements Exception {
  /// Mensagem amigável para o usuário
  final String message;
  
  /// Código de erro para tracking
  final String? code;
  
  /// Erro original (para debugging)
  final dynamic originalError;
  
  /// Stack trace original
  final StackTrace? stackTrace;
  
  const AppException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });
  
  @override
  String toString() => 'AppException: $message (code: $code)';
  
  /// Mensagem técnica para logs
  String get technicalMessage => originalError?.toString() ?? message;
}

// ============================================
// EXCEÇÕES DE REDE
// ============================================

/// Erro de conexão com a internet
class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  /// Sem conexão com internet
  factory NetworkException.noConnection() => const NetworkException(
    'Sem conexão com a internet. Verifique sua rede.',
    code: 'NETWORK_NO_CONNECTION',
  );
  
  /// Timeout de requisição
  factory NetworkException.timeout() => const NetworkException(
    'A operação demorou muito. Tente novamente.',
    code: 'NETWORK_TIMEOUT',
  );
  
  /// Servidor indisponível
  factory NetworkException.serverUnavailable() => const NetworkException(
    'Servidor temporariamente indisponível. Tente novamente em alguns minutos.',
    code: 'NETWORK_SERVER_DOWN',
  );
}

/// Erro de resposta do servidor (4xx, 5xx)
class ServerException extends AppException {
  final int? statusCode;
  
  const ServerException(
    super.message, {
    this.statusCode,
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  /// Erro 400 - Bad Request
  factory ServerException.badRequest([String? detail]) => ServerException(
    detail ?? 'Requisição inválida.',
    statusCode: 400,
    code: 'SERVER_BAD_REQUEST',
  );
  
  /// Erro 404 - Not Found
  factory ServerException.notFound([String? resource]) => ServerException(
    resource != null ? '$resource não encontrado.' : 'Recurso não encontrado.',
    statusCode: 404,
    code: 'SERVER_NOT_FOUND',
  );
  
  /// Erro 500 - Internal Server Error
  factory ServerException.internalError() => const ServerException(
    'Erro interno do servidor. Nossa equipe foi notificada.',
    statusCode: 500,
    code: 'SERVER_INTERNAL_ERROR',
  );
  
  /// Erro 503 - Service Unavailable
  factory ServerException.serviceUnavailable() => const ServerException(
    'Serviço temporariamente indisponível.',
    statusCode: 503,
    code: 'SERVER_SERVICE_UNAVAILABLE',
  );
}

// ============================================
// EXCEÇÕES DE AUTENTICAÇÃO
// ============================================

/// Erro de autenticação/autorização
class AuthException extends AppException {
  const AuthException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  /// Credenciais inválidas
  factory AuthException.invalidCredentials() => const AuthException(
    'E-mail ou senha incorretos.',
    code: 'AUTH_INVALID_CREDENTIALS',
  );
  
  /// Sessão expirada
  factory AuthException.sessionExpired() => const AuthException(
    'Sua sessão expirou. Faça login novamente.',
    code: 'AUTH_SESSION_EXPIRED',
  );
  
  /// Token inválido
  factory AuthException.invalidToken() => const AuthException(
    'Token de autenticação inválido.',
    code: 'AUTH_INVALID_TOKEN',
  );
  
  /// Usuário não autorizado
  factory AuthException.unauthorized() => const AuthException(
    'Você não tem permissão para esta ação.',
    code: 'AUTH_UNAUTHORIZED',
  );
  
  /// Conta desativada
  factory AuthException.accountDisabled() => const AuthException(
    'Esta conta foi desativada.',
    code: 'AUTH_ACCOUNT_DISABLED',
  );
}

// ============================================
// EXCEÇÕES DE VALIDAÇÃO
// ============================================

/// Erro de validação de dados
class ValidationException extends AppException {
  /// Campo que falhou na validação
  final String? field;
  
  const ValidationException(
    super.message, {
    this.field,
    super.code,
    super.originalError,
  });
  
  /// Campo obrigatório não preenchido
  factory ValidationException.required(String fieldName) => ValidationException(
    '$fieldName é obrigatório.',
    field: fieldName,
    code: 'VALIDATION_REQUIRED',
  );
  
  /// Formato inválido
  factory ValidationException.invalidFormat(String fieldName, [String? expected]) =>
      ValidationException(
        expected != null 
            ? '$fieldName deve estar no formato: $expected'
            : 'Formato de $fieldName inválido.',
        field: fieldName,
        code: 'VALIDATION_INVALID_FORMAT',
      );
  
  /// Valor fora do intervalo permitido
  factory ValidationException.outOfRange(String fieldName, {num? min, num? max}) {
    String message;
    if (min != null && max != null) {
      message = '$fieldName deve estar entre $min e $max.';
    } else if (min != null) {
      message = '$fieldName deve ser maior que $min.';
    } else if (max != null) {
      message = '$fieldName deve ser menor que $max.';
    } else {
      message = 'Valor de $fieldName fora do intervalo permitido.';
    }
    return ValidationException(message, field: fieldName, code: 'VALIDATION_OUT_OF_RANGE');
  }
}

// ============================================
// EXCEÇÕES DE PAGAMENTO
// ============================================

/// Erro relacionado a pagamento
class PaymentException extends AppException {
  const PaymentException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  /// Pagamento recusado
  factory PaymentException.declined([String? reason]) => PaymentException(
    reason ?? 'Pagamento recusado. Tente outro método de pagamento.',
    code: 'PAYMENT_DECLINED',
  );
  
  /// Cartão inválido
  factory PaymentException.invalidCard() => const PaymentException(
    'Dados do cartão inválidos.',
    code: 'PAYMENT_INVALID_CARD',
  );
  
  /// Saldo insuficiente
  factory PaymentException.insufficientFunds() => const PaymentException(
    'Saldo insuficiente.',
    code: 'PAYMENT_INSUFFICIENT_FUNDS',
  );
  
  /// Erro no processamento
  factory PaymentException.processingError() => const PaymentException(
    'Erro ao processar pagamento. Tente novamente.',
    code: 'PAYMENT_PROCESSING_ERROR',
  );
  
  /// PIX expirado
  factory PaymentException.pixExpired() => const PaymentException(
    'O código PIX expirou. Gere um novo código.',
    code: 'PAYMENT_PIX_EXPIRED',
  );
}

// ============================================
// EXCEÇÕES DE CARRINHO/PEDIDO
// ============================================

/// Erro relacionado ao carrinho
class CartException extends AppException {
  const CartException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  /// Carrinho vazio
  factory CartException.emptyCart() => const CartException(
    'Seu carrinho está vazio.',
    code: 'CART_EMPTY',
  );
  
  /// Produto indisponível
  factory CartException.productUnavailable([String? productName]) => CartException(
    productName != null 
        ? '$productName não está mais disponível.'
        : 'Um produto do carrinho não está mais disponível.',
    code: 'CART_PRODUCT_UNAVAILABLE',
  );
  
  /// Quantidade indisponível
  factory CartException.insufficientStock([String? productName]) => CartException(
    productName != null
        ? 'Quantidade de $productName indisponível em estoque.'
        : 'Quantidade indisponível em estoque.',
    code: 'CART_INSUFFICIENT_STOCK',
  );
  
  /// Pedido mínimo não atingido
  factory CartException.minimumOrderNotMet(int minimumInCents) {
    final minimum = (minimumInCents / 100).toStringAsFixed(2);
    return CartException(
      'O pedido mínimo é R\$ $minimum.',
      code: 'CART_MINIMUM_NOT_MET',
    );
  }
  
  /// Loja fechada
  factory CartException.storeClosed() => const CartException(
    'A loja está fechada no momento.',
    code: 'CART_STORE_CLOSED',
  );
}

/// Erro relacionado ao pedido
class OrderException extends AppException {
  const OrderException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  /// Pedido não encontrado
  factory OrderException.notFound() => const OrderException(
    'Pedido não encontrado.',
    code: 'ORDER_NOT_FOUND',
  );
  
  /// Pedido já cancelado
  factory OrderException.alreadyCancelled() => const OrderException(
    'Este pedido já foi cancelado.',
    code: 'ORDER_ALREADY_CANCELLED',
  );
  
  /// Não pode cancelar (status avançado)
  factory OrderException.cannotCancel() => const OrderException(
    'Este pedido não pode mais ser cancelado.',
    code: 'ORDER_CANNOT_CANCEL',
  );
}

// ============================================
// EXCEÇÕES DE ENDEREÇO/ENTREGA
// ============================================

/// Erro relacionado a endereço/entrega
class DeliveryException extends AppException {
  const DeliveryException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  /// O restaurante não entrega neste endereço
  factory DeliveryException.outOfRange() => const DeliveryException(
    'O restaurante não realiza entregas nesta região.',
    code: 'DELIVERY_OUT_OF_RANGE',
  );
  
  /// CEP não encontrado
  factory DeliveryException.zipCodeNotFound() => const DeliveryException(
    'CEP não encontrado.',
    code: 'DELIVERY_ZIP_NOT_FOUND',
  );
  
  /// Endereço incompleto
  factory DeliveryException.incompleteAddress() => const DeliveryException(
    'Complete o endereço de entrega.',
    code: 'DELIVERY_INCOMPLETE_ADDRESS',
  );
}

// ============================================
// EXCEÇÕES DE CUPOM
// ============================================

/// Erro relacionado a cupom
class CouponException extends AppException {
  const CouponException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  /// Cupom inválido
  factory CouponException.invalid() => const CouponException(
    'Cupom inválido.',
    code: 'COUPON_INVALID',
  );
  
  /// Cupom expirado
  factory CouponException.expired() => const CouponException(
    'Este cupom expirou.',
    code: 'COUPON_EXPIRED',
  );
  
  /// Cupom já utilizado
  factory CouponException.alreadyUsed() => const CouponException(
    'Você já utilizou este cupom.',
    code: 'COUPON_ALREADY_USED',
  );
  
  /// Valor mínimo não atingido
  factory CouponException.minimumNotMet(int minimumInCents) {
    final minimum = (minimumInCents / 100).toStringAsFixed(2);
    return CouponException(
      'Pedido mínimo de R\$ $minimum para usar este cupom.',
      code: 'COUPON_MINIMUM_NOT_MET',
    );
  }
  
  /// Cupom não aplicável
  factory CouponException.notApplicable([String? reason]) => CouponException(
    reason ?? 'Este cupom não é válido para os itens do carrinho.',
    code: 'COUPON_NOT_APPLICABLE',
  );
}

// ============================================
// EXCEÇÃO GENÉRICA (último recurso)
// ============================================

/// Erro genérico/desconhecido
class UnknownException extends AppException {
  const UnknownException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
  
  factory UnknownException.fromError(Object error, [StackTrace? stackTrace]) =>
      UnknownException(
        'Ocorreu um erro inesperado. Tente novamente.',
        code: 'UNKNOWN_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
}
















