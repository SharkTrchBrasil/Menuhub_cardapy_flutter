/// 🔒 Segurança de Pagamentos PIX
/// Proteção contra manipulação de chaves e valores PIX
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Tipos de chave PIX
enum PixKeyType { cpf, cnpj, email, phone, evp }

/// Resultado de validação PIX
class PixValidationResult {
  final bool isValid;
  final String? error;
  final PixKeyType? keyType;

  const PixValidationResult({
    required this.isValid,
    this.error,
    this.keyType,
  });

  factory PixValidationResult.valid(PixKeyType type) => PixValidationResult(
        isValid: true,
        keyType: type,
      );

  factory PixValidationResult.invalid(String error) => PixValidationResult(
        isValid: false,
        error: error,
      );
}

/// Serviço de segurança PIX
class PixSecurityService {
  static final PixSecurityService _instance = PixSecurityService._internal();
  factory PixSecurityService() => _instance;
  PixSecurityService._internal();

  final Set<String> _processedTxIds = {};
  final String _secretKey = const String.fromEnvironment(
    'PIX_SECRET',
    defaultValue: 'pix_secret_key_change_in_production',
  );

  /// Valida formato de chave PIX
  PixValidationResult validatePixKey(String key) {
    // Remove espaços e caracteres especiais para validação
    final cleanKey = key.trim();

    // CPF: 11 dígitos
    if (RegExp(r'^\d{11}$').hasMatch(cleanKey)) {
      if (_validateCpf(cleanKey)) {
        return PixValidationResult.valid(PixKeyType.cpf);
      }
      return PixValidationResult.invalid('CPF inválido');
    }

    // CNPJ: 14 dígitos
    if (RegExp(r'^\d{14}$').hasMatch(cleanKey)) {
      if (_validateCnpj(cleanKey)) {
        return PixValidationResult.valid(PixKeyType.cnpj);
      }
      return PixValidationResult.invalid('CNPJ inválido');
    }

    // Email
    if (RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')
        .hasMatch(cleanKey)) {
      return PixValidationResult.valid(PixKeyType.email);
    }

    // Telefone: +55 + 10 ou 11 dígitos
    if (RegExp(r'^\+55\d{10,11}$').hasMatch(cleanKey)) {
      return PixValidationResult.valid(PixKeyType.phone);
    }

    // EVP (chave aleatória): UUID
    if (RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false)
        .hasMatch(cleanKey)) {
      return PixValidationResult.valid(PixKeyType.evp);
    }

    return PixValidationResult.invalid('Formato de chave PIX inválido');
  }

  /// Valida CPF
  bool _validateCpf(String cpf) {
    // CPFs inválidos conhecidos
    final invalidCpfs = List.generate(10, (i) => '${i}' * 11);
    if (invalidCpfs.contains(cpf)) return false;

    // Validação dos dígitos verificadores
    int calcDigit(String cpf, int weight) {
      var total = 0;
      for (var i = 0; i < weight - 1; i++) {
        total += int.parse(cpf[i]) * (weight - i);
      }
      final remainder = total % 11;
      return remainder < 2 ? 0 : 11 - remainder;
    }

    if (calcDigit(cpf, 10) != int.parse(cpf[9])) return false;
    if (calcDigit(cpf, 11) != int.parse(cpf[10])) return false;

    return true;
  }

  /// Valida CNPJ
  bool _validateCnpj(String cnpj) {
    // CNPJs inválidos conhecidos
    final invalidCnpjs = List.generate(10, (i) => '${i}' * 14);
    if (invalidCnpjs.contains(cnpj)) return false;

    // Validação simplificada
    // Em produção, implementar validação completa
    return true;
  }

  /// Cria assinatura para transação PIX
  String createPixSignature({
    required String pixKey,
    required int amount,
    required String merchantId,
    required String txId,
  }) {
    final data = '$pixKey|$amount|$merchantId|$txId';
    final hmacSha256 = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmacSha256.convert(utf8.encode(data));
    return digest.toString();
  }

  /// Verifica assinatura de transação PIX
  bool verifyPixSignature({
    required String pixKey,
    required int amount,
    required String merchantId,
    required String txId,
    required String signature,
  }) {
    final expectedSignature = createPixSignature(
      pixKey: pixKey,
      amount: amount,
      merchantId: merchantId,
      txId: txId,
    );
    return _secureCompare(expectedSignature, signature);
  }

  /// Verifica se pagamento é duplicado
  bool isDuplicatePayment(String txId) {
    if (_processedTxIds.contains(txId)) {
      return true;
    }
    _processedTxIds.add(txId);
    return false;
  }

  /// Valida valor do pagamento
  bool validatePaymentAmount({
    required int orderTotal,
    required int pixAmount,
    int toleranceCents = 0,
  }) {
    return (orderTotal - pixAmount).abs() <= toleranceCents;
  }

  /// Detecta tentativa de manipulação de valor
  bool detectAmountTampering({
    required int originalAmount,
    required int receivedAmount,
  }) {
    // Valor muito menor que o esperado
    if (receivedAmount < originalAmount * 0.9) {
      return true;
    }
    return false;
  }

  /// Comparação segura de strings
  bool _secureCompare(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Mascara chave PIX para exibição
  String maskPixKey(String key, PixKeyType type) {
    switch (type) {
      case PixKeyType.cpf:
        return '***.***.${key.substring(6, 9)}-**';
      case PixKeyType.cnpj:
        return '**.***.***/****-${key.substring(12)}';
      case PixKeyType.email:
        final parts = key.split('@');
        if (parts.length != 2) return '***@***';
        final name = parts[0];
        final domain = parts[1];
        return '${name.substring(0, 2)}***@$domain';
      case PixKeyType.phone:
        return '+55 ** *****-${key.substring(key.length - 4)}';
      case PixKeyType.evp:
        return '${key.substring(0, 8)}-****-****-****-************';
    }
  }

  /// Limpa cache de transações processadas (para testes)
  void clearProcessedTransactions() {
    _processedTxIds.clear();
  }
}

/// Dados de transação PIX protegidos
class SecurePixTransaction {
  final String txId;
  final String pixKey;
  final int amount;
  final String merchantId;
  final String signature;
  final DateTime createdAt;

  SecurePixTransaction({
    required this.txId,
    required this.pixKey,
    required this.amount,
    required this.merchantId,
    required this.signature,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Verifica se transação é válida
  bool isValid() {
    final service = PixSecurityService();
    return service.verifyPixSignature(
      pixKey: pixKey,
      amount: amount,
      merchantId: merchantId,
      txId: txId,
      signature: signature,
    );
  }

  /// Verifica se transação expirou (5 minutos)
  bool isExpired() {
    return DateTime.now().difference(createdAt).inMinutes > 5;
  }
}

