import 'package:flutter/material.dart';
import 'package:totem/core/di.dart';
import 'package:totem/repositories/realtime_repository.dart';

/// ✅ ENTERPRISE: Banner de status de conexão WebSocket
///
/// Exibe um aviso visual no topo do app quando a conexão WebSocket
/// é perdida ou está reconectando. Desaparece automaticamente
/// quando a conexão é restabelecida.
///
/// Uso:
/// ```dart
/// Column(
///   children: [
///     const ConnectionStatusBanner(),
///     Expanded(child: /* conteúdo */),
///   ],
/// )
/// ```
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = getIt<RealtimeRepository>();

    return StreamBuilder<WebSocketConnectionStatus>(
      stream: repo.connectionStatusController.stream,
      initialData:
          repo.connectionStatusController.valueOrNull ??
          WebSocketConnectionStatus.connected,
      builder: (context, snapshot) {
        final status = snapshot.data ?? WebSocketConnectionStatus.connected;

        // ✅ Conectado = sem banner
        if (status == WebSocketConnectionStatus.connected) {
          return const SizedBox.shrink();
        }

        final isReconnecting =
            status == WebSocketConnectionStatus.reconnecting ||
            status == WebSocketConnectionStatus.connecting;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color:
                isReconnecting ? Colors.orange.shade700 : Colors.red.shade700,
            boxShadow: [
              BoxShadow(
                color: (isReconnecting
                        ? Colors.orange.shade700
                        : Colors.red.shade700)
                    .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isReconnecting) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Reconectando...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Sem conexão com o servidor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
