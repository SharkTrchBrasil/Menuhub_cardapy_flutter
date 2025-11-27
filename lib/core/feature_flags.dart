/// 🚩 FEATURE FLAGS - FLUTTER CLIENT
/// ==================================
/// Cliente de feature flags para controle de funcionalidades.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Status de uma feature
enum FeatureStatus {
  enabled,
  disabled,
  percentage,
  allowlist,
  beta,
}

/// Representa uma feature flag
class Feature {
  final String key;
  final String description;
  final FeatureStatus status;
  final int percentage;
  final Set<int> allowlist;

  const Feature({
    required this.key,
    this.description = '',
    this.status = FeatureStatus.disabled,
    this.percentage = 0,
    this.allowlist = const {},
  });

  bool isEnabledFor({int? userId, int? storeId}) {
    switch (status) {
      case FeatureStatus.enabled:
        return true;
      case FeatureStatus.disabled:
        return false;
      case FeatureStatus.allowlist:
      case FeatureStatus.beta:
        return allowlist.contains(userId) || allowlist.contains(storeId);
      case FeatureStatus.percentage:
        if (userId != null) {
          return ('$key:$userId'.hashCode % 100).abs() < percentage;
        }
        return false;
    }
  }

  factory Feature.fromJson(Map<String, dynamic> json) {
    return Feature(
      key: json['key'] ?? '',
      description: json['description'] ?? '',
      status: FeatureStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FeatureStatus.disabled,
      ),
      percentage: json['percentage'] ?? 0,
      allowlist: Set<int>.from(json['allowlist'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'description': description,
    'status': status.name,
    'percentage': percentage,
    'allowlist': allowlist.toList(),
  };
}

/// Serviço de Feature Flags
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  final Map<String, Feature> _features = {};
  int? _currentUserId;
  int? _currentStoreId;

  /// Features padrão
  static const Map<String, Feature> _defaultFeatures = {
    // Pagamentos
    'pix_instant_payment': Feature(
      key: 'pix_instant_payment',
      description: 'Pagamento PIX instantâneo',
      status: FeatureStatus.enabled,
    ),
    'card_payment_online': Feature(
      key: 'card_payment_online',
      description: 'Pagamento com cartão online',
      status: FeatureStatus.enabled,
    ),
    'split_payment': Feature(
      key: 'split_payment',
      description: 'Dividir pagamento',
      status: FeatureStatus.disabled,
    ),

    // Checkout
    'new_checkout_flow': Feature(
      key: 'new_checkout_flow',
      description: 'Novo fluxo de checkout',
      status: FeatureStatus.percentage,
      percentage: 10,
    ),
    'express_checkout': Feature(
      key: 'express_checkout',
      description: 'Checkout expresso',
      status: FeatureStatus.beta,
    ),

    // Entregas
    'real_time_tracking': Feature(
      key: 'real_time_tracking',
      description: 'Rastreamento em tempo real',
      status: FeatureStatus.enabled,
    ),
    'scheduled_delivery': Feature(
      key: 'scheduled_delivery',
      description: 'Agendamento de entrega',
      status: FeatureStatus.enabled,
    ),

    // Promoções
    'loyalty_program': Feature(
      key: 'loyalty_program',
      description: 'Programa de fidelidade',
      status: FeatureStatus.enabled,
    ),

    // UI/UX
    'dark_mode': Feature(
      key: 'dark_mode',
      description: 'Modo escuro',
      status: FeatureStatus.enabled,
    ),
    'product_recommendations': Feature(
      key: 'product_recommendations',
      description: 'Recomendações de produtos',
      status: FeatureStatus.percentage,
      percentage: 50,
    ),

    // Segurança
    'e2e_encryption': Feature(
      key: 'e2e_encryption',
      description: 'Criptografia E2E',
      status: FeatureStatus.enabled,
    ),
    'biometric_auth': Feature(
      key: 'biometric_auth',
      description: 'Autenticação biométrica',
      status: FeatureStatus.enabled,
    ),
  };

  /// Inicializa o serviço
  Future<void> initialize({int? userId, int? storeId}) async {
    _currentUserId = userId;
    _currentStoreId = storeId;

    // Carrega features padrão
    _features.addAll(_defaultFeatures);

    // Tenta carregar overrides do cache local
    await _loadFromCache();
  }

  /// Atualiza contexto do usuário
  void setContext({int? userId, int? storeId}) {
    _currentUserId = userId;
    _currentStoreId = storeId;
  }

  /// Carrega features do cache local
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('feature_flags');
      
      if (cached != null) {
        final Map<String, dynamic> data = jsonDecode(cached);
        for (final entry in data.entries) {
          _features[entry.key] = Feature.fromJson(entry.value);
        }
      }
    } catch (e) {
      // Ignora erros de cache
    }
  }

  /// Salva features no cache local
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _features.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString('feature_flags', jsonEncode(data));
    } catch (e) {
      // Ignora erros de cache
    }
  }

  /// Atualiza features do servidor
  Future<void> fetchFromServer(Map<String, dynamic> serverFeatures) async {
    for (final entry in serverFeatures.entries) {
      _features[entry.key] = Feature.fromJson(entry.value);
    }
    await _saveToCache();
  }

  /// Verifica se feature está ativa
  bool isEnabled(String featureKey, {bool defaultValue = false}) {
    final feature = _features[featureKey];
    
    if (feature == null) {
      return defaultValue;
    }

    return feature.isEnabledFor(
      userId: _currentUserId,
      storeId: _currentStoreId,
    );
  }

  /// Obtém feature por chave
  Feature? getFeature(String featureKey) => _features[featureKey];

  /// Retorna todas as features ativas
  List<String> getEnabledFeatures() {
    return _features.entries
        .where((e) => e.value.isEnabledFor(
              userId: _currentUserId,
              storeId: _currentStoreId,
            ))
        .map((e) => e.key)
        .toList();
  }

  /// Override local (para testes)
  void setFeatureOverride(String featureKey, FeatureStatus status) {
    if (_features.containsKey(featureKey)) {
      _features[featureKey] = Feature(
        key: featureKey,
        description: _features[featureKey]!.description,
        status: status,
      );
    }
  }

  /// Remove override local
  void clearOverride(String featureKey) {
    if (_defaultFeatures.containsKey(featureKey)) {
      _features[featureKey] = _defaultFeatures[featureKey]!;
    }
  }
}

/// Instância global
final featureFlags = FeatureFlagService();

/// Função de conveniência
bool isFeatureEnabled(String featureKey, {bool defaultValue = false}) {
  return featureFlags.isEnabled(featureKey, defaultValue: defaultValue);
}

/// Widget que renderiza baseado em feature flag
class FeatureFlag extends StatelessWidget {
  final String featureKey;
  final Widget child;
  final Widget? fallback;
  final bool defaultValue;

  const FeatureFlag({
    super.key,
    required this.featureKey,
    required this.child,
    this.fallback,
    this.defaultValue = false,
  });

  @override
  Widget build(BuildContext context) {
    if (featureFlags.isEnabled(featureKey, defaultValue: defaultValue)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

// Importação necessária para StatelessWidget
import 'package:flutter/material.dart';

