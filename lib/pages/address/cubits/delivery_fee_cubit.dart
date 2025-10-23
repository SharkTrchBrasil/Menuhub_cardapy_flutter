// Em: lib/cubits/delivery_fee/delivery_fee_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';

import '../../../models/customer_address.dart';
import '../../../models/delivery_type.dart';
import '../../../models/store.dart';
import 'package:equatable/equatable.dart';

part 'delivery_fee_state.dart';

class DeliveryFeeCubit extends Cubit<DeliveryFeeState> {
  DeliveryFeeCubit() : super(const DeliveryFeeState());

  // Esta função está PERFEITA, não precisa de alterações.
  // Ela só muda o tipo de entrega, sem afetar o frete calculado.
  void updateDeliveryType(DeliveryType newType) {
    emit(state.copyWith(deliveryType: newType));
  }

  void calculate({
    required CustomerAddress? address,
    required Store store,
    required double cartSubtotal,
  }) {
    final config = store.store_operation_config;

    // ✅ MUDANÇA PRINCIPAL AQUI
    if (config == null || address == null) {
      // Se não for possível calcular por falta de endereço, emite o status 'requiresAddress'
      emit(state.copyWith(status: DeliveryFeeStatus.requiresAddress));
      return;
    }

    final double baseFee = _calculateBaseFee(address, store);
    final freeShippingThreshold = config.freeDeliveryThreshold ?? 0;

    if (freeShippingThreshold > 0 && cartSubtotal >= freeShippingThreshold) {
      emit(state.copyWith(
        calculatedDeliveryFee: 0,
        isFree: true,
        freeShippingReason: FreeShippingReason.minOrderValue,
        status: DeliveryFeeStatus.success, // ✅ ADICIONADO
      ));
      return;
    }

    emit(state.copyWith(
      calculatedDeliveryFee: baseFee,
      isFree: baseFee == 0,
      freeShippingReason: FreeShippingReason.none,
      status: DeliveryFeeStatus.success, // ✅ ADICIONADO
    ));
  }

  double _calculateBaseFee(CustomerAddress address, Store store) {
    // Nenhuma alteração necessária nesta função.
    final scope = store.store_operation_config?.deliveryScope ?? 'city';

    if (scope == 'neighborhood') {
      final city = store.cities.firstWhereOrNull((c) => c.id == address.cityId);
      final neighborhood = city?.neighborhoods.firstWhereOrNull((n) => n.id == address.neighborhoodId);
      if (neighborhood != null && neighborhood.isActive && !neighborhood.freeDelivery) {
        return (neighborhood.deliveryFee) / 100.0;
      }
    } else { // 'city'
      final city = store.cities.firstWhereOrNull((c) => c.id == address.cityId);
      if (city != null && city.isActive) {
        return (city.deliveryFee) / 100.0;
      }
    }
    return 0.0;
  }
}