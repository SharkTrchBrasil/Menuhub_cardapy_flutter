/// Event Deduplicator - Bulletproof Client-Side Deduplication (Totem Web)
///
/// LRU cache de eventos processados para evitar duplicidade na UI.
/// Cada evento é identificado por (event_type, entity_id, server_seq).
///
/// Casos de uso:
/// - Reconexão com delta sync: Backend pode reenviar eventos
/// - Tab hidden/visible: Mesmo evento chega após visibility change
/// - Network instability: Pacotes duplicados pelo Engine.IO
///
/// Adaptado do Admin (padrão Discord Gateway Dedup, Slack Event ID)

import 'dart:collection';

import 'package:totem/core/utils/app_logger.dart';

class EventDeduplicator {
  EventDeduplicator({this.maxSize = 1000});

  final int maxSize;

  /// LRU: LinkedHashMap mantém ordem de inserção.
  /// Key = "event_type:entity_id:server_seq"
  /// Value = timestamp de quando foi processado
  final LinkedHashMap<String, DateTime> _processed = LinkedHashMap();

  /// Sequência mais alta recebida por store (para ordenação)
  final Map<String, int> _highestSeqByStore = {};

  /// Verifica se o evento já foi processado.
  /// Retorna true se é DUPLICATA (deve ser ignorado).
  bool isDuplicate({
    required String eventType,
    required String entityId,
    int serverSeq = 0,
    String? storeId,
  }) {
    // Se server_seq = 0, não temos sequência → usa key sem seq
    final key = serverSeq > 0
        ? '$eventType:$entityId:$serverSeq'
        : '$eventType:$entityId';

    if (_processed.containsKey(key)) {
      return true;
    }

    // Verifica se já recebemos uma seq MAIOR para este entity_id
    // (significa que este evento é outdated)
    if (serverSeq > 0 && storeId != null) {
      final entitySeqKey = '$storeId:$eventType:$entityId';
      final lastSeq = _highestSeqByStore[entitySeqKey] ?? 0;
      if (serverSeq < lastSeq) {
        AppLogger.d(
          '[EventDedup] Evento outdated ignorado: $eventType $entityId '
          'seq=$serverSeq < lastSeq=$lastSeq',
        );
        return true;
      }
      _highestSeqByStore[entitySeqKey] = serverSeq;
    }

    return false;
  }

  /// Marca o evento como processado (deve ser chamado APÓS processar).
  void markProcessed({
    required String eventType,
    required String entityId,
    int serverSeq = 0,
  }) {
    final key = serverSeq > 0
        ? '$eventType:$entityId:$serverSeq'
        : '$eventType:$entityId';

    _processed[key] = DateTime.now();

    // GC: Remove entradas mais antigas se exceder maxSize
    while (_processed.length > maxSize) {
      _processed.remove(_processed.keys.first);
    }
  }

  /// Atalho: verifica + marca em uma única chamada.
  /// Retorna true se é NOVO (deve ser processado).
  /// Retorna false se é DUPLICATA (deve ser ignorado).
  bool tryProcess({
    required String eventType,
    required String entityId,
    int serverSeq = 0,
    String? storeId,
  }) {
    if (isDuplicate(
      eventType: eventType,
      entityId: entityId,
      serverSeq: serverSeq,
      storeId: storeId,
    )) {
      return false;
    }

    markProcessed(
      eventType: eventType,
      entityId: entityId,
      serverSeq: serverSeq,
    );
    return true;
  }

  /// Retorna a maior sequência conhecida para uma loja.
  int getHighestSeq(String storeId) {
    int highest = 0;
    for (final entry in _highestSeqByStore.entries) {
      if (entry.key.startsWith('$storeId:') && entry.value > highest) {
        highest = entry.value;
      }
    }
    return highest;
  }

  /// Limpa o cache de dedup (usado no logout ou reconnect limpo).
  void clear() {
    _processed.clear();
    _highestSeqByStore.clear();
  }

  /// Métricas para debugging.
  Map<String, dynamic> get stats => {
    'processed_count': _processed.length,
    'max_size': maxSize,
    'stores_tracked': _highestSeqByStore.keys
        .map((k) => k.split(':').first)
        .toSet()
        .length,
  };
}
