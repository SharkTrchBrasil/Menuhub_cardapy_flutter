import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/utils/app_logger.dart';

/// ✅ Gerenciador de Heartbeat para o Totem
/// 
/// Implementa o padrão PING/PONG para manter a conexão WebSocket viva
/// e detectar falhas rapidamente.
class HeartbeatManager {
  final IO.Socket socket;
  final Function() onConnectionDead;
  final Function()? onConnectionAlive;
  
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  bool _awaitingPong = false;
  int _consecutiveFailures = 0;
  DateTime? _lastPongReceived;
  
  /// Intervalo entre PINGs (25 segundos)
  static const Duration pingInterval = Duration(seconds: 25);
  
  /// Timeout para receber PONG (8 segundos)
  static const Duration pongTimeout = Duration(seconds: 8);
  
  /// Após 3 falhas consecutivas, considera a conexão morta
  static const int maxConsecutiveFailures = 3;
  
  HeartbeatManager({
    required this.socket,
    required this.onConnectionDead,
    this.onConnectionAlive,
  });
  
  /// Inicia o monitoramento de heartbeat
  void start() {
    stop(); // Limpa timers anteriores
    
    _consecutiveFailures = 0;
    _awaitingPong = false;
    _lastPongReceived = DateTime.now();
    
    // Registra listener para PONG (resposta ao nosso PING)
    socket.on('pong', _onPongReceived);
    
    // Registra listener para HEARTBEAT (enviado espontaneamente pelo servidor)
    socket.on('heartbeat', _onPongReceived);
    
    // Inicia timer de PING periódico
    _pingTimer = Timer.periodic(pingInterval, (_) => _sendPing());
    
    AppLogger.d('💓 [Heartbeat] Iniciado (PING: ${pingInterval.inSeconds}s, Timeout: ${pongTimeout.inSeconds}s)');
    
    // Envia primeiro PING imediatamente para validar conexão
    Future.delayed(const Duration(seconds: 2), _sendPing);
  }
  
  /// Para o monitoramento de heartbeat
  void stop() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
    _awaitingPong = false;
    
    try {
      socket.off('pong');
      socket.off('heartbeat');
    } catch (_) {}
    
    AppLogger.d('🛑 [Heartbeat] Parado');
  }
  
  /// Envia PING e aguarda PONG
  void _sendPing() {
    if (!socket.connected) {
      AppLogger.d('⚠️ [Heartbeat] Ignorando PING: Socket desconectado');
      return;
    }

    // Se ainda está aguardando PONG do último PING, a conexão está instável
    if (_awaitingPong) {
      _consecutiveFailures++;
      AppLogger.d('⚠️ [Heartbeat] PONG não recebido (falha #$_consecutiveFailures de $maxConsecutiveFailures)');
      
      if (_consecutiveFailures >= maxConsecutiveFailures) {
        AppLogger.d('❌ [Heartbeat] Conexão considerada MORTA por falta de PONG');
        _handleConnectionDead();
        return;
      }
    }
    
    // Envia PING
    try {
      _awaitingPong = true;
      socket.emit('ping', {
        'timestamp': DateTime.now().toIso8601String(),
        'sequence': _consecutiveFailures,
      });
      
      // Inicia timeout para PONG
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = Timer(pongTimeout, () {
        if (_awaitingPong) {
          AppLogger.d('⏱️ [Heartbeat] Timeout de PONG (${pongTimeout.inSeconds}s)');
          // A lógica de incremento de falhas já acontece no próximo _sendPing
          // mas podemos forçar aqui se quisermos ser mais agressivos
        }
      });
      
    } catch (e) {
      AppLogger.e('❌ [Heartbeat] Erro ao enviar PING: $e');
      _consecutiveFailures++;
      if (_consecutiveFailures >= maxConsecutiveFailures) {
        _handleConnectionDead();
      }
    }
  }
  
  /// Callback quando recebe PONG do servidor
  void _onPongReceived(dynamic data) {
    if (!_awaitingPong) return;
    
    _awaitingPong = false;
    _pongTimeoutTimer?.cancel();
    _lastPongReceived = DateTime.now();
    
    // Reset de falhas - conexão está saudável
    if (_consecutiveFailures > 0) {
      AppLogger.d('✅ [Heartbeat] Conexão restaurada após $_consecutiveFailures falha(s)');
      _consecutiveFailures = 0;
      onConnectionAlive?.call();
    }
  }
  
  /// Trata conexão morta
  void _handleConnectionDead() {
    stop();
    onConnectionDead();
  }
  
  bool get isHealthy => _consecutiveFailures == 0 && !_awaitingPong;
}
