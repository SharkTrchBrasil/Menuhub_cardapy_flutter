/// 🔒 Segurança de Dispositivo
/// Detecta root, emulador, debugger e outras ameaças
library;

import 'dart:io';
import 'package:flutter/foundation.dart';

/// Resultado da verificação de segurança
class SecurityCheckResult {
  final bool isSecure;
  final List<String> threats;
  final String riskLevel;

  const SecurityCheckResult({
    required this.isSecure,
    required this.threats,
    required this.riskLevel,
  });

  factory SecurityCheckResult.secure() => const SecurityCheckResult(
        isSecure: true,
        threats: [],
        riskLevel: 'LOW',
      );

  factory SecurityCheckResult.compromised(List<String> threats) =>
      SecurityCheckResult(
        isSecure: false,
        threats: threats,
        riskLevel: threats.length > 2 ? 'HIGH' : 'MEDIUM',
      );
}

/// Serviço de segurança do dispositivo
class DeviceSecurityService {
  static final DeviceSecurityService _instance =
      DeviceSecurityService._internal();
  factory DeviceSecurityService() => _instance;
  DeviceSecurityService._internal();

  /// Verifica integridade do dispositivo
  Future<SecurityCheckResult> checkDeviceIntegrity() async {
    // Em modo debug, permite tudo para desenvolvimento
    if (kDebugMode) {
      return SecurityCheckResult.secure();
    }

    final threats = <String>[];

    // Verifica root/jailbreak
    if (await _isRooted()) {
      threats.add('ROOTED_DEVICE');
    }

    // Verifica emulador
    if (await _isEmulator()) {
      threats.add('EMULATOR_DETECTED');
    }

    // Verifica debugger
    if (_isDebuggerAttached()) {
      threats.add('DEBUGGER_ATTACHED');
    }

    // Verifica modo desenvolvedor (Android)
    if (Platform.isAndroid && await _isDeveloperModeEnabled()) {
      threats.add('DEVELOPER_MODE');
    }

    if (threats.isEmpty) {
      return SecurityCheckResult.secure();
    }

    return SecurityCheckResult.compromised(threats);
  }

  /// Verifica se dispositivo está rooteado
  Future<bool> _isRooted() async {
    if (Platform.isAndroid) {
      return _checkAndroidRoot();
    } else if (Platform.isIOS) {
      return _checkiOSJailbreak();
    }
    return false;
  }

  /// Verifica root no Android
  Future<bool> _checkAndroidRoot() async {
    // Caminhos comuns de binários su
    final suPaths = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
    ];

    for (final path in suPaths) {
      if (await File(path).exists()) {
        return true;
      }
    }

    // Verifica apps de root
    final rootApps = [
      'com.noshufou.android.su',
      'com.noshufou.android.su.elite',
      'eu.chainfire.supersu',
      'com.koushikdutta.superuser',
      'com.thirdparty.superuser',
      'com.yellowes.su',
      'com.topjohnwu.magisk',
    ];

    // Aqui você usaria PackageManager para verificar
    // Por simplicidade, retornamos false
    return false;
  }

  /// Verifica jailbreak no iOS
  Future<bool> _checkiOSJailbreak() async {
    final jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
      '/usr/bin/ssh',
    ];

    for (final path in jailbreakPaths) {
      if (await File(path).exists()) {
        return true;
      }
    }

    // Tenta escrever em diretório protegido
    try {
      final file = File('/private/jailbreak_test.txt');
      await file.writeAsString('test');
      await file.delete();
      return true; // Se conseguiu escrever, está jailbroken
    } catch (_) {
      return false;
    }
  }

  /// Verifica se é emulador
  Future<bool> _isEmulator() async {
    if (Platform.isAndroid) {
      // Características comuns de emuladores Android
      final emulatorIndicators = [
        'goldfish', // Emulador padrão
        'ranchu', // Emulador ARM
        'sdk_gphone', // Google Phone
        'generic', // Genérico
        'vbox', // VirtualBox
        'genymotion', // Genymotion
      ];

      // Aqui você verificaria Build.FINGERPRINT, Build.MODEL, etc.
      // Por simplicidade, retornamos false
      return false;
    }

    if (Platform.isIOS) {
      // iOS Simulator
      // Verificar via ProcessInfo ou ambiente
      return false;
    }

    return false;
  }

  /// Verifica se debugger está anexado
  bool _isDebuggerAttached() {
    // Em Dart, podemos verificar assert
    bool isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    return isDebug;
  }

  /// Verifica modo desenvolvedor (Android)
  Future<bool> _isDeveloperModeEnabled() async {
    // Aqui você usaria Settings.Secure.getInt para verificar
    // development_settings_enabled
    return false;
  }

  /// Bloqueia execução se dispositivo comprometido
  Future<void> enforceSecurityPolicy({
    bool allowRoot = false,
    bool allowEmulator = false,
    bool allowDebugger = false,
  }) async {
    if (kDebugMode) return; // Permite tudo em debug

    final result = await checkDeviceIntegrity();

    if (!result.isSecure) {
      final blockedThreats = <String>[];

      if (!allowRoot && result.threats.contains('ROOTED_DEVICE')) {
        blockedThreats.add('ROOTED_DEVICE');
      }

      if (!allowEmulator && result.threats.contains('EMULATOR_DETECTED')) {
        blockedThreats.add('EMULATOR_DETECTED');
      }

      if (!allowDebugger && result.threats.contains('DEBUGGER_ATTACHED')) {
        blockedThreats.add('DEBUGGER_ATTACHED');
      }

      if (blockedThreats.isNotEmpty) {
        throw SecurityException(
          'Dispositivo não seguro: ${blockedThreats.join(", ")}',
          blockedThreats,
        );
      }
    }
  }
}

/// Exceção de segurança
class SecurityException implements Exception {
  final String message;
  final List<String> threats;

  SecurityException(this.message, this.threats);

  @override
  String toString() => 'SecurityException: $message';
}

