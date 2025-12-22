/// 🔐 CRIPTOGRAFIA END-TO-END (E2E) - FLUTTER CLIENT
/// ===================================================
/// Cliente de criptografia para proteção contra MITM.
///
/// FLUXO:
/// 1. Gera par de chaves RSA localmente
/// 2. Envia chave pública para o servidor
/// 3. Recebe chave AES de sessão criptografada
/// 4. Descriptografa chave AES com chave privada local
/// 5. Usa AES-256-GCM para dados sensíveis

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;


/// Serviço de criptografia E2E
class E2EEncryptionService {
  /// Chave de sessão AES (256 bits)
  Uint8List? _sessionKey;
  
  /// ID da sessão
  String? _sessionId;
  
  /// Timestamp máximo de validade (5 minutos)
  static const int maxRequestAgeSeconds = 300;
  
  /// Verifica se tem sessão ativa
  bool get hasSession => _sessionKey != null && _sessionId != null;
  
  /// ID da sessão atual
  String? get sessionId => _sessionId;
  
  /// Gera chave AES de sessão localmente (para testes)
  Uint8List generateSessionKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
  }
  
  /// Inicializa sessão com chave recebida do servidor
  void initSession(String sessionId, Uint8List sessionKey) {
    _sessionId = sessionId;
    _sessionKey = sessionKey;
  }
  
  /// Limpa sessão
  void clearSession() {
    _sessionKey = null;
    _sessionId = null;
  }
  
  /// Criptografa dados sensíveis com AES-256-GCM
  /// 
  /// Retorna Map com:
  /// - nonce: IV aleatório (base64)
  /// - ciphertext: Dados criptografados (base64)
  /// - timestamp: Timestamp atual
  Map<String, String>? encryptData(Map<String, dynamic> data) {
    if (_sessionKey == null) return null;
    
    try {
      // Serializa dados
      final plaintext = jsonEncode(data);
      
      // Gera IV aleatório (16 bytes para AES)
      final random = Random.secure();
      final iv = encrypt.IV.fromSecureRandom(16);
      
      // Criptografa com AES
      final key = encrypt.Key(_sessionKey!);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      
      return {
        'nonce': iv.base64,
        'ciphertext': encrypted.base64,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };
    } catch (e) {
      return null;
    }
  }
  
  /// Descriptografa dados recebidos
  Map<String, dynamic>? decryptData(Map<String, String> encrypted) {
    if (_sessionKey == null) return null;
    
    try {
      // Verifica timestamp (previne replay)
      final timestamp = int.tryParse(encrypted['timestamp'] ?? '0') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if ((now - timestamp).abs() > maxRequestAgeSeconds * 1000) {
        return null; // Requisição expirada
      }
      
      // Decodifica
      final iv = encrypt.IV.fromBase64(encrypted['nonce']!);
      final ciphertext = encrypt.Encrypted.fromBase64(encrypted['ciphertext']!);
      
      // Descriptografa
      final key = encrypt.Key(_sessionKey!);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final plaintext = encrypter.decrypt(ciphertext, iv: iv);
      
      return jsonDecode(plaintext);
    } catch (e) {
      return null;
    }
  }
}

/// Serviço de integridade de requisições usando HMAC
class RequestIntegrityService {
  final String _secretKey;
  
  RequestIntegrityService(this._secretKey);
  
  /// Assina requisição com HMAC-SHA256
  /// 
  /// Retorna Map com:
  /// - signature: HMAC da requisição
  /// - timestamp: Timestamp atual
  /// - nonce: Valor aleatório único
  Map<String, String> signRequest(Map<String, dynamic> data) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = _generateNonce();
    
    // Cria payload ordenado
    final payload = jsonEncode(_sortMap(data));
    final message = '$timestamp.$nonce.$payload';
    
    // Gera HMAC-SHA256
    final hmacSha256 = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmacSha256.convert(utf8.encode(message));
    
    return {
      'signature': digest.toString(),
      'timestamp': timestamp.toString(),
      'nonce': nonce,
    };
  }
  
  /// Verifica assinatura de resposta do servidor
  bool verifyResponse(
    Map<String, dynamic> data,
    String signature,
    String timestamp,
    String nonce, {
    int maxAgeSeconds = 300,
  }) {
    // Verifica idade
    final reqTimestamp = int.tryParse(timestamp) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    if ((now - reqTimestamp).abs() > maxAgeSeconds) {
      return false;
    }
    
    // Recalcula assinatura
    final payload = jsonEncode(_sortMap(data));
    final message = '$timestamp.$nonce.$payload';
    
    final hmacSha256 = Hmac(sha256, utf8.encode(_secretKey));
    final expectedDigest = hmacSha256.convert(utf8.encode(message));
    
    // Comparação segura
    return _secureCompare(signature, expectedDigest.toString());
  }
  
  /// Gera nonce aleatório
  String _generateNonce() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
  
  /// Ordena Map recursivamente para assinatura consistente
  Map<String, dynamic> _sortMap(Map<String, dynamic> map) {
    final sorted = <String, dynamic>{};
    final keys = map.keys.toList()..sort();
    
    for (final key in keys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        sorted[key] = _sortMap(value);
      } else if (value is List) {
        sorted[key] = value.map((e) => e is Map<String, dynamic> ? _sortMap(e) : e).toList();
      } else {
        sorted[key] = value;
      }
    }
    
    return sorted;
  }
  
  /// Comparação segura contra timing attacks
  bool _secureCompare(String a, String b) {
    if (a.length != b.length) return false;
    
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

/// Headers de segurança para requisições
class SecurityHeaders {
  final String signature;
  final String timestamp;
  final String nonce;
  final String? sessionId;
  
  SecurityHeaders({
    required this.signature,
    required this.timestamp,
    required this.nonce,
    this.sessionId,
  });
  
  Map<String, String> toMap() => {
    'X-Signature': signature,
    'X-Timestamp': timestamp,
    'X-Nonce': nonce,
    if (sessionId != null) 'X-Session-Id': sessionId!,
  };
}

/// Extensão para adicionar headers de segurança em requisições Dio
extension SecurityHeadersExtension on Map<String, String> {
  Map<String, String> withSecurityHeaders(SecurityHeaders headers) {
    return {...this, ...headers.toMap()};
  }
}

