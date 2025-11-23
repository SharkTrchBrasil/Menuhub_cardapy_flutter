import 'package:dio/dio.dart';
import 'package:totem/models/coupon.dart';

/// Resultado da validação de cupom
class CouponValidationResult {
  final bool valid;
  final Coupon? coupon;
  final DiscountPreview? preview;
  final String? error;
  final String? errorCode;

  CouponValidationResult({
    required this.valid,
    this.coupon,
    this.preview,
    this.error,
    this.errorCode,
  });

  factory CouponValidationResult.success({
    required Coupon coupon,
    required DiscountPreview preview,
  }) {
    return CouponValidationResult(
      valid: true,
      coupon: coupon,
      preview: preview,
    );
  }

  factory CouponValidationResult.error({
    required String message,
    required String code,
  }) {
    return CouponValidationResult(
      valid: false,
      error: message,
      errorCode: code,
    );
  }

  factory CouponValidationResult.fromJson(Map<String, dynamic> json) {
    return CouponValidationResult(
      valid: json['valid'] as bool,
      coupon: json['coupon'] != null 
          ? Coupon.fromJson(json['coupon']) 
          : null,
      preview: json['preview'] != null 
          ? DiscountPreview.fromJson(json['preview']) 
          : null,
      error: json['error'] as String?,
      errorCode: json['error_code'] as String?,
    );
  }
}

/// Preview do desconto
class DiscountPreview {
  final int originalSubtotal;
  final double originalSubtotalReais;
  final int discountAmount;
  final double discountAmountReais;
  final int deliveryDiscount;
  final double deliveryDiscountReais;
  final int finalSubtotal;
  final double finalSubtotalReais;
  final double discountPercentage;

  DiscountPreview({
    required this.originalSubtotal,
    required this.originalSubtotalReais,
    required this.discountAmount,
    required this.discountAmountReais,
    required this.deliveryDiscount,
    required this.deliveryDiscountReais,
    required this.finalSubtotal,
    required this.finalSubtotalReais,
    required this.discountPercentage,
  });

  factory DiscountPreview.fromJson(Map<String, dynamic> json) {
    return DiscountPreview(
      originalSubtotal: json['original_subtotal'] as int,
      originalSubtotalReais: (json['original_subtotal_reais'] as num).toDouble(),
      discountAmount: json['discount_amount'] as int,
      discountAmountReais: (json['discount_amount_reais'] as num).toDouble(),
      deliveryDiscount: json['delivery_discount'] as int,
      deliveryDiscountReais: (json['delivery_discount_reais'] as num).toDouble(),
      finalSubtotal: json['final_subtotal'] as int,
      finalSubtotalReais: (json['final_subtotal_reais'] as num).toDouble(),
      discountPercentage: (json['discount_percentage'] as num).toDouble(),
    );
  }

  /// Desconto total (produto + frete)
  int get totalDiscount => discountAmount + deliveryDiscount;
  
  /// Desconto total em reais
  double get totalDiscountReais => discountAmountReais + deliveryDiscountReais;
  
  /// Se tem desconto de frete
  bool get hasFreeDelivery => deliveryDiscount > 0;
}

/// Repository para validação de cupons
class CouponRepository {
  final Dio _dio;
  final int storeId;

  CouponRepository({
    required Dio dio,
    required this.storeId,
  }) : _dio = dio;

  /// Valida cupom ANTES do checkout
  /// Retorna preview do desconto ou erro
  Future<CouponValidationResult> validateCoupon({
    required String code,
    required int cartSubtotal,
    int deliveryFee = 0,
    int? customerProfileId,
    int? customerId,
  }) async {
    try {
      final response = await _dio.post(
        '/app/coupons/validate',
        data: {
          'store_id': storeId,
          'coupon_code': code.toUpperCase(),
          'cart_subtotal': cartSubtotal,
          'delivery_fee': deliveryFee,
          'customer_profile_id': customerProfileId,
          'customer_id': customerId,
        },
      );

      return CouponValidationResult.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null && e.response!.data != null) {
        // Tenta parsear erro do backend
        try {
          return CouponValidationResult.fromJson(e.response!.data);
        } catch (_) {
          // Se não conseguir parsear, retorna erro genérico
        }
      }

      return CouponValidationResult.error(
        message: 'Erro ao validar cupom. Tente novamente.',
        code: 'NETWORK_ERROR',
      );
    } catch (e) {
      return CouponValidationResult.error(
        message: 'Erro inesperado ao validar cupom',
        code: 'UNKNOWN_ERROR',
      );
    }
  }

  /// Busca cupons disponíveis para a loja (opcional)
  Future<List<Coupon>> getAvailableCoupons() async {
    try {
      final response = await _dio.get(
        '/stores/$storeId/coupons',
        queryParameters: {'is_active': true},
      );

      if (response.data is List) {
        return (response.data as List)
            .map((json) => Coupon.fromJson(json))
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}
