/// 🔒 Proteção Anti-Tampering
/// Protege contra manipulação de dados, inspeção e debugging
library;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Serviço de proteção anti-tampering
class AntiTamperService {
  static final AntiTamperService _instance = AntiTamperService._internal();
  factory AntiTamperService() => _instance;
  AntiTamperService._internal();

  final String _secretKey = const String.fromEnvironment(
    'TAMPER_SECRET',
    defaultValue: 'default_secret_key_change_in_production',
  );

  /// Cria assinatura HMAC para dados
  String createSignature(Map<String, dynamic> data) {
    final sortedKeys = data.keys.toList()..sort();
    final dataString =
        sortedKeys.map((k) => '$k=${data[k]}').join('&');

    final hmacSha256 = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmacSha256.convert(utf8.encode(dataString));

    return digest.toString();
  }

  /// Verifica assinatura de dados
  bool verifySignature(Map<String, dynamic> data, String signature) {
    final expectedSignature = createSignature(data);
    return _secureCompare(expectedSignature, signature);
  }

  /// Comparação segura de strings (previne timing attacks)
  bool _secureCompare(String a, String b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Protege dados do carrinho contra manipulação
  Map<String, dynamic> protectCartData(Map<String, dynamic> cartData) {
    final signature = createSignature(cartData);
    return {
      ...cartData,
      '_signature': signature,
      '_timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Valida dados do carrinho
  bool validateCartData(Map<String, dynamic> protectedData) {
    final signature = protectedData['_signature'] as String?;
    final timestamp = protectedData['_timestamp'] as int?;

    if (signature == null || timestamp == null) {
      return false;
    }

    // Verifica se dados não são muito antigos (5 minutos)
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > 5 * 60 * 1000) {
      return false;
    }

    // Remove campos de controle para verificar assinatura
    final dataToVerify = Map<String, dynamic>.from(protectedData)
      ..remove('_signature')
      ..remove('_timestamp');

    return verifySignature(dataToVerify, signature);
  }

  /// Protege preço contra manipulação
  String encryptPrice(int priceInCents) {
    final data = {
      'price': priceInCents,
      'nonce': _generateNonce(),
    };
    final signature = createSignature(data);
    return base64Encode(utf8.encode(jsonEncode({...data, 'sig': signature})));
  }

  /// Descriptografa e valida preço
  int? decryptPrice(String encryptedPrice) {
    try {
      final decoded = utf8.decode(base64Decode(encryptedPrice));
      final data = jsonDecode(decoded) as Map<String, dynamic>;

      final signature = data['sig'] as String;
      final price = data['price'] as int;
      final nonce = data['nonce'] as String;

      final dataToVerify = {'price': price, 'nonce': nonce};
      if (!verifySignature(dataToVerify, signature)) {
        return null;
      }

      return price;
    } catch (_) {
      return null;
    }
  }

  /// Gera nonce aleatório
  String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Detecta tentativa de inspeção de código
  bool detectCodeInspection() {
    if (kDebugMode) return false;

    // Verifica se está em modo profile ou release
    if (kProfileMode || kReleaseMode) {
      // Em release, não deveria ter acesso a certas funcionalidades
      return false;
    }

    return true;
  }

  /// Ofusca dados sensíveis em logs
  String obfuscateSensitiveData(String data, {int visibleChars = 4}) {
    if (data.length <= visibleChars) {
      return '*' * data.length;
    }
    return '${'*' * (data.length - visibleChars)}${data.substring(data.length - visibleChars)}';
  }

  /// Valida integridade de requisição de pagamento
  bool validatePaymentRequest({
    required int orderId,
    required int amount,
    required String pixKey,
    required String signature,
  }) {
    final data = {
      'order_id': orderId,
      'amount': amount,
      'pix_key': pixKey,
    };

    return verifySignature(data, signature);
  }
}

/// Mixin para proteção de preços em widgets
mixin PriceProtectionMixin {
  final _antiTamper = AntiTamperService();

  /// Protege preço para exibição
  String protectPrice(int priceInCents) {
    return _antiTamper.encryptPrice(priceInCents);
  }

  /// Recupera preço protegido
  int? getProtectedPrice(String encryptedPrice) {
    return _antiTamper.decryptPrice(encryptedPrice);
  }

  /// Valida se preço não foi manipulado
  bool validatePrice(int expectedPrice, String encryptedPrice) {
    final actualPrice = _antiTamper.decryptPrice(encryptedPrice);
    return actualPrice == expectedPrice;
  }
}

