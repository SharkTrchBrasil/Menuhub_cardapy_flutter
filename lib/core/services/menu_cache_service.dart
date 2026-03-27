import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// ✅ PERF: Cache do payload bruto do backend em sessionStorage.
///
/// Estratégia stale-while-revalidate — 100% REATIVO:
///   1. Salva o payload COMPLETO do initial_state_loaded (dados reais do backend)
///   2. Na próxima visita, carrega e reprocessa pelo mesmo pipeline
///   3. Socket conecta e entrega dados frescos → sobrescreve o stale
///
/// ZERO valores fixos — o cache é um espelho exato do último response do backend.
/// Usa sessionStorage (não localStorage) → stateless, morre ao fechar aba.
/// TOKENS nunca são cacheados.
class MenuCacheService {
  MenuCacheService._();
  static final MenuCacheService instance = MenuCacheService._();
  factory MenuCacheService() => instance;

  static const _keyPrefix = 'mhub_cache_v2_';
  static const _maxAge = Duration(minutes: 10);

  /// Salva o payload BRUTO COMPLETO do initial_state_loaded.
  /// Nenhuma simplificação — é o JSON exato que o backend enviou.
  void saveRawPayload({
    required String storeSlug,
    required Map<String, dynamic> rawPayload,
  }) {
    if (!kIsWeb) return;
    try {
      final key = '$_keyPrefix$storeSlug';
      final envelope = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'payload': rawPayload,
      };
      final encoded = jsonEncode(envelope);
      // Guard: sessionStorage tem limite de ~5MB. Se o payload for muito grande, ignora.
      if (encoded.length > 4 * 1024 * 1024) {
        if (kDebugMode)
          print(
            '⚠️ [CACHE] Payload muito grande (${encoded.length} bytes), ignorando cache',
          );
        return;
      }
      web.window.sessionStorage.setItem(key, encoded);
      if (kDebugMode)
        print(
          '💾 [CACHE] Raw payload saved for "$storeSlug" (${encoded.length} bytes)',
        );
    } catch (e) {
      // sessionStorage full ou não disponível — silently ignore
      if (kDebugMode) print('⚠️ [CACHE] Failed to save: $e');
    }
  }

  /// Carrega o payload bruto do backend do sessionStorage.
  /// Retorna null se não existir ou estiver expirado.
  /// O caller deve reprocessar pelo mesmo pipeline (_handleInitialStateLoaded).
  Map<String, dynamic>? loadRawPayload(String storeSlug) {
    if (!kIsWeb) return null;
    try {
      final key = '$_keyPrefix$storeSlug';
      final raw = web.window.sessionStorage.getItem(key);
      if (raw == null) return null;

      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final ts = envelope['ts'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;

      if (age > _maxAge.inMilliseconds) {
        web.window.sessionStorage.removeItem(key);
        if (kDebugMode)
          print('⏰ [CACHE] Expired for "$storeSlug" (${age}ms old)');
        return null;
      }

      final payload = envelope['payload'] as Map<String, dynamic>?;
      if (payload == null) return null;

      if (kDebugMode)
        print('⚡ [CACHE] Raw payload loaded for "$storeSlug" (${age}ms old)');
      return payload;
    } catch (e) {
      if (kDebugMode) print('⚠️ [CACHE] Failed to load: $e');
      return null;
    }
  }

  /// Limpa cache de uma loja específica
  void clear(String storeSlug) {
    if (!kIsWeb) return;
    try {
      web.window.sessionStorage.removeItem('$_keyPrefix$storeSlug');
    } catch (_) {}
  }
}
