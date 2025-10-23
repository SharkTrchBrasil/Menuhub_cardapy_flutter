// Em: lib/models/new_order.dart

import 'package:totem/models/customer_address.dart';
import 'cart.dart'; // Importa nosso modelo Cart completo

class NewOrder {
  // ✅ O construtor agora é muito mais limpo!
  // Ele recebe o objeto 'cart' como a fonte da verdade para os dados do pedido.
  NewOrder({
    required this.cart, // O carrinho final vindo do CartCubit.state
    required this.customerId,
    this.customerName,
    this.customerPhone,
    this.deliveryType,
    this.address,
    this.paymentMethodId,
    this.needsChange,
    this.changeFor,
    this.observation,
    this.deliveryFee,
    this.applyCashbackAmount,
    this.redeemedRewardProductId,
  });

  // Armazenamos o carrinho para fácil acesso no método toJson
  final Cart cart;

  // O resto das propriedades são informações adicionais do checkout
  final int customerId;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryType;
  final CustomerAddress? address;
  final int? paymentMethodId;
  final bool? needsChange;
  final double? changeFor;
  final String? observation;
  final double? deliveryFee;
  final int? applyCashbackAmount;
  final int? redeemedRewardProductId;

  /// Converte o objeto para o formato JSON que o backend espera.
  /// Agora ele é um "empacotador", não um "calculador".
  Map<String, dynamic> toJson() {
    // A taxa de entrega precisa ser convertida para centavos
    int deliveryFeeInCents = deliveryFee != null ? (deliveryFee! * 100).round() : 0;

    return {
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,

      // ✅ CORREÇÃO 1: Mapeia a lista de 'CartItem' e chama o método correto.
      'products': cart.items.map((item) => item.toJsonForOrder()).toList(),

      // ✅ CORREÇÃO 2: Usa os totais que já vieram do backend.
      // O backend irá recalcular e validar estes valores como checagem final.
      'total_price': cart.total + deliveryFeeInCents,
      'delivery_fee': deliveryFeeInCents,

      'payment_method_id': paymentMethodId,
      'delivery_type': deliveryType,
      'observation': observation,

      'needs_change': needsChange,
      'change_for': changeFor != null ? (changeFor! * 100).round() : null,

      // ✅ Usa o cupom que já está no objeto 'cart'.
      'coupon_code': cart.couponCode,

      'apply_cashback_amount': applyCashbackAmount,
      'redeemed_reward_product_id': redeemedRewardProductId,

      if (address != null) ...{
        'street': address!.street,
        'number': address!.number,
        'complement': address!.complement,
        'neighborhood': address!.neighborhood,
        'city': address!.city,
      },
    }..removeWhere((key, value) => value == null); // Remove chaves nulas
  }
}