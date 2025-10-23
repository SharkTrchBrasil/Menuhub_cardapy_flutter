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

  CreateOrderPayload({
    required this.paymentMethodId,
    required this.deliveryType,
    this.observation,
    this.needsChange,
    this.changeFor,
    this.addressId,
    this.deliveryFee,
  });

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
    }..removeWhere((key, value) => value == null); // Remove chaves nulas
  }
}