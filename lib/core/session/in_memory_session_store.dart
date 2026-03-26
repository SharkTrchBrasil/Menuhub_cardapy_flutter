/// ✅ STATELESS AUTH: Sessão em memória para autenticação do Totem
///
/// Mantém tokens de acesso da LOJA apenas em variáveis Dart (RAM).
/// NÃO persiste em localStorage, sessionStorage, cookies ou FlutterSecureStorage.
///
/// MOTIVO: O Totem é acessado via URL pública (como iFood, Anota AI).
/// Qualquer pessoa com o link deve conseguir acessar sem bloqueio,
/// independente de aba anônima, dispositivo diferente ou link compartilhado.
///
/// Ao fechar a aba, a sessão some. Próximo acesso re-autentica pela URL.
class InMemorySessionStore {
  // ═══════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════
  InMemorySessionStore._();
  static final InMemorySessionStore instance = InMemorySessionStore._();

  // ═══════════════════════════════════════════════════════════
  // STORE AUTH TOKENS (loja/menu — obtidos via /auth/subdomain)
  // ═══════════════════════════════════════════════════════════
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiration;
  String? _storeUrl;
  String? _storeName;
  int? _storeId;
  String? _connectionToken;

  // ═══════════════════════════════════════════════════════════
  // CUSTOMER AUTH TOKENS (login Google — separado da loja)
  // ═══════════════════════════════════════════════════════════
  String? _customerAccessToken;
  String? _customerRefreshToken;
  DateTime? _customerTokenExpiration;

  // ═══════════════════════════════════════════════════════════
  // GETTERS — Store Auth
  // ═══════════════════════════════════════════════════════════
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  DateTime? get tokenExpiration => _tokenExpiration;
  String? get storeUrl => _storeUrl;
  String? get storeName => _storeName;
  int? get storeId => _storeId;
  String? get connectionToken => _connectionToken;

  bool get hasValidStoreToken {
    if (_accessToken == null || _tokenExpiration == null) return false;
    return _tokenExpiration!.isAfter(DateTime.now().add(const Duration(minutes: 1)));
  }

  // ═══════════════════════════════════════════════════════════
  // GETTERS — Customer Auth
  // ═══════════════════════════════════════════════════════════
  String? get customerAccessToken => _customerAccessToken;
  String? get customerRefreshToken => _customerRefreshToken;
  DateTime? get customerTokenExpiration => _customerTokenExpiration;

  bool get hasValidCustomerToken {
    if (_customerAccessToken == null || _customerTokenExpiration == null) return false;
    return _customerTokenExpiration!.isAfter(DateTime.now().add(const Duration(minutes: 1)));
  }

  // ═══════════════════════════════════════════════════════════
  // SETTERS — Store Auth
  // ═══════════════════════════════════════════════════════════
  void setStoreSession({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    required String storeUrl,
    required String storeName,
    required int storeId,
    required String connectionToken,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokenExpiration = DateTime.now().add(Duration(seconds: expiresIn));
    _storeUrl = storeUrl;
    _storeName = storeName;
    _storeId = storeId;
    _connectionToken = connectionToken;
  }

  void updateStoreTokens({
    required String accessToken,
    String? refreshToken,
    required int expiresIn,
  }) {
    _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;
    _tokenExpiration = DateTime.now().add(Duration(seconds: expiresIn));
  }

  // ═══════════════════════════════════════════════════════════
  // SETTERS — Customer Auth
  // ═══════════════════════════════════════════════════════════
  void setCustomerSession({
    required String accessToken,
    String? refreshToken,
    required int expiresIn,
  }) {
    _customerAccessToken = accessToken;
    if (refreshToken != null) _customerRefreshToken = refreshToken;
    _customerTokenExpiration = DateTime.now().add(Duration(seconds: expiresIn));
  }

  void updateCustomerTokens({
    required String accessToken,
    String? refreshToken,
    required int expiresIn,
  }) {
    _customerAccessToken = accessToken;
    if (refreshToken != null) _customerRefreshToken = refreshToken;
    _customerTokenExpiration = DateTime.now().add(Duration(seconds: expiresIn));
  }

  // ═══════════════════════════════════════════════════════════
  // CLEAR
  // ═══════════════════════════════════════════════════════════
  void clearStoreSession() {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiration = null;
    _storeUrl = null;
    _storeName = null;
    _storeId = null;
    _connectionToken = null;
  }

  void clearCustomerSession() {
    _customerAccessToken = null;
    _customerRefreshToken = null;
    _customerTokenExpiration = null;
  }

  void clearAll() {
    clearStoreSession();
    clearCustomerSession();
  }
}
