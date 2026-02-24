/// ✅ Menu Visit Service
///
/// Serviço para registrar visitas ao cardápio via Socket.IO em tempo real.
/// Deduplicação e analytics integrados.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:totem/core/utils/app_logger.dart';

class MenuVisitService {
  static final MenuVisitService _instance = MenuVisitService._internal();
  factory MenuVisitService() => _instance;
  MenuVisitService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();

  String? _sessionId;
  String? _deviceInfo;
  String? _appVersion;
  IO.Socket? _socket;
  bool _isInitialized = false;

  // Constantes
  static const String _sessionIdKey = 'menu_session_id';
  static const String _lastVisitKey = 'last_menu_visit';
  static const Duration _deduplicationWindow = Duration(minutes: 5);

  /// Inicializa o serviço com o socket conectado
  Future<void> initialize(IO.Socket socket) async {
    if (_isInitialized) return;

    _socket = socket;
    await _loadOrCreateSessionId();
    await _collectDeviceInfo();
    _isInitialized = true;

    AppLogger.d('📱 [MenuVisit] Serviço inicializado');
  }

  /// Carrega ou cria um session ID único
  Future<String> _loadOrCreateSessionId() async {
    _sessionId = await _secureStorage.read(key: _sessionIdKey);

    if (_sessionId == null || _sessionId!.isEmpty) {
      _sessionId = _uuid.v4();
      await _secureStorage.write(key: _sessionIdKey, value: _sessionId!);
      AppLogger.d('🆔 [MenuVisit] Novo session ID criado: $_sessionId');
    } else {
      AppLogger.d(
        '🔄 [MenuVisit] Session ID existente carregado: $_sessionId',
      );
    }

    return _sessionId!;
  }

  /// Coleta informações do dispositivo para analytics
  Future<void> _collectDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      String deviceType = 'unknown';
      String platform = 'unknown';

      if (kIsWeb) {
        deviceType = 'desktop';
        platform = 'web';
      } else {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceType = _getDeviceType(androidInfo.model);
          platform = 'android';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceType =
              iosInfo.model.toLowerCase().contains('ipad')
                  ? 'tablet'
                  : 'mobile';
          platform = 'ios';
        }
      }

      _deviceInfo = '$deviceType-$platform';
      _appVersion = packageInfo.version;

      AppLogger.d(
        '📱 [MenuVisit] Device info: $_deviceInfo, v$_appVersion',
      );
    } catch (e) {
      AppLogger.e('❌ [MenuVisit] Erro ao coletar device info: $e');
      _deviceInfo = 'unknown';
      _appVersion = '1.0.0';
    }
  }

  /// Determina tipo de dispositivo baseado no modelo
  String _getDeviceType(String model) {
    final modelLower = model.toLowerCase();

    if (modelLower.contains('tablet') ||
        modelLower.contains('pad') ||
        (modelLower.contains('sm-') && modelLower.contains('t'))) {
      return 'tablet';
    } else if (modelLower.contains('mobile') ||
        modelLower.contains('phone') ||
        modelLower.contains('m-')) {
      return 'mobile';
    } else {
      return 'desktop';
    }
  }

  /// Registra visita ao cardápio via Socket.IO
  Future<bool> recordMenuVisit({
    String? customSource,
    String? referrer,
    Map<String, dynamic>? utmParameters,
  }) async {
    if (!_isInitialized || _socket == null || !_socket!.connected) {
      AppLogger.w(
        '⚠️ [MenuVisit] Socket não conectado, ignorando visita',
      );
      return false;
    }

    // 🔄 VERIFICA DEDUPLICAÇÃO (mesma sessão em 5 minutos)
    if (await _isDuplicateVisit()) {
      AppLogger.d('🔄 [MenuVisit] Visita duplicada ignorada');
      return false;
    }

    try {
      // 📱 PREPARA DADOS DA VISITA
      final visitData = {
        'customer_session_id': _sessionId,
        'source': customSource ?? _detectSource(referrer),
        'device_type': _deviceInfo ?? 'unknown',
        'user_agent': _getUserAgent(),
        'referrer': referrer,
        'ip_address': null, // Será preenchido no backend
        'app_version': _appVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'utm_parameters': utmParameters,
      };

      AppLogger.d('📤 [MenuVisit] Enviando visita: ${visitData.keys}');

      // 📡 EMITE VISITA VIA SOCKET.IO
      _socket!.emit('menu_visit', visitData);

      // 💾 SALVA TIMESTAMP PARA DEDUPLICAÇÃO
      await _saveLastVisitTimestamp();

      AppLogger.i('✅ [MenuVisit] Visita registrada via Socket.IO');
      return true;
    } catch (e) {
      AppLogger.e('❌ [MenuVisit] Erro ao registrar visita: $e');
      return false;
    }
  }

  /// Verifica se é uma visita duplicada (mesma sessão em 5 minutos)
  Future<bool> _isDuplicateVisit() async {
    try {
      final lastVisitStr = await _secureStorage.read(key: _lastVisitKey);
      if (lastVisitStr == null) return false;

      final lastVisit = DateTime.parse(lastVisitStr);
      final now = DateTime.now();

      return now.difference(lastVisit) < _deduplicationWindow;
    } catch (e) {
      AppLogger.e('❌ [MenuVisit] Erro ao verificar duplicata: $e');
      return false;
    }
  }

  /// Salva timestamp da última visita
  Future<void> _saveLastVisitTimestamp() async {
    try {
      await _secureStorage.write(
        key: _lastVisitKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      AppLogger.e('❌ [MenuVisit] Erro ao salvar timestamp: $e');
    }
  }

  /// Detecta origem do tráfego baseado no referrer
  String _detectSource(String? referrer) {
    if (referrer == null || referrer.isEmpty) {
      return 'direct';
    }

    final referrerLower = referrer.toLowerCase();

    // Redes sociais
    if (referrerLower.contains('instagram')) return 'instagram';
    if (referrerLower.contains('facebook')) return 'facebook';
    if (referrerLower.contains('twitter') || referrerLower.contains('x.com'))
      return 'twitter';
    if (referrerLower.contains('tiktok')) return 'tiktok';
    if (referrerLower.contains('linkedin')) return 'linkedin';

    // WhatsApp (geralmente não tem referrer)
    if (referrerLower.contains('whatsapp')) return 'whatsapp';

    // Buscadores
    if (referrerLower.contains('google')) return 'google';
    if (referrerLower.contains('bing')) return 'bing';
    if (referrerLower.contains('yahoo')) return 'yahoo';

    // MenuHub
    if (referrerLower.contains('menuhub')) return 'menuhub';

    return 'other';
  }

  /// Obtém user agent simplificado
  String _getUserAgent() {
    if (kIsWeb) {
      return 'web-${_deviceInfo ?? 'unknown'}';
    } else {
      return '${defaultTargetPlatform.toString().split('.').last}-${_deviceInfo ?? 'unknown'}';
    }
  }

  /// Solicita analytics do menu via Socket.IO
  Future<Map<String, dynamic>?> requestMenuAnalytics({int days = 30}) async {
    if (!_isInitialized || _socket == null || !_socket!.connected) {
      AppLogger.warning(
        '⚠️ [MenuVisit] Socket não conectado, não pode solicitar analytics',
      );
      return null;
    }

    try {
      final requestData = {
        'days': days,
        'timestamp': DateTime.now().toIso8601String(),
      };

      AppLogger.d('📊 [MenuVisit] Solicitando analytics: $requestData');

      // 📡 EMITE SOLICITAÇÃO VIA SOCKET.IO
      _socket!.emit('menu_analytics', requestData);

      // TODO: Implementar listener para resposta
      // Por enquanto, retorna null (analytics serão recebidos via evento)

      AppLogger.i('📊 [MenuVisit] Analytics solicitados via Socket.IO');
      return null;
    } catch (e) {
      AppLogger.e('❌ [MenuVisit] Erro ao solicitar analytics: $e');
      return null;
    }
  }

  /// Limpa session ID (para testes ou reset)
  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _sessionIdKey);
      await _secureStorage.delete(key: _lastVisitKey);
      _sessionId = null;
      AppLogger.d('🗑️ [MenuVisit] Sessão limpa');
    } catch (e) {
      AppLogger.e('❌ [MenuVisit] Erro ao limpar sessão: $e');
    }
  }

  /// Obtém informações da sessão atual
  Map<String, String?> getSessionInfo() {
    return {
      'session_id': _sessionId,
      'device_type': _deviceInfo,
      'app_version': _appVersion,
      'is_initialized': _isInitialized.toString(),
      'socket_connected': _socket?.connected.toString(),
    };
  }

  /// Força registro de visita (ignora deduplicação)
  Future<bool> forceRecordMenuVisit({
    String? customSource,
    String? referrer,
    Map<String, dynamic>? utmParameters,
  }) async {
    // Limpa timestamp para forçar nova visita
    await _secureStorage.delete(key: _lastVisitKey);

    return await recordMenuVisit(
      customSource: customSource,
      referrer: referrer,
      utmParameters: utmParameters,
    );
  }
}
