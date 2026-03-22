// CHANGELOG:
// [2026-03-22] CREATED — Web-specific reconnect strategy for Totem (Flutter Web).
//   - No dart:io dependency (Platform not available in web)
//   - Optimized for browser environment (tab visibility, network stability)
//   - Faster timings than mobile (web has lower latency)
//   - Tab visibility as proxy for "background" detection

/// Estratégia de reconexão para ambiente WEB (Flutter Web)
/// 
/// Diferenças vs Mobile/Desktop:
/// - Sem dart:io.Platform (não disponível em web)
/// - Latência de rede geralmente menor (WiFi corporativo)
/// - Tab visibility como proxy de "background"
/// - Sem Android Doze ou Desktop sleep
/// - Browsers mantêm conexões mais tempo que mobile
abstract class WebReconnectStrategy {
  /// Intervalo entre PINGs (18s — mais agressivo que mobile)
  Duration get pingInterval;
  
  /// Timeout para receber PONG (6s — rede web mais estável)
  Duration get pongTimeout;
  
  /// Máximo de falhas consecutivas antes de considerar morto (3)
  int get maxConsecutiveFailures;
  
  /// Cooldown após tab voltar a visible (5s — menor que desktop)
  Duration get resumeCooldown;
  
  /// Máximo de tempo em background antes de forçar full reconnect (120s)
  Duration get maxSafeBackgroundDuration;
  
  /// Delay após ganhar conectividade (500ms — web é rápido)
  Duration connectivityGainDelay();
}

/// Implementação padrão para ambiente web
/// 
/// Timings otimizados para browser:
/// - pingInterval: 18s (vs 20s desktop, 18s Android)
/// - pongTimeout: 6s (vs 10s desktop, 8s Android)
/// - maxSafeBackgroundDuration: 120s (vs 60s desktop, 40s Android)
/// Browsers mantêm conexões ativas por mais tempo mesmo com tab hidden
class DefaultWebStrategy implements WebReconnectStrategy {
  const DefaultWebStrategy();
  
  /// 18s: Web tem latência consistente, pode ser mais agressivo
  /// que desktop mas igual ao Android para manter consistência
  @override
  Duration get pingInterval => const Duration(seconds: 18);
  
  /// 6s: Rede web geralmente mais estável que mobile
  /// WiFi corporativo tem jitter baixo, permite timeout menor
  @override
  Duration get pongTimeout => const Duration(seconds: 6);
  
  /// 3 falhas: Detecção em ~54s (18s × 3)
  /// Bom balance entre rapidez e tolerância a picos de latência
  @override
  int get maxConsecutiveFailures => 3;
  
  /// 5s: Tab visibility muda rápido, cooldown menor
  /// Usuário pode voltar à tab rapidamente após Alt+Tab
  @override
  Duration get resumeCooldown => const Duration(seconds: 5);
  
  /// 120s: Browsers mantêm conexões WebSocket ativas por muito tempo
  /// mesmo com tab hidden. 2min é conservador para redes corporativas
  @override
  Duration get maxSafeBackgroundDuration => const Duration(seconds: 120);
  
  /// 500ms: Web tem conectividade quase instantânea
  /// Não há handshake wireless como em mobile
  @override
  Duration connectivityGainDelay() => const Duration(milliseconds: 500);
}

/// Factory para criar estratégia web
/// 
/// Uso:
/// ```dart
/// final strategy = createWebStrategy();
/// final heartbeat = HeartbeatManager(strategy: strategy, ...);
/// ```
WebReconnectStrategy createWebStrategy() => const DefaultWebStrategy();
