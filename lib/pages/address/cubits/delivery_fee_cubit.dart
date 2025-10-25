import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:equatable/equatable.dart';

import '../../../models/customer_address.dart';
import '../../../models/delivery_type.dart';
import '../../../models/store.dart';

part 'delivery_fee_state.dart';

class DeliveryFeeCubit extends Cubit<DeliveryFeeState> {
  DeliveryFeeCubit() : super(const DeliveryFeeInitial());

  // ✅ LÓGICA DE ATUALIZAÇÃO DE TIPO CORRIGIDA E MAIS ROBUSTA
  void updateDeliveryType(DeliveryType newType) {
    // Se o estado atual já foi calculado (Loaded), cria uma nova cópia com o novo tipo.
    if (state is DeliveryFeeLoaded) {
      final loadedState = state as DeliveryFeeLoaded;
      emit(loadedState.copyWith(deliveryType: newType));
    }
    // Se o estado for qualquer outro (Initial, Loading, Error),
    // emite um novo estado `Initial` com o tipo de entrega atualizado.
    else {
      emit(DeliveryFeeInitial(deliveryType: newType));
    }
  }

  void calculate({
    required CustomerAddress? address,
    required Store store,
    required double cartSubtotal,
  }) {
    // Pega o tipo de entrega atual do estado, qualquer que seja ele.
    final currentDeliveryType = state.deliveryType;

    // Se o tipo de entrega for retirada, o frete é sempre zero.
    if (currentDeliveryType == DeliveryType.pickup) {
      emit(const DeliveryFeeLoaded(
        deliveryFee: 0,
        isFree: true,
        deliveryType: DeliveryType.pickup,
      ));
      return;
    }

    // Se não for retirada, mas não tiver endereço, requer um endereço.
    if (address == null) {
      emit(DeliveryFeeRequiresAddress(deliveryType: currentDeliveryType));
      return;
    }

    emit(DeliveryFeeLoading(deliveryType: currentDeliveryType));

    final config = store.store_operation_config;
    final double baseFee = _calculateBaseFee(address, store);
    final freeShippingThreshold = config?.freeDeliveryThreshold ?? 0;

    if (freeShippingThreshold > 0 && cartSubtotal >= freeShippingThreshold) {
      emit(DeliveryFeeLoaded(
        deliveryFee: 0,
        isFree: true,
        deliveryType: currentDeliveryType,
      ));
      return;
    }

    emit(DeliveryFeeLoaded(
      deliveryFee: baseFee,
      isFree: baseFee == 0,
      deliveryType: currentDeliveryType,
    ));
  }

  // A função de cálculo base permanece a mesma.
  double _calculateBaseFee(CustomerAddress address, Store store) {
    final scope = store.store_operation_config?.deliveryScope ?? 'city';

    if (scope == 'neighborhood') {
      final city = store.cities.firstWhereOrNull((c) => c.id == address.cityId);
      final neighborhood = city?.neighborhoods.firstWhereOrNull((n) => n.id == address.neighborhoodId);
      if (neighborhood != null && neighborhood.isActive && !neighborhood.freeDelivery) {
        return (neighborhood.deliveryFee);
      }
    } else { // 'city'
      final city = store.cities.firstWhereOrNull((c) => c.id == address.cityId);
      if (city != null && city.isActive) {
        return (city.deliveryFee.toDouble());
      }
    }
    return 0.0;
  }
}