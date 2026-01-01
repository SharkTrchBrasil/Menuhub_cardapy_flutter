import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:totem/core/utils/app_logger.dart';
import 'package:totem/config/app_config.dart';

/// Modelo de desconto de promoção
class PromotionDiscount {
  final int promotionId;
  final String promotionType;
  final int discountOnOrder;
  final int discountOnDelivery;
  final String description;

  PromotionDiscount({
    required this.promotionId,
    required this.promotionType,
    required this.discountOnOrder,
    required this.discountOnDelivery,
    required this.description,
  });

  factory PromotionDiscount.fromJson(Map<String, dynamic> json) {
    return PromotionDiscount(
      promotionId: json['promotion_id'] ?? 0,
      promotionType: json['promotion_type'] ?? '',
      discountOnOrder: json['discount_on_order'] ?? 0,
      discountOnDelivery: json['discount_on_delivery'] ?? 0,
      description: json['description'] ?? '',
    );
  }
}

/// Resultado da aplicação de promoções
class AppliedPromotions {
  final int originalSubtotal;
  final int originalDeliveryFee;
  final int totalOrderDiscount;
  final int totalDeliveryDiscount;
  final int finalSubtotal;
  final int finalDeliveryFee;
  final int finalTotal;
  final List<PromotionDiscount> promotionsApplied;
  final String? message;

  AppliedPromotions({
    required this.originalSubtotal,
    required this.originalDeliveryFee,
    required this.totalOrderDiscount,
    required this.totalDeliveryDiscount,
    required this.finalSubtotal,
    required this.finalDeliveryFee,
    required this.finalTotal,
    required this.promotionsApplied,
    this.message,
  });

  factory AppliedPromotions.fromJson(Map<String, dynamic> json) {
    final promotionsList = (json['promotions_applied'] as List?)
        ?.map((p) => PromotionDiscount.fromJson(p))
        .toList() ?? [];

    return AppliedPromotions(
      originalSubtotal: json['original_subtotal'] ?? 0,
      originalDeliveryFee: json['original_delivery_fee'] ?? 0,
      totalOrderDiscount: json['total_order_discount'] ?? 0,
      totalDeliveryDiscount: json['total_delivery_discount'] ?? 0,
      finalSubtotal: json['final_subtotal'] ?? 0,
      finalDeliveryFee: json['final_delivery_fee'] ?? 0,
      finalTotal: json['final_total'] ?? 0,
      promotionsApplied: promotionsList,
      message: json['message'],
    );
  }

  /// Verifica se algum desconto foi aplicado
  bool get hasDiscount => totalOrderDiscount > 0 || totalDeliveryDiscount > 0;
  
  /// Verifica se tem frete grátis
  bool get hasFreeDelivery => originalDeliveryFee > 0 && finalDeliveryFee == 0;
  
  /// Total economizado
  int get totalSaved => totalOrderDiscount + totalDeliveryDiscount;
}

/// Preview de promoção para exibir no cardápio
class PromotionPreview {
  final int id;
  final String promotionType;
  final String title;
  final String? description;
  final String? badgeText;
  final int? minimumOrder;
  final String? minimumOrderDisplay;

  PromotionPreview({
    required this.id,
    required this.promotionType,
    required this.title,
    this.description,
    this.badgeText,
    this.minimumOrder,
    this.minimumOrderDisplay,
  });

  factory PromotionPreview.fromJson(Map<String, dynamic> json) {
    return PromotionPreview(
      id: json['id'] ?? 0,
      promotionType: json['promotion_type'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      badgeText: json['badge_text'],
      minimumOrder: json['minimum_order'],
      minimumOrderDisplay: json['minimum_order_display'],
    );
  }
}

/// Serviço de promoções para o cardápio
class PromotionService {
  static final PromotionService _instance = PromotionService._internal();
  factory PromotionService() => _instance;
  PromotionService._internal();

  final String _baseUrl = AppConfig.apiUrl;

  /// Lista promoções ativas de uma loja
  Future<List<PromotionPreview>> getActivePromotions(int storeId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/app/promotions/$storeId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final promotions = (data['promotions'] as List?)
            ?.map((p) => PromotionPreview.fromJson(p))
            .toList() ?? [];
        
        AppLogger.success(
          '✅ ${promotions.length} promoções ativas para loja $storeId',
          tag: 'PROMO',
        );
        return promotions;
      } else {
        AppLogger.warning(
          'Erro ao buscar promoções: ${response.statusCode}',
          tag: 'PROMO',
        );
        return [];
      }
    } catch (e) {
      AppLogger.error('Erro ao buscar promoções', error: e, tag: 'PROMO');
      return [];
    }
  }

  /// Aplica promoções no carrinho e retorna os valores finais
  Future<AppliedPromotions?> applyPromotions({
    required int storeId,
    required int subtotal, // Em centavos
    required int deliveryFee, // Em centavos
    int? customerProfileId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/app/promotions/apply'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'store_id': storeId,
          'subtotal': subtotal,
          'delivery_fee': deliveryFee,
          if (customerProfileId != null) 'customer_profile_id': customerProfileId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = AppliedPromotions.fromJson(data);
        
        if (result.hasDiscount) {
          AppLogger.success(
            '✅ Promoções aplicadas: '
            'pedido -R\$${(result.totalOrderDiscount / 100).toStringAsFixed(2)}, '
            'frete -R\$${(result.totalDeliveryDiscount / 100).toStringAsFixed(2)}',
            tag: 'PROMO',
          );
        } else {
          AppLogger.debug('Nenhuma promoção aplicável', tag: 'PROMO');
        }
        
        return result;
      } else {
        AppLogger.warning(
          'Erro ao aplicar promoções: ${response.statusCode}',
          tag: 'PROMO',
        );
        return null;
      }
    } catch (e) {
      AppLogger.error('Erro ao aplicar promoções', error: e, tag: 'PROMO');
      return null;
    }
  }
}
