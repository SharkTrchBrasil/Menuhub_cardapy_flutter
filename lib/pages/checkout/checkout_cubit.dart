import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:totem/models/order.dart';
import 'package:totem/repositories/realtime_repository.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import '../../models/create_order_payload.dart';
import '../../models/delivery_type.dart';
import '../../models/store.dart';
import '../cart/cart_cubit.dart';
import '../cart/cart_state.dart';

part 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this.realtimeRepository,
    required this.customerRepository,
  }) : super(const CheckoutState());

  final RealtimeRepository realtimeRepository;
  final CustomerRepository customerRepository;

  void initialize(Store store) {
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
    if (newMethod.method_type != 'CASH') {
      emit(state.copyWith(selectedPaymentMethod: newMethod, changeFor: 0));
    } else {
      emit(state.copyWith(selectedPaymentMethod: newMethod));
    }
  }

  void updateChange(double? amount) {
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
    required CartState cartState,
    required AddressState addressState,
    required DeliveryFeeState feeState,
  }) async {
    emit(state.copyWith(status: CheckoutStatus.loading));

    // ✅ CORREÇÃO APLICADA AQUI
    // Acessa a taxa de entrega de forma segura, tratando todos os tipos de estado.
    int deliveryFeeInCents = 0;
    if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
      deliveryFeeInCents = (feeState.deliveryFee * 100).toInt();
    }

    final cart = cartState.cart;
    final customer = authState.customer;
    if (customer == null) {
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: "Cliente não autenticado."));
      return;
    }
    if (cart.items.isEmpty) {
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: "Seu carrinho está vazio."));
      return;
    }
    if (state.selectedPaymentMethod == null) {
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: "Selecione uma forma de pagamento."));
      return;
    }

    try {
      final payload = CreateOrderPayload(
        paymentMethodId: state.selectedPaymentMethod!.id,
        deliveryType: feeState.deliveryType.name,
        addressId: addressState.selectedAddress?.id,
        observation: state.observation,
        needsChange: state.needsChange,
        changeFor: state.changeFor,
        deliveryFee: deliveryFeeInCents, // Usa a variável segura
      );

      final order = await realtimeRepository.sendOrder(payload);

      emit(state.copyWith(status: CheckoutStatus.success, finalOrder: order));
    } catch (e) {
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }
}