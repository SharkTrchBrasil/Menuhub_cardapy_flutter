part of 'delivery_fee_cubit.dart';

// ✅ NOVO: Enum para representar os diferentes estados do cálculo
enum DeliveryFeeStatus { initial, loading, success, error, requiresAddress }

// ✅ NOVO: Motivo do frete grátis (movido para cá se ainda não estava)
enum FreeShippingReason { none, minOrderValue }

class DeliveryFeeState extends Equatable {
  const DeliveryFeeState({
    this.calculatedDeliveryFee = 0,
    this.isFree = false,
    this.freeShippingReason = FreeShippingReason.none,
    this.deliveryType = DeliveryType.delivery,
    this.status = DeliveryFeeStatus.initial, // ✅ ADICIONADO
  });

  final double calculatedDeliveryFee;
  final bool isFree;
  final FreeShippingReason freeShippingReason;
  final DeliveryType deliveryType;
  final DeliveryFeeStatus status; // ✅ ADICIONADO

  DeliveryFeeState copyWith({
    double? calculatedDeliveryFee,
    bool? isFree,
    FreeShippingReason? freeShippingReason,
    DeliveryType? deliveryType,
    DeliveryFeeStatus? status, // ✅ ADICIONADO
  }) {
    return DeliveryFeeState(
      calculatedDeliveryFee: calculatedDeliveryFee ?? this.calculatedDeliveryFee,
      isFree: isFree ?? this.isFree,
      freeShippingReason: freeShippingReason ?? this.freeShippingReason,
      deliveryType: deliveryType ?? this.deliveryType,
      status: status ?? this.status, // ✅ ADICIONADO
    );
  }

  @override
  List<Object?> get props => [calculatedDeliveryFee, isFree, freeShippingReason, deliveryType, status]; // ✅ ADICIONADO
}