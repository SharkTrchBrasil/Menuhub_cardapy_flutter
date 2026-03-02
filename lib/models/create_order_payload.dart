// Em: lib/models/create_order_payload.dart
// ✅ ALINHAMENTO iFOOD: Inclui campos de origem para popular o formato Menuhub

import 'package:totem/models/customer_address.dart';

class CreateOrderPayload {
  final int paymentMethodId;
  final String deliveryType;
  final String? observation;
  final bool? needsChange;
  final double? changeFor; // Em Reais, ex: 50.00
  final int? addressId;
  final int? deliveryFee;
  final bool? isScheduled;
  final String? scheduledFor; // ISO 8601 datetime string

  // ✅ SEGURANÇA: Coordenadas GPS reais do cliente
  final double? customerLatitude;
  final double? customerLongitude;

  // ✅ NOVO: Campos para pagamento online (Mercado Pago)
  final String? mercadopagoPaymentId;
  final String? paymentType; // 'delivery' ou 'online'

  // ✅ ALINHAMENTO iFOOD: Origem do pedido
  final String? platform; // 'ANDROID', 'IOS', 'WEB'
  final String? appName; // 'Totem', 'Menuhub', etc
  final String? appVersion; // '1.0.0'
  final String? salesChannel; // 'TOTEM', 'MENU', 'MENUHUB'

  CreateOrderPayload({
    required this.paymentMethodId,
    required this.deliveryType,
    this.observation,
    this.needsChange,
    this.changeFor,
    this.addressId,
    this.deliveryFee,
    this.isScheduled,
    this.scheduledFor,
    this.customerLatitude,
    this.customerLongitude,
    this.mercadopagoPaymentId,
    this.paymentType,
    this.platform,
    this.appName,
    this.appVersion,
    this.salesChannel,
  });

  /// Factory para criar um CreateOrderPayload a partir de JSON
  factory CreateOrderPayload.fromJson(Map<String, dynamic> json) {
    return CreateOrderPayload(
      paymentMethodId: json['payment_method_id'] as int,
      deliveryType: json['delivery_type'] as String,
      observation: json['observation'] as String?,
      needsChange: json['needs_change'] as bool?,
      changeFor: (json['change_for'] as num?)?.toDouble(),
      addressId: json['address_id'] as int?,
      deliveryFee: json['delivery_fee'] as int?,
      isScheduled: json['is_scheduled'] as bool?,
      scheduledFor: json['scheduled_for'] as String?,
      customerLatitude: (json['customer_latitude'] as num?)?.toDouble(),
      customerLongitude: (json['customer_longitude'] as num?)?.toDouble(),
      mercadopagoPaymentId: json['mercadopago_payment_id'] as String?,
      paymentType: json['payment_type'] as String?,
      // ✅ ALINHAMENTO iFOOD: Campos de origem
      platform: json['platform'] as String?,
      appName: json['app_name'] as String?,
      appVersion: json['app_version'] as String?,
      salesChannel: json['sales_channel'] as String?,
    );
  }

  /// Converte o objeto para o formato JSON que o backend espera.
  Map<String, dynamic> toJson() {
    return {
      'payment_method_id': paymentMethodId,
      'delivery_type': deliveryType,
      'observation': observation,
      'needs_change': needsChange,
      // Backend espera o valor em Reais, como definido no Pydantic
      'change_for': changeFor,
      'address_id': addressId,
      'delivery_fee': deliveryFee,
      'is_scheduled': isScheduled,
      'scheduled_for': scheduledFor,
      'customer_latitude': customerLatitude,
      'customer_longitude': customerLongitude,
      'mercadopago_payment_id': mercadopagoPaymentId,
      'payment_type': paymentType,
      // ✅ ALINHAMENTO iFOOD: Campos de origem
      'platform': platform,
      'app_name': appName,
      'app_version': appVersion,
      'sales_channel': salesChannel,
    }..removeWhere((key, value) => value == null); // Remove chaves nulas
  }

  String _mapToOrderType(String type) {
    final t = type.toLowerCase();
    if (t == 'delivery') return 'DELIVERY';
    if (t == 'pickup' || t == 'takeout') return 'PICKUP';
    if (t == 'dine_in') return 'TABLE'; // Ou POS dependendo da regra
    return 'POS'; // Default fallback
  }
}
