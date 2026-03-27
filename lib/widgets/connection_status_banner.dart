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
class ConnectionStatusBanner extends StatefulWidget {
  const ConnectionStatusBanner({super.key});

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  bool _hasConnectedOnce = false;

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

        // ✅ Conectado = sem banner + marca que já conectou pelo menos uma vez
        if (status == WebSocketConnectionStatus.connected) {
          _hasConnectedOnce = true;
          return const SizedBox.shrink();
        }

        // ✅ Não mostra banner durante conexão inicial (splash/loading)
        // Só mostra após a primeira conexão real ser perdida
        if (!_hasConnectedOnce) {
          return const SizedBox.shrink();
        }

        final isReconnecting =
            status == WebSocketConnectionStatus.reconnecting ||
            status == WebSocketConnectionStatus.connecting;

        return SizedBox(
          width: double.infinity,
          height: 3,
          child: isReconnecting
              ? const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                )
              : LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: Colors.transparent,
                  color: Colors.red.shade600,
                ),
        );
      },
    );
  }
}
