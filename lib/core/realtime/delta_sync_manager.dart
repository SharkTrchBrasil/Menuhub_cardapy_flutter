/// Delta Sync Manager - Cursor-Based Event Replay (Totem Web)
///
/// Gerencia a sincronização delta entre Totem client e backend:
/// - Rastreia last_server_seq por store (cursor monotonic)
/// - No reconnect, solicita apenas o "delta" (eventos perdidos)
/// - Processa resposta: aplica delta events ou ordena full sync
/// - Fallback gracioso se delta indisponível
///
/// Fluxo:
/// 1. Eventos do backend atualizam lastServerSeq via trackEvent()
/// 2. No reconnect, emite 'sync_from' com since_seq
/// 3. Backend retorna delta_events OU full_sync_required
/// 4. Se delta: replay sequencial via onDeltaApply callback
/// 5. Se full_sync: reconecta com initial_state_loaded (pesado)
///
/// Adaptado do Admin (padrão Discord Gateway Resume, Slack Events API)

import 'dart:async';

import 'package:totem/core/utils/app_logger.dart';
import 'package:totem/core/realtime/event_deduplicator.dart';

/// Estado de sync por store
class StoreSyncState {
  final String storeUuid;
  int lastServerSeq;
  DateTime? lastEventAt;
  DateTime? lastFullSyncAt;
  int deltaSyncCount;
  int fullSyncCount;

  StoreSyncState({
    required this.storeUuid,
    this.lastServerSeq = 0,
    this.lastEventAt,
    this.lastFullSyncAt,
    this.deltaSyncCount = 0,
    this.fullSyncCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'store_uuid': storeUuid,
    'last_server_seq': lastServerSeq,
    'last_event_at': lastEventAt?.toUtc().toIso8601String(),
    'last_full_sync_at': lastFullSyncAt?.toUtc().toIso8601String(),
    'delta_sync_count': deltaSyncCount,
    'full_sync_count': fullSyncCount,
  };
}

/// Resultado de um delta sync
class DeltaSyncResult {
  final bool success;
  final bool fullSyncRequired;
  final int eventsApplied;
  final int currentServerSeq;
  final String? error;

  const DeltaSyncResult({
    required this.success,
    this.fullSyncRequired = false,
    this.eventsApplied = 0,
    this.currentServerSeq = 0,
    this.error,
  });

  bool get isDeltaApplied => success && !fullSyncRequired && eventsApplied > 0;
  bool get isUpToDate => success && !fullSyncRequired && eventsApplied == 0;

  @override
  String toString() =>
      'DeltaSyncResult(success=$success, fullSync=$fullSyncRequired, '
      'events=$eventsApplied, seq=$currentServerSeq)';
}

/// Callback para aplicar delta events no RealtimeRepository
typedef DeltaApplyCallback =
    void Function(String storeUuid, List<Map<String, dynamic>> deltaEvents);

/// Callback para emitir evento via socket com ACK
typedef EmitWithAckCallback =
    Future<dynamic> Function(
      String event,
      Map<String, dynamic> data, {
      Duration timeout,
    });

class DeltaSyncManager {
  DeltaSyncManager({
    required this.deduplicator,
    required this.emitWithAck,
    this.onDeltaApply,
  });

  final EventDeduplicator deduplicator;
  final EmitWithAckCallback emitWithAck;
  final DeltaApplyCallback? onDeltaApply;

  /// Estado de sync por store
  final Map<String, StoreSyncState> _storeStates = {};

  /// Previne delta sync concorrente por store
  final Map<String, Completer<DeltaSyncResult>> _inFlightRequests = {};

  // ═══════════════════════════════════════════════════════════════
  // TRACKING DE SEQUÊNCIA
  // ═══════════════════════════════════════════════════════════════

  /// Atualiza o estado de sync quando um evento é recebido.
  /// Deve ser chamado para CADA evento que contém server_seq.
  void trackEvent({
    required String storeUuid,
    required int serverSeq,
    DateTime? eventTimestamp,
  }) {
    final state = _getOrCreateState(storeUuid);

    if (serverSeq > state.lastServerSeq) {
      state.lastServerSeq = serverSeq;
    }

    final ts = eventTimestamp ?? DateTime.now().toUtc();
    if (state.lastEventAt == null || ts.isAfter(state.lastEventAt!)) {
      state.lastEventAt = ts;
    }
  }

  /// Atualiza seq após receber initial_state_loaded (full snapshot)
  void trackInitialState({required String storeUuid, required int serverSeq}) {
    final state = _getOrCreateState(storeUuid);

    if (serverSeq > state.lastServerSeq) {
      state.lastServerSeq = serverSeq;
    }

    state.lastEventAt = DateTime.now().toUtc();
    state.lastFullSyncAt = DateTime.now().toUtc();
  }

  // ═══════════════════════════════════════════════════════════════
  // DELTA SYNC REQUEST
  // ═══════════════════════════════════════════════════════════════

  /// Solicita delta sync ao backend para uma loja.
  ///
  /// Retorna DeltaSyncResult indicando se:
  /// - Delta foi aplicado com sucesso (eventos parciais)
  /// - Full sync é necessário (gap no buffer)
  /// - Client já está em dia (sem eventos novos)
  Future<DeltaSyncResult> requestDelta({
    required String storeUuid,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Dedup: se já tem um request in-flight para esta store, retorna o mesmo
    final existing = _inFlightRequests[storeUuid];
    if (existing != null && !existing.isCompleted) {
      AppLogger.d('[DeltaSync] Reusing in-flight delta request for $storeUuid');
      return existing.future;
    }

    final completer = Completer<DeltaSyncResult>();
    _inFlightRequests[storeUuid] = completer;

    try {
      final state = _getOrCreateState(storeUuid);

      AppLogger.i(
        '[DeltaSync] Requesting delta for $storeUuid '
        '(last_seq=${state.lastServerSeq}, '
        'last_event=${state.lastEventAt?.toIso8601String() ?? "null"})',
        tag: 'DELTA_SYNC',
      );

      // ✅ CURSOR-BASED REPLAY: Usa sync_from (handler no TotemNamespace)
      final response = await emitWithAck('sync_from', {
        'store_uuid': storeUuid,
        'since_seq': state.lastServerSeq,
      }, timeout: timeout);

      if (response == null || response is! Map) {
        final result = const DeltaSyncResult(
          success: false,
          fullSyncRequired: true,
          error: 'No response from server',
        );
        completer.complete(result);
        return result;
      }

      final data = Map<String, dynamic>.from(response);
      final success = data['success'] == true;
      final fullSyncRequired = data['full_sync_required'] == true;
      final currentSeq = (data['current_seq'] as num?)?.toInt() ?? 0;
      final deltaEvents = data['delta_events'] as List? ?? [];

      if (!success) {
        final result = DeltaSyncResult(
          success: false,
          fullSyncRequired: true,
          currentServerSeq: currentSeq,
          error: data['error']?.toString() ?? 'Unknown error',
        );
        completer.complete(result);
        return result;
      }

      // Atualiza seq do servidor
      if (currentSeq > state.lastServerSeq) {
        state.lastServerSeq = currentSeq;
      }

      // ✅ FAST PATH: Delta events do Redis buffer
      // Normaliza campos: backend usa 'type'/'data', frontend espera 'event_type'/'payload'
      if (deltaEvents.isNotEmpty) {
        final typedEvents = deltaEvents.whereType<Map>().map((e) {
          final m = Map<String, dynamic>.from(e);
          // Normaliza 'type' → 'event_type' se necessário
          if (m.containsKey('type') && !m.containsKey('event_type')) {
            m['event_type'] = m['type'];
          }
          // Normaliza 'data' → 'payload' se necessário
          if (m.containsKey('data') && !m.containsKey('payload')) {
            m['payload'] = m['data'];
          }
          return m;
        }).toList();

        AppLogger.i(
          '[DeltaSync] Applying ${typedEvents.length} delta events '
          'for $storeUuid (fast path)',
          tag: 'DELTA_SYNC',
        );

        onDeltaApply?.call(storeUuid, typedEvents);
        state.deltaSyncCount++;
        state.lastEventAt = DateTime.now().toUtc();

        final result = DeltaSyncResult(
          success: true,
          eventsApplied: typedEvents.length,
          currentServerSeq: currentSeq,
        );
        completer.complete(result);
        return result;
      }

      // Full sync required ou client up-to-date
      if (fullSyncRequired) {
        state.fullSyncCount++;
        AppLogger.w(
          '[DeltaSync] Full sync required for $storeUuid '
          '(gap in buffer or first connect)',
        );
      } else {
        AppLogger.i(
          '[DeltaSync] Client up-to-date for $storeUuid '
          '(seq=${state.lastServerSeq})',
          tag: 'DELTA_SYNC',
        );
      }

      final result = DeltaSyncResult(
        success: true,
        fullSyncRequired: fullSyncRequired,
        currentServerSeq: currentSeq,
      );
      completer.complete(result);
      return result;
    } catch (e, st) {
      AppLogger.e(
        '[DeltaSync] Delta request failed for $storeUuid: $e',
        tag: 'DELTA_SYNC',
      );
      final result = DeltaSyncResult(
        success: false,
        fullSyncRequired: true,
        error: e.toString(),
      );
      if (!completer.isCompleted) completer.complete(result);
      return result;
    } finally {
      _inFlightRequests.remove(storeUuid);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════

  /// Retorna true se temos estado de sync para uma loja
  /// (ou seja, já recebemos pelo menos um evento/initial).
  bool hasState(String storeUuid) {
    final state = _storeStates[storeUuid];
    return state != null && state.lastServerSeq > 0;
  }

  /// Retorna o estado de sync de uma loja.
  StoreSyncState? getState(String storeUuid) => _storeStates[storeUuid];

  /// Limpa tudo (usado no logout ou full reconnect).
  void clear() {
    _storeStates.clear();
    _inFlightRequests.clear();
    deduplicator.clear();
  }

  /// Métricas para debugging.
  Map<String, dynamic> get stats => {
    'stores': _storeStates.map((k, v) => MapEntry(k, v.toJson())),
    'in_flight': _inFlightRequests.keys.toList(),
    'dedup': deduplicator.stats,
  };

  // ═══════════════════════════════════════════════════════════════
  // PRIVATE
  // ═══════════════════════════════════════════════════════════════

  StoreSyncState _getOrCreateState(String storeUuid) {
    return _storeStates.putIfAbsent(
      storeUuid,
      () => StoreSyncState(storeUuid: storeUuid),
    );
  }
}
