// lib/models/totem_auth.dart
class TotemAuth {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final int storeId;
  final String storeUrl;
  final String storeName;
  final List<String>? allowedDomains;

  // --- ✅ 1. CAMPO ADICIONADO ---
  // Token de uso único e curta duração para a conexão WebSocket.
  final String connectionToken;

  TotemAuth({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.storeId,
    required this.storeUrl,
    required this.storeName,
    this.allowedDomains,
    required this.connectionToken, // Adicionado ao construtor
  });

  factory TotemAuth.fromJson(Map<String, dynamic> json) {
    return TotemAuth(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
      storeId: json['store_id'] as int,
      storeUrl: json['store_url'] as String,
      storeName: json['store_name'] as String,
      allowedDomains: json['allowed_domains'] != null
          ? List<String>.from(json['allowed_domains'])
          : null,
      // --- ✅ 2. PARSE DO NOVO CAMPO ---
      // Pega o token de conexão da resposta da API.
      connectionToken: json['connection_token'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'store_id': storeId,
      'store_url': storeUrl,
      'store_name': storeName,
      'allowed_domains': allowedDomains,
      // --- ✅ 3. ADICIONADO AO JSON (opcional, mas boa prática) ---
      'connection_token': connectionToken,
    };
  }

  DateTime get expirationTime {
    return DateTime.now().add(Duration(seconds: expiresIn));
  }

  bool get isExpiringSoon {
    final expiresAt = expirationTime;
    final now = DateTime.now();
    final fiveMinutesFromNow = now.add(const Duration(minutes: 5));
    return expiresAt.isBefore(fiveMinutesFromNow);
  }
}