import 'package:equatable/equatable.dart';
import 'package:totem/models/coupon_rule.dart';

/// ✅ Modelo de Cupom ATUALIZADO
/// Compatível com backend enterprise (sistema de regras JSONB)
class Coupon extends Equatable {
  const Coupon({
    required this.id,
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.startDate,
    this.endDate,
    required this.isActive,
    this.rules = const [],
  });

  final int id;
  final String code;
  final String? description;
  
  /// Tipo de desconto: 'PERCENTAGE', 'FIXED_AMOUNT', 'FREE_DELIVERY'
  final String discountType;
  
  /// Valor do desconto (% ou centavos)
  final double discountValue;
  
  /// Teto máximo de desconto em centavos (para PERCENTAGE)
  final int? maxDiscountAmount;
  
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  
  /// Sistema de regras flexível (JSONB)
  final List<CouponRule> rules;

  factory Coupon.fromJson(Map<String, dynamic> json) {
    // Parse rules
    var rulesList = <CouponRule>[];
    if (json['rules'] != null && json['rules'] is List) {
      rulesList = (json['rules'] as List)
          .map((r) => CouponRule.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    return Coupon(
      id: json['id'] as int,
      code: json['code'] as String,
      description: json['description'] as String?,
      discountType: json['discountType'] as String,
      discountValue: (json['discountValue'] as num).toDouble(),
      maxDiscountAmount: json['maxDiscountAmount'] as int?,
      startDate: json['startDate'] != null 
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null 
          ? DateTime.parse(json['endDate'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      rules: rulesList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'description': description,
        'discountType': discountType,
        'discountValue': discountValue,
        'maxDiscountAmount': maxDiscountAmount,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'isActive': isActive,
        'rules': rules.map((r) => r.toJson()).toList(),
      };

  // ═══════════════════════════════════════════════════════════
  // GETTERS DE COMPATIBILIDADE (extraem dados de rules)
  // ═══════════════════════════════════════════════════════════

  /// Valor mínimo do pedido (extraído da regra MIN_SUBTOTAL)
  int? get minOrderValue {
    try {
      final rule = rules.firstWhere((r) => r.ruleType == 'MIN_SUBTOTAL');
      return rule.value['value'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Se é válido apenas para primeiro pedido
  bool get isForFirstOrder {
    return rules.any((r) => r.ruleType == 'FIRST_ORDER');
  }

  /// Limite de usos por cliente
  int? get maxUsesPerCustomer {
    try {
      final rule = rules.firstWhere((r) => r.ruleType == 'MAX_USES_PER_CUSTOMER');
      return rule.value['limit'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Limite total de usos
  int? get maxUsesTotal {
    try {
      final rule = rules.firstWhere((r) => r.ruleType == 'MAX_USES_TOTAL');
      return rule.value['limit'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// ID do produto alvo (se houver)
  int? get targetProductId {
    try {
      final rule = rules.firstWhere((r) => r.ruleType == 'TARGET_PRODUCT');
      return rule.value['product_id'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Se é cupom de frete grátis
  bool get isFreeDelivery => discountType == 'FREE_DELIVERY';

  /// Texto descritivo do desconto
  String get discountText {
    if (discountType == 'PERCENTAGE') {
      return '${discountValue.toInt()}% OFF';
    } else if (discountType == 'FIXED_AMOUNT') {
      return 'R\$ ${(discountValue / 100).toStringAsFixed(2)} OFF';
    } else if (discountType == 'FREE_DELIVERY') {
      return 'FRETE GRÁTIS';
    }
    return '';
  }

  /// Texto do valor mínimo (se houver)
  String? get minOrderText {
    if (minOrderValue != null) {
      return 'Mínimo: R\$ ${(minOrderValue! / 100).toStringAsFixed(2)}';
    }
    return null;
  }

  @override
  List<Object?> get props => [id, code];
}
