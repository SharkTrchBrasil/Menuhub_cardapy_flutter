// Modelo para regras de frete no Totem

class DeliveryFeeRule {
  final int id;
  final int storeId;
  final String ruleType;
  final int priority;
  final bool isActive;
  final Map<String, dynamic> config;
  final String createdAt;
  final String updatedAt;

  DeliveryFeeRule({
    required this.id,
    required this.storeId,
    required this.ruleType,
    required this.priority,
    required this.isActive,
    required this.config,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeliveryFeeRule.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeRule(
      id: json['id'] as int,
      storeId: json['store_id'] as int,
      ruleType: json['rule_type'] as String,
      priority: json['priority'] as int,
      isActive: json['is_active'] as bool,
      config: Map<String, dynamic>.from(json['config'] as Map),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'rule_type': ruleType,
      'priority': priority,
      'is_active': isActive,
      'config': config,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

