/// 🔒 Detecção de Fraudes
/// Detecta golpes comuns em delivery e pagamentos
library;

import 'dart:collection';

/// Resultado da análise de fraude
class FraudAnalysisResult {
  final bool isSuspicious;
  final String riskLevel; // LOW, MEDIUM, HIGH, CRITICAL
  final List<String> flags;
  final String? recommendation;

  const FraudAnalysisResult({
    required this.isSuspicious,
    required this.riskLevel,
    required this.flags,
    this.recommendation,
  });

  factory FraudAnalysisResult.safe() => const FraudAnalysisResult(
        isSuspicious: false,
        riskLevel: 'LOW',
        flags: [],
      );

  factory FraudAnalysisResult.suspicious({
    required List<String> flags,
    required String riskLevel,
    String? recommendation,
  }) =>
      FraudAnalysisResult(
        isSuspicious: true,
        riskLevel: riskLevel,
        flags: flags,
        recommendation: recommendation,
      );
}

/// Serviço de detecção de fraudes
class FraudDetectionService {
  static final FraudDetectionService _instance =
      FraudDetectionService._internal();
  factory FraudDetectionService() => _instance;
  FraudDetectionService._internal();

  // Cache de histórico de pedidos por cliente
  final Map<String, List<OrderHistory>> _customerHistory = {};

  // Cache de cupons usados
  final Map<String, List<CouponUsage>> _couponUsage = {};

  // Cache de IPs suspeitos
  final Set<String> _suspiciousIps = {};

  // Cache de dispositivos
  final Map<String, DeviceInfo> _deviceHistory = {};

  /// Analisa pedido para fraude
  FraudAnalysisResult analyzeOrder({
    required String customerId,
    required int orderTotal,
    required String paymentMethod,
    required String? couponCode,
    required String? ipAddress,
    required String? deviceId,
  }) {
    final flags = <String>[];

    // 1. Verifica valor anômalo
    final valueAnalysis = _analyzeOrderValue(customerId, orderTotal);
    flags.addAll(valueAnalysis);

    // 2. Verifica abuso de cupom
    if (couponCode != null) {
      final couponAnalysis = _analyzeCouponUsage(customerId, couponCode);
      flags.addAll(couponAnalysis);
    }

    // 3. Verifica IP suspeito
    if (ipAddress != null) {
      final ipAnalysis = _analyzeIpAddress(ipAddress);
      flags.addAll(ipAnalysis);
    }

    // 4. Verifica dispositivo
    if (deviceId != null) {
      final deviceAnalysis = _analyzeDevice(customerId, deviceId);
      flags.addAll(deviceAnalysis);
    }

    // 5. Verifica padrão de comportamento
    final behaviorAnalysis = _analyzeBehavior(customerId);
    flags.addAll(behaviorAnalysis);

    if (flags.isEmpty) {
      return FraudAnalysisResult.safe();
    }

    // Determina nível de risco
    final riskLevel = _calculateRiskLevel(flags);

    return FraudAnalysisResult.suspicious(
      flags: flags,
      riskLevel: riskLevel,
      recommendation: _getRecommendation(riskLevel, flags),
    );
  }

  /// Analisa valor do pedido
  List<String> _analyzeOrderValue(String customerId, int orderTotal) {
    final flags = <String>[];
    final history = _customerHistory[customerId] ?? [];

    if (history.isEmpty) {
      // Primeiro pedido muito alto
      if (orderTotal > 50000) {
        // R$ 500
        flags.add('HIGH_FIRST_ORDER');
      }
    } else {
      // Calcula média
      final avgOrder =
          history.map((o) => o.total).reduce((a, b) => a + b) / history.length;

      // Pedido 5x maior que média
      if (orderTotal > avgOrder * 5) {
        flags.add('UNUSUAL_HIGH_VALUE');
      }

      // Muitos pedidos em pouco tempo
      final recentOrders = history
          .where((o) =>
              DateTime.now().difference(o.createdAt).inHours < 24)
          .length;
      if (recentOrders >= 10) {
        flags.add('HIGH_ORDER_FREQUENCY');
      }
    }

    return flags;
  }

  /// Analisa uso de cupom
  List<String> _analyzeCouponUsage(String customerId, String couponCode) {
    final flags = <String>[];
    final usage = _couponUsage[customerId] ?? [];

    // Cupom já usado por este cliente
    if (usage.any((u) => u.couponCode == couponCode)) {
      flags.add('COUPON_ALREADY_USED');
    }

    // Muitos cupons usados recentemente
    final recentUsage = usage
        .where((u) => DateTime.now().difference(u.usedAt).inDays < 7)
        .length;
    if (recentUsage >= 5) {
      flags.add('EXCESSIVE_COUPON_USAGE');
    }

    return flags;
  }

  /// Analisa endereço IP
  List<String> _analyzeIpAddress(String ipAddress) {
    final flags = <String>[];

    if (_suspiciousIps.contains(ipAddress)) {
      flags.add('SUSPICIOUS_IP');
    }

    // Verifica se é VPN/Proxy (simplificado)
    if (ipAddress.startsWith('10.') ||
        ipAddress.startsWith('192.168.') ||
        ipAddress.startsWith('172.')) {
      // IP privado - pode ser VPN
      flags.add('POSSIBLE_VPN');
    }

    return flags;
  }

  /// Analisa dispositivo
  List<String> _analyzeDevice(String customerId, String deviceId) {
    final flags = <String>[];
    final deviceInfo = _deviceHistory[deviceId];

    if (deviceInfo != null) {
      // Dispositivo usado por outro cliente
      if (deviceInfo.customerId != customerId) {
        flags.add('SHARED_DEVICE');
      }

      // Muitas contas no mesmo dispositivo
      if (deviceInfo.accountCount > 3) {
        flags.add('MULTIPLE_ACCOUNTS_DEVICE');
      }
    }

    return flags;
  }

  /// Analisa comportamento
  List<String> _analyzeBehavior(String customerId) {
    final flags = <String>[];
    final history = _customerHistory[customerId] ?? [];

    if (history.isEmpty) return flags;

    // Muitos cancelamentos
    final cancellations =
        history.where((o) => o.status == 'CANCELLED').length;
    if (cancellations > history.length * 0.3) {
      flags.add('HIGH_CANCELLATION_RATE');
    }

    // Muitas disputas/chargebacks
    final disputes = history.where((o) => o.hasDispute).length;
    if (disputes > 2) {
      flags.add('MULTIPLE_DISPUTES');
    }

    return flags;
  }

  /// Calcula nível de risco
  String _calculateRiskLevel(List<String> flags) {
    final criticalFlags = [
      'MULTIPLE_DISPUTES',
      'SUSPICIOUS_IP',
      'MULTIPLE_ACCOUNTS_DEVICE',
    ];

    final highFlags = [
      'UNUSUAL_HIGH_VALUE',
      'HIGH_FIRST_ORDER',
      'EXCESSIVE_COUPON_USAGE',
    ];

    if (flags.any((f) => criticalFlags.contains(f))) {
      return 'CRITICAL';
    }

    if (flags.any((f) => highFlags.contains(f))) {
      return 'HIGH';
    }

    if (flags.length >= 3) {
      return 'HIGH';
    }

    if (flags.length >= 2) {
      return 'MEDIUM';
    }

    return 'LOW';
  }

  /// Obtém recomendação baseada no risco
  String? _getRecommendation(String riskLevel, List<String> flags) {
    switch (riskLevel) {
      case 'CRITICAL':
        return 'Bloquear pedido e revisar conta';
      case 'HIGH':
        return 'Requerer verificação adicional';
      case 'MEDIUM':
        return 'Monitorar pedido';
      default:
        return null;
    }
  }

  /// Registra histórico de pedido
  void recordOrder(String customerId, OrderHistory order) {
    _customerHistory.putIfAbsent(customerId, () => []);
    _customerHistory[customerId]!.add(order);

    // Mantém apenas últimos 100 pedidos
    if (_customerHistory[customerId]!.length > 100) {
      _customerHistory[customerId]!.removeAt(0);
    }
  }

  /// Registra uso de cupom
  void recordCouponUsage(String customerId, String couponCode) {
    _couponUsage.putIfAbsent(customerId, () => []);
    _couponUsage[customerId]!.add(CouponUsage(
      couponCode: couponCode,
      usedAt: DateTime.now(),
    ));
  }

  /// Marca IP como suspeito
  void markIpSuspicious(String ipAddress) {
    _suspiciousIps.add(ipAddress);
  }

  /// Registra dispositivo
  void recordDevice(String deviceId, String customerId) {
    if (_deviceHistory.containsKey(deviceId)) {
      if (_deviceHistory[deviceId]!.customerId != customerId) {
        _deviceHistory[deviceId]!.accountCount++;
      }
    } else {
      _deviceHistory[deviceId] = DeviceInfo(
        deviceId: deviceId,
        customerId: customerId,
        accountCount: 1,
      );
    }
  }

  /// Limpa caches (para testes)
  void clearAll() {
    _customerHistory.clear();
    _couponUsage.clear();
    _suspiciousIps.clear();
    _deviceHistory.clear();
  }
}

/// Histórico de pedido
class OrderHistory {
  final int total;
  final String status;
  final bool hasDispute;
  final DateTime createdAt;

  OrderHistory({
    required this.total,
    required this.status,
    this.hasDispute = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Uso de cupom
class CouponUsage {
  final String couponCode;
  final DateTime usedAt;

  CouponUsage({
    required this.couponCode,
    required this.usedAt,
  });
}

/// Informação de dispositivo
class DeviceInfo {
  final String deviceId;
  final String customerId;
  int accountCount;

  DeviceInfo({
    required this.deviceId,
    required this.customerId,
    required this.accountCount,
  });
}

