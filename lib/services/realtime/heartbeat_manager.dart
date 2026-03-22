// CHANGELOG:
// [2026-03-22] REWRITTEN — Web-aware heartbeat with generation counter and tab visibility.
//   - Receives WebReconnectStrategy for web-specific timings.
//   - Generation counter (elimina stale timer callbacks).
//   - notifyTabHidden/notifyTabVisible for tab visibility lifecycle.
//   - onBackgroundTooLong callback for intelligent recovery.
//   - Preserves public API: start, stop, isHealthy, onConnectionDead, onConnectionAlive.

import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../../core/utils/app_logger.dart';
import 'web_reconnect_strategy.dart';

/// ✅ ENTERPRISE: Gerenciador de Heartbeat para Totem (Flutter Web)
///
/// Padrão PING/PONG otimizado para ambiente web:
/// - Cliente envia 'ping' a cada strategy.pingInterval
/// - Servidor responde 'pong' dentro de strategy.pongTimeout
/// - Servidor também envia 'heartbeat' broadcast (namespace /)
/// - N pongs perdidos consecutivos = conexão morta → força reconexão
///
/// UPGRADE 2026-03-22:
/// - Timings adaptativos para web via WebReconnectStrategy
/// - Generation counter previne corrupção por callbacks órfãos
/// - Tab visibility awareness (hidden/visible lifecycle)
/// - onBackgroundTooLong callback para recovery inteligente
class HeartbeatManager {
  final socket_io.Socket socket;
  final Function() onConnectionDead;
  final Function()? onConnectionAlive;
  final Function()? onBackgroundTooLong;
  final WebReconnectStrategy strategy;

  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  bool _awaitingPong = false;
  int _consecutiveFailures = 0;
  DateTime? _lastPongReceived;

  // ═══════════════════════════════════════════════════════════
  // GENERATION COUNTER — Elimina stale timer callbacks
  // ═══════════════════════════════════════════════════════════
  // Problema: _pongTimeoutTimer pode ter callback agendado antes do stop().
  // Quando start() é chamado, o callback antigo executa com estado novo,
  // corrompendo _awaitingPong.
  // Solução: Cada start() incrementa _generation. Callbacks verificam
  // se a generation ainda é a mesma antes de executar.
  int _generation = 0;

  // ═══════════════════════════════════════════════════════════
  // TAB VISIBILITY LIFECYCLE — Web-specific background detection
  // ═══════════════════════════════════════════════════════════
  DateTime? _tabHiddenAt;
  bool _wasBackgroundTooLong = false;

  HeartbeatManager({
    required this.socket,
    required this.onConnectionDead,
    required this.strategy,
    this.onConnectionAlive,
    this.onBackgroundTooLong,
  });

  /// Inicia o monitoramento de heartbeat.
  /// Deve ser chamado APÓS socket.onConnect confirmar conexão.
  void start() {
    stop();

    _generation++;
    final myGen = _generation;

    _consecutiveFailures = 0;
    _awaitingPong = false;
    _lastPongReceived = DateTime.now();
    _wasBackgroundTooLong = false;

    // Registra listener para PONG do servidor
    socket.on('pong', _onPongReceived);

    // ✅ TOTEM ESPECÍFICO: Também escuta 'heartbeat' broadcast do servidor
    // O namespace '/' recebe heartbeat espontâneo do backend
    socket.on('heartbeat', _onPongReceived);

    // Timer periódico de PING usando strategy.pingInterval
    _pingTimer = Timer.periodic(strategy.pingInterval, (_) {
      if (_generation != myGen) return; // Stale callback — discard
      _sendPing(myGen);
    });

    AppLogger.d(
      '[Heartbeat] Iniciado gen=$myGen '
      '(ping=${strategy.pingInterval.inSeconds}s, '
      'pong_timeout=${strategy.pongTimeout.inSeconds}s, '
      'max_failures=${strategy.maxConsecutiveFailures})',
    );

    // Primeiro PING após 2s (dá tempo para conexão estabilizar)
    Future.delayed(const Duration(seconds: 2), () {
      if (_generation != myGen) return; // Stale callback — discard
      _sendPing(myGen);
    });
  }

  /// Para o monitoramento de heartbeat.
  /// Deve ser chamado antes de disconnect/dispose do socket.
  void stop() {
    _generation++; // ✅ CRITICAL: Invalida todos os timers pendentes
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
    _awaitingPong = false;

    try {
      socket.off('pong');
      socket.off('heartbeat');
    } catch (_) {}

    AppLogger.d('🛑 [Heartbeat] Parado (Gen: $_generation)');
  }

  // ═══════════════════════════════════════════════════════════
  // TAB VISIBILITY API — Web-specific lifecycle
  // ═══════════════════════════════════════════════════════════

  /// Notifica que a tab foi escondida (hidden).
  /// Registra o momento para calcular duração ao voltar.
  ///
  /// Em browsers, tab hidden não suspende timers como Android Doze,
  /// mas economiza recursos e evita falsos positivos quando
  /// a CPU está ocupada com outras abas.
  void notifyTabHidden() {
    _tabHiddenAt = DateTime.now();
    _wasBackgroundTooLong = false;
    AppLogger.d(
      '[Heartbeat] Tab HIDDEN at '
      '${_tabHiddenAt!.toIso8601String()}',
    );
  }

  /// Notifica que a tab voltou a visible.
  /// Calcula duração; se >= maxSafeBackgroundDuration → conexão morta.
  /// Se < maxSafe → força PING para validar rapidamente.
  ///
  /// Fluxo:
  /// 1. Calcula hiddenDuration = now - _tabHiddenAt
  /// 2. Se >= maxSafe → marca wasBackgroundTooLong, chama onBackgroundTooLong()
  /// 3. Se < maxSafe → força PING para validar conexão em <pongTimeout
  void notifyTabVisible() {
    final hiddenAt = _tabHiddenAt;
    _tabHiddenAt = null;

    if (hiddenAt == null) {
      AppLogger.d('[Heartbeat] Tab visible sem hidden registrado');
      return;
    }

    final hiddenDuration = DateTime.now().difference(hiddenAt);

    AppLogger.d(
      '[Heartbeat] Tab visible after '
      '${hiddenDuration.inSeconds}s hidden '
      '(maxSafe=${strategy.maxSafeBackgroundDuration.inSeconds}s)',
    );

    if (hiddenDuration >= strategy.maxSafeBackgroundDuration) {
      // Hidden longo — conexão provavelmente morta
      _wasBackgroundTooLong = true;
      AppLogger.w(
        '[Heartbeat] Tab hidden too long '
        '(${hiddenDuration.inSeconds}s >= '
        '${strategy.maxSafeBackgroundDuration.inSeconds}s). '
        'Triggering background recovery.',
      );
      onBackgroundTooLong?.call();
    } else {
      // Hidden curto — valida com force ping
      _wasBackgroundTooLong = false;
      AppLogger.d(
        '[Heartbeat] Tab hidden short '
        '(${hiddenDuration.inSeconds}s). Force ping to validate.',
      );
      forcePing();
    }
  }

  /// true se o último retorno de hidden excedeu maxSafeBackgroundDuration.
  /// Lido pelo RealtimeRepository para decidir nível de recovery.
  bool get wasBackgroundTooLong => _wasBackgroundTooLong;

  /// Duração do hidden atual (null se não está hidden).
  Duration? get currentHiddenDuration {
    final hiddenAt = _tabHiddenAt;
    if (hiddenAt == null) return null;
    return DateTime.now().difference(hiddenAt);
  }

  // ═══════════════════════════════════════════════════════════
  // PING/PONG CORE
  // ═══════════════════════════════════════════════════════════

  /// Envia PING e inicia timer de espera pelo PONG.
  /// [gen] é a generation no momento do agendamento — se _generation
  /// mudou (stop+start aconteceu), o callback é descartado.
  void _sendPing(int gen) {
    // Generation check — descarta callbacks órfãos
    if (_generation != gen) return;

    // Se ainda está aguardando PONG do PING anterior, contabiliza falha.
    if (_awaitingPong) {
      _consecutiveFailures++;
      AppLogger.d(
        '[Heartbeat] PONG não recebido '
        '(falha #$_consecutiveFailures/${strategy.maxConsecutiveFailures})',
      );

      if (_consecutiveFailures >= strategy.maxConsecutiveFailures) {
        AppLogger.d(
          '[Heartbeat] Conexão considerada MORTA após '
          '${strategy.maxConsecutiveFailures} falhas. Forcing reconnect.',
        );
        _handleConnectionDead();
        return;
      }
    }

    try {
      _awaitingPong = true;

      // Evento 'ping' — o backend responde com 'pong'
      socket.emit('ping', {
        'timestamp': DateTime.now().toIso8601String(),
        'sequence': _consecutiveFailures,
        'generation': gen,
      });

      // Timeout: se PONG não chegar em strategy.pongTimeout, marca como falha
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = Timer(strategy.pongTimeout, () {
        // Generation check — descarta callbacks órfãos
        if (_generation != gen) return;

        if (_awaitingPong) {
          AppLogger.d(
            '[Heartbeat] Pong timeout '
            '(${strategy.pongTimeout.inSeconds}s)',
          );
          // NÃO incrementa _consecutiveFailures aqui.
          // O próximo _sendPing() já verifica _awaitingPong e incrementa.
        }
      });
    } catch (e) {
      AppLogger.e('[Heartbeat] Erro ao enviar PING: $e');
      _consecutiveFailures++;
      if (_consecutiveFailures >= strategy.maxConsecutiveFailures) {
        _handleConnectionDead();
      }
    }
  }

  /// Callback quando recebe PONG ou heartbeat do servidor
  void _onPongReceived(dynamic data) {
    if (!_awaitingPong) return;

    _awaitingPong = false;
    _pongTimeoutTimer?.cancel();
    _lastPongReceived = DateTime.now();

    // Reset de falhas — conexão restaurada
    if (_consecutiveFailures > 0) {
      AppLogger.d(
        '[Heartbeat] Conexão restaurada após $_consecutiveFailures falha(s)',
      );
      _consecutiveFailures = 0;
      onConnectionAlive?.call();
    }
  }

  void _handleConnectionDead() {
    stop();
    onConnectionDead();
  }

  /// Tempo desde último PONG bem-sucedido
  Duration? get timeSinceLastPong {
    if (_lastPongReceived == null) return null;
    return DateTime.now().difference(_lastPongReceived!);
  }

  /// Conexão está saudável (sem falhas pendentes)
  bool get isHealthy => _consecutiveFailures == 0 && !_awaitingPong;

  /// Força um PING imediato (útil após retorno de hidden curto
  /// ou ação do usuário para validar conexão).
  void forcePing() {
    _awaitingPong = false;
    _sendPing(_generation);
  }
}
