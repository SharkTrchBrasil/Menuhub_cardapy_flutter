// Em: lib/models/create_order_payload.dart

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
    }..removeWhere((key, value) => value == null); // Remove chaves nulas
  }
}