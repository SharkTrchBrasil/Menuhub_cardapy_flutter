import 'package:equatable/equatable.dart';
import 'package:totem/models/coupon_rule.dart';

/// ✅ Modelo de Cupom ENTERPRISE
/// Compatível com backend enterprise (sistema de regras JSONB)
///
/// Tipos de promoção suportados:
/// - DELIVERY: Frete grátis/com desconto
/// - VOUCHER_FLEX: Cupons de desconto flexíveis
/// - ITEM: Promoções em itens específicos
///
/// Público alvo:
/// - ALL: Todos os clientes
/// - NEW_CUSTOMERS: Apenas novos clientes
/// - LOST_CUSTOMERS: Clientes perdidos
/// - NEW_AND_LOST: Novos e perdidos
/// - OPTIMIZED: Público otimizado
class Coupon extends Equatable {
  const Coupon({
    required this.id,
    required this.code,
    this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.startDate,
    this.endDate,
    required this.isActive,
    this.rules = const [],
    // ✅ Campos enterprise
    this.promotionType,
    this.discountSubtype,
    this.objective,
    this.mechanic,
    this.status,
    this.targetAudience,
    this.periodicity,
    this.deliveryRadius,
    this.minimumOrder,
    this.voucherValue,
    this.voucherValueLimit,
    this.merchantInvestment,
    // ✅ Campos de parceria
    this.partnerName,
    this.commissionType,
    this.commissionValue,
    this.isListed,
  });

  final int id;
  final String code;
  final String? title;
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

  // ═══════════════════════════════════════════════════════════
  // CAMPOS ENTERPRISE (alinhados com Menuhub)
  // ═══════════════════════════════════════════════════════════

  /// Tipo da promoção: DELIVERY, VOUCHER_FLEX, ITEM
  final String? promotionType;

  /// Subtipo: FIXED (valor fixo), PERCENT (percentual)
  final String? discountSubtype;

  /// Objetivo (ex: "Alavancar vendas")
  final String? objective;

  /// Mecânica/funcionamento
  final String? mechanic;

  /// Status: DRAFT, PARTICIPATING, PAUSED, ENDED
  final String? status;

  /// Público alvo: ALL, NEW_CUSTOMERS, LOST_CUSTOMERS, etc
  final String? targetAudience;

  /// Periodicidade (ex: "O dia inteiro", "Almoço e Jantar")
  final String? periodicity;

  /// Raio de entrega (para promoções DELIVERY)
  final String? deliveryRadius;

  /// Valor mínimo do pedido em centavos
  final int? minimumOrder;

  /// Valor do voucher em reais (para VOUCHER_FLEX)
  final int? voucherValue;

  /// Limite do voucher (0 = sem limite)
  final int? voucherValueLimit;

  /// Descrição do investimento da loja
  final String? merchantInvestment;

  // ═══════════════════════════════════════════════════════════
  // CAMPOS DE PARCERIA (Influencers)
  // ═══════════════════════════════════════════════════════════

  /// Nome do parceiro/influencer
  final String? partnerName;

  /// Tipo de comissão: FIXED, PERCENT
  final String? commissionType;

  /// Valor da comissão
  final double? commissionValue;

  /// Se aparece na listagem pública
  final bool? isListed;

  factory Coupon.fromJson(Map<String, dynamic> json) {
    // Helper para extrair valor numérico (centavos) de MoneyAmount (mapa) ou num direto
    int? parseMoney(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is Map) {
        final amount = value['amount'] ?? value['value'];
        if (amount is num) return amount.toInt();
        if (amount is String) return (double.tryParse(amount) ?? 0).toInt();
      }
      return null;
    }

    T? pick<T>(String camelKey, String snakeKey) {
      final value =
          json.containsKey(camelKey) ? json[camelKey] : json[snakeKey];
      return value as T?;
    }

    // Parse rules
    var rulesList = <CouponRule>[];
    if (json['rules'] != null && json['rules'] is List) {
      rulesList =
          (json['rules'] as List)
              .map((r) => CouponRule.fromJson(r as Map<String, dynamic>))
              .toList();
    }

    return Coupon(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? 'N/A',
      title: json['title'] as String?,
      description: json['description'] as String?,
      discountType:
          pick<String>('discountType', 'discount_type') ?? 'FIXED_AMOUNT',
      discountValue:
          (parseMoney(pick<dynamic>('discountValue', 'discount_value')) ?? 0)
              .toDouble(),
      maxDiscountAmount: parseMoney(
        pick<dynamic>('maxDiscountAmount', 'max_discount_amount'),
      ),
      startDate:
          pick<String>('startDate', 'start_date') != null
              ? DateTime.parse(pick<String>('startDate', 'start_date')!)
              : null,
      endDate:
          pick<String>('endDate', 'end_date') != null
              ? DateTime.parse(pick<String>('endDate', 'end_date')!)
              : null,
      isActive: pick<bool>('isActive', 'is_active') ?? true,
      rules: rulesList,
      // Campos enterprise
      promotionType: pick<String>('promotionType', 'promotion_type'),
      discountSubtype: pick<String>('discountSubtype', 'discount_subtype'),
      objective: json['objective'] as String?,
      mechanic: json['mechanic'] as String?,
      status: json['status'] as String?,
      targetAudience: pick<String>('targetAudience', 'target_audience'),
      periodicity: json['periodicity'] as String?,
      deliveryRadius: pick<String>('deliveryRadius', 'delivery_radius'),
      minimumOrder: parseMoney(pick<dynamic>('minimumOrder', 'minimum_order')),
      voucherValue: parseMoney(pick<dynamic>('voucherValue', 'voucher_value')),
      voucherValueLimit: parseMoney(
        pick<dynamic>('voucherValueLimit', 'voucher_value_limit'),
      ),
      merchantInvestment: pick<String>(
        'merchantInvestment',
        'merchant_investment',
      ),
      // Campos de parceria
      partnerName: pick<String>('partnerName', 'partner_name'),
      commissionType: pick<String>('commissionType', 'commission_type'),
      commissionValue:
          pick<num>('commissionValue', 'commission_value') != null
              ? pick<num>('commissionValue', 'commission_value')!.toDouble()
              : null,
      isListed: pick<bool>('isListed', 'is_listed'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'title': title,
    'description': description,
    'discountType': discountType,
    'discountValue': discountValue,
    'maxDiscountAmount': maxDiscountAmount,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'isActive': isActive,
    'rules': rules.map((r) => r.toJson()).toList(),
    // Campos enterprise
    'promotionType': promotionType,
    'discountSubtype': discountSubtype,
    'objective': objective,
    'mechanic': mechanic,
    'status': status,
    'targetAudience': targetAudience,
    'periodicity': periodicity,
    'deliveryRadius': deliveryRadius,
    'minimumOrder': minimumOrder,
    'voucherValue': voucherValue,
    'voucherValueLimit': voucherValueLimit,
    'merchantInvestment': merchantInvestment,
    // Campos de parceria
    'partnerName': partnerName,
    'commissionType': commissionType,
    'commissionValue': commissionValue,
    'isListed': isListed,
  };

  // ═══════════════════════════════════════════════════════════
  // GETTERS DE COMPATIBILIDADE (extraem dados de rules)
  // ═══════════════════════════════════════════════════════════

  /// Valor mínimo do pedido (primeiro tenta campo direto, depois regra)
  int? get minOrderValue {
    // Primeiro tenta o campo direto (enterprise)
    if (minimumOrder != null && minimumOrder! > 0) {
      return minimumOrder;
    }
    // Fallback para regra MIN_SUBTOTAL
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
      final rule = rules.firstWhere(
        (r) => r.ruleType == 'MAX_USES_PER_CUSTOMER',
      );
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

  /// ID da categoria alvo (se houver)
  int? get targetCategoryId {
    try {
      final rule = rules.firstWhere((r) => r.ruleType == 'TARGET_CATEGORY');
      return rule.value['category_id'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Se o cupom está expirado (end_date no passado)
  bool get isExpired => endDate != null && endDate!.isBefore(DateTime.now());

  /// Se o cupom ainda não começou (start_date no futuro)
  bool get isNotStarted =>
      startDate != null && startDate!.isAfter(DateTime.now());

  /// Se o cupom está válido para exibição (ativo, listado, não expirado, já iniciado)
  bool get isValidForDisplay =>
      isActive && (isListed ?? true) && !isExpired && !isNotStarted;

  /// Se é cupom de frete grátis
  bool get isFreeDelivery => discountType == 'FREE_DELIVERY';

  /// Se é cupom de parceiro/influencer
  bool get isPartnerCoupon => partnerName != null && partnerName!.isNotEmpty;

  /// Se é para novos clientes apenas
  bool get isForNewCustomers =>
      targetAudience == 'NEW_CUSTOMERS' || targetAudience == 'NEW_AND_LOST';

  /// Se é para clientes perdidos
  bool get isForLostCustomers =>
      targetAudience == 'LOST_CUSTOMERS' || targetAudience == 'NEW_AND_LOST';

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
    if (minOrderValue != null && minOrderValue! > 0) {
      return 'Mínimo: R\$ ${(minOrderValue! / 100).toStringAsFixed(2)}';
    }
    return null;
  }

  /// Texto do público alvo
  String get targetAudienceText {
    switch (targetAudience) {
      case 'NEW_CUSTOMERS':
        return 'Apenas novos clientes';
      case 'LOST_CUSTOMERS':
        return 'Clientes que não compraram há muito tempo';
      case 'NEW_AND_LOST':
        return 'Novos clientes e clientes inativos';
      case 'OPTIMIZED':
        return 'Público otimizado';
      case 'ALL':
      default:
        return 'Todos os clientes';
    }
  }

  @override
  List<Object?> get props => [id, code];
}
