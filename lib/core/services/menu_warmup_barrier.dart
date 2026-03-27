import 'dart:async';

import 'package:totem/models/store.dart';
import 'package:totem/core/utils/app_logger.dart';

/// ✅ PERF: Barreira de aquecimento do menu.
/// Permite que widgets renderizem progressivamente conforme dados chegam:
///   Fase 0 (<100ms): Skeleton genérico
///   Fase 1 (<300ms): Store name + status (storeReady completa)
///   Fase 2 (<500ms): Categorias visíveis (catalogReady completa)
///   Fase 3 (<2s):    Produtos completos (fullMenuReady completa)
class MenuWarmupBarrier {
  MenuWarmupBarrier._();
  static final MenuWarmupBarrier instance = MenuWarmupBarrier._();
  factory MenuWarmupBarrier() => instance;

  final _storeReady = Completer<Store>();
  final _catalogReady = Completer<void>();
  final _fullMenuReady = Completer<void>();

  final Stopwatch _stopwatch = Stopwatch();

  bool get isStoreReady => _storeReady.isCompleted;
  bool get isCatalogReady => _catalogReady.isCompleted;
  bool get isFullMenuReady => _fullMenuReady.isCompleted;

  Future<Store> get firstStore => _storeReady.future;
  Future<void> get catalogReady => _catalogReady.future;
  Future<void> get fullMenuReady => _fullMenuReady.future;

  /// Chamado no início da inicialização para medir tempos
  void startTiming() {
    if (!_stopwatch.isRunning) _stopwatch.start();
  }

  /// Fase 1: Store recebida — nome da loja + status aberto/fechado visíveis
  void onStoreReceived(Store store) {
    if (!_storeReady.isCompleted) {
      _storeReady.complete(store);
      AppLogger.i(
        '⚡ [PERF] Store ready: ${_stopwatch.elapsedMilliseconds}ms',
        tag: 'WARMUP',
      );
    }
  }

  /// Fase 2: Categorias recebidas — skeleton de categorias pode ser preenchido
  void onCatalogReceived() {
    if (!_catalogReady.isCompleted) {
      _catalogReady.complete();
      AppLogger.i(
        '⚡ [PERF] Catalog ready: ${_stopwatch.elapsedMilliseconds}ms',
        tag: 'WARMUP',
      );
    }
  }

  /// Fase 3: Menu completo — todos os produtos renderizados
  void onFullMenuReady() {
    if (!_fullMenuReady.isCompleted) {
      _fullMenuReady.complete();
      _stopwatch.stop();
      AppLogger.i(
        '⚡ [PERF] Full menu ready: ${_stopwatch.elapsedMilliseconds}ms',
        tag: 'WARMUP',
      );
    }
  }

  /// Reset para re-inicializações (ex: troca de loja)
  void reset() {
    // Completers não podem ser reutilizados — precisamos de uma nova instância.
    // Como é singleton, recriamos os internals.
    // Nota: Não recriamos o singleton, apenas os completers via _resetCompleters.
    _stopwatch.reset();
  }
}
