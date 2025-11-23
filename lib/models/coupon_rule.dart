import 'package:equatable/equatable.dart';

/// Modelo de regra de cupom
/// Suporta validações flexíveis via JSONB
class CouponRule extends Equatable {
  const CouponRule({
    this.id,
    required this.ruleType,
    required this.value,
    this.priority = 0,
  });

  final int? id;
  final String ruleType;
  final Map<String, dynamic> value;
  final int priority;

  /// Tipos de regras suportadas:
  /// - MIN_SUBTOTAL: Valor mínimo do pedido
  /// - MAX_USES_TOTAL: Limite global de usos
  /// - MAX_USES_PER_CUSTOMER: Limite por cliente
  /// - FIRST_ORDER: Apenas primeiro pedido
  /// - TARGET_PRODUCT: Produto específico
  /// - TARGET_CATEGORY: Categoria específica
  /// - TIME_WINDOW: Janela de tempo
  /// - DAY_OF_WEEK: Dias da semana

  factory CouponRule.fromJson(Map<String, dynamic> json) {
    return CouponRule(
      id: json['id'] as int?,
      ruleType: json['ruleType'] as String,
      value: Map<String, dynamic>.from(json['value'] as Map),
      priority: json['priority'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleType': ruleType,
        'value': value,
        'priority': priority,
      };

  @override
  List<Object?> get props => [id, ruleType, value, priority];
}
