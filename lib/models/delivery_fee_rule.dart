/// ✅ ENTERPRISE: Modelo para regras de frete por tipo de entrega (alinhado com Admin e Backend)
class DeliveryFeeRule {
  final int? id;
  final int storeId;
  final String deliveryMethod; // ✅ NOVO: 'delivery', 'pickup', 'table'
  final String ruleType; // 'per_km', 'radius'
  final int priority;
  final bool isActive;
  final double?
  freeDeliveryThreshold; // ✅ NOVO: Valor mínimo para frete grátis (em reais)
  final int? estimatedMinMinutes; // ✅ NOVO: Tempo mínimo de entrega
  final int? estimatedMaxMinutes; // ✅ NOVO: Tempo máximo de entrega
  final double? minOrder; // ✅ NOVO: Valor mínimo do pedido (em reais)
  final Map<String, dynamic> config;
  final String? createdAt;
  final String? updatedAt;

  DeliveryFeeRule({
    this.id,
    required this.storeId,
    this.deliveryMethod = 'delivery', // ✅ NOVO: Default para compatibilidade
    required this.ruleType,
    required this.priority,
    required this.isActive,
    this.freeDeliveryThreshold, // ✅ NOVO
    this.estimatedMinMinutes, // ✅ NOVO
    this.estimatedMaxMinutes, // ✅ NOVO
    this.minOrder, // ✅ NOVO: Valor mínimo do pedido
    required this.config,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryFeeRule.fromJson(Map<String, dynamic> json) {
    // Helper para converter MoneyAmount (mapa) ou num direto para double (valor em reais)
    double? parseMoney(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble() / 100.0;
      if (value is Map && value.containsKey('value')) {
        return (value['value'] as num).toDouble() / 100.0;
      }
      return null;
    }

    return DeliveryFeeRule(
      id: json['id'] as int?,
      storeId: json['store_id'] as int,
      deliveryMethod: json['delivery_method'] as String? ?? 'delivery',
      ruleType: json['rule_type'] as String,
      priority: json['priority'] as int,
      isActive: json['is_active'] as bool,
      freeDeliveryThreshold: parseMoney(json['free_delivery_threshold']),
      estimatedMinMinutes: json['estimated_min_minutes'] as int?,
      estimatedMaxMinutes: json['estimated_max_minutes'] as int?,
      minOrder: parseMoney(json['min_order']),
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'store_id': storeId,
      'delivery_method': deliveryMethod, // ✅ NOVO
      'rule_type': ruleType,
      'priority': priority,
      'is_active': isActive,
      if (freeDeliveryThreshold != null)
        'free_delivery_threshold':
            (freeDeliveryThreshold! * 100)
                .toInt(), // ✅ NOVO: Converte reais para centavos
      if (estimatedMinMinutes != null)
        'estimated_min_minutes': estimatedMinMinutes, // ✅ NOVO
      if (estimatedMaxMinutes != null)
        'estimated_max_minutes': estimatedMaxMinutes, // ✅ NOVO
      if (minOrder != null)
        'min_order':
            (minOrder! * 100).toInt(), // ✅ NOVO: Converte reais para centavos
      'config': config,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  DeliveryFeeRule copyWith({
    int? id,
    int? storeId,
    String? deliveryMethod, // ✅ NOVO
    String? ruleType,
    int? priority,
    bool? isActive,
    double? freeDeliveryThreshold, // ✅ NOVO
    int? estimatedMinMinutes, // ✅ NOVO
    int? estimatedMaxMinutes, // ✅ NOVO
    double? minOrder, // ✅ NOVO
    Map<String, dynamic>? config,
    String? createdAt,
    String? updatedAt,
  }) {
    return DeliveryFeeRule(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod, // ✅ NOVO
      ruleType: ruleType ?? this.ruleType,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      freeDeliveryThreshold:
          freeDeliveryThreshold ?? this.freeDeliveryThreshold, // ✅ NOVO
      estimatedMinMinutes:
          estimatedMinMinutes ?? this.estimatedMinMinutes, // ✅ NOVO
      estimatedMaxMinutes:
          estimatedMaxMinutes ?? this.estimatedMaxMinutes, // ✅ NOVO
      minOrder: minOrder ?? this.minOrder, // ✅ NOVO
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
