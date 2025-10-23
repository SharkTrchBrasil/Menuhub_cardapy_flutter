

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:totem/models/order.dart';


import 'package:totem/pages/cart/cart_state.dart';
import 'package:totem/repositories/realtime_repository.dart';
import 'package:totem/cubit/auth_cubit.dart';

import 'package:totem/models/payment_method.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';

import '../../models/create_order_payload.dart';
import '../../models/store.dart';

part 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this.realtimeRepository,
    required this.customerRepository,
  }) : super(const CheckoutState());

  final RealtimeRepository realtimeRepository;
  final CustomerRepository customerRepository;

  // ✅ NOVO: Método para inicializar o estado com um pagamento padrão
  void initialize(Store store) {
    // Tenta encontrar o primeiro método de pagamento online, senão pega o primeiro da lista
    final defaultMethod = store.paymentMethodGroups
        .expand((group) => group.categories)
        .expand((cat) => cat.methods)
        .firstWhere(
          (m) => m.method_type == 'OFFLINE',
      orElse: () => store.paymentMethodGroups
          .expand((group) => group.categories)
          .expand((cat) => cat.methods)
          .first,
    );
    emit(state.copyWith(selectedPaymentMethod: defaultMethod));
  }

  void updatePaymentMethod(PlatformPaymentMethod newMethod) {
    // Se o novo método não for dinheiro, limpa a informação de troco
    if (newMethod.method_type != 'CASH') {
      emit(state.copyWith(selectedPaymentMethod: newMethod, changeFor: 0));
    } else {
      emit(state.copyWith(selectedPaymentMethod: newMethod));
    }
  }

  // ✅ NOVO: Método para atualizar o valor do troco
  void updateChange(double? amount) {
    // Usamos 0 para indicar "Não preciso de troco" e null para "não definido"
    emit(state.copyWith(changeFor: amount ?? 0));
  }


  void setObservation(String text) {
    emit(state.copyWith(observation: text));
  }

  void updateNeedsChange(bool needs) {
    emit(state.copyWith(
        needsChange: needs, changeFor: needs ? state.changeFor : null));
  }

  void updateChangeFor(double? amount) {
    emit(state.copyWith(changeFor: amount));
  }


  Future<void> placeOrder({
    required AuthState authState,
    required CartState cartState, // Continua recebendo o CartState completo
    required AddressState addressState,
    required DeliveryFeeState feeState,
  }) async {
    emit(state.copyWith(status: CheckoutStatus.loading));

    final cart = cartState.cart;
    final deliveryFeeInCents = (feeState.calculatedDeliveryFee * 100).toInt();

    final customer = authState.customer;
    if (customer == null) {
      emit(state.copyWith(status: CheckoutStatus.error,
          errorMessage: "Cliente não autenticado."));
      return;
    }

    if (cart.items.isEmpty) {
      emit(state.copyWith(status: CheckoutStatus.error,
          errorMessage: "Seu carrinho está vazio."));
      return;
    }
    if (state.selectedPaymentMethod == null) {
      emit(state.copyWith(status: CheckoutStatus.error,
          errorMessage: "Selecione uma forma de pagamento."));
      return;
    }

    try {
      // ✅ Monta o NOVO payload, muito mais enxuto
      final payload = CreateOrderPayload(
        paymentMethodId: state.selectedPaymentMethod!.id,
        deliveryType: feeState.deliveryType.name,
        addressId: addressState.selectedAddress?.id,
        observation: state.observation,
        needsChange: state.needsChange,
        changeFor: state.changeFor,
        deliveryFee: deliveryFeeInCents,
      );

      // Chama o novo método do repositório
      final order = await realtimeRepository.sendOrder(payload);

      // Sucesso! Emite o estado com o pedido finalizado.
      emit(state.copyWith(status: CheckoutStatus.success, finalOrder: order));
    } catch (e) {
      // O catch agora pega qualquer erro do repositório (vindo do backend)
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

}


