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
import '../../services/store_status_service.dart';
import '../../services/geolocation_service.dart';
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

  void initialize(Store store, {DeliveryType? deliveryType}) {
    print('🔍 [CheckoutCubit] Inicializando métodos de pagamento...');
    print('   Store ID: ${store.id}');
    print('   Total de grupos: ${store.paymentMethodGroups.length}');
    
    // ✅ DEBUG: Log dos grupos e métodos disponíveis
    for (final group in store.paymentMethodGroups) {
      print('   Grupo: ${group.name} (${group.methods.length} métodos)');
      for (final method in group.methods) {
        print('     - ${method.name} (${method.method_type}): ativo=${method.activation?.isActive ?? false}');
      }
    }
    
    // ✅ ATUALIZADO: PaymentMethodGroup agora tem methods diretamente (sem categories)
    // Filtra métodos ativos e disponíveis para o tipo de entrega
    final availableMethods = store.paymentMethodGroups
        .expand((group) => group.methods)
        .where((method) {
          final activation = method.activation;
          if (activation == null || !activation.isActive) {
            print('     ❌ ${method.name} não está ativo');
            return false;
          }
          
          // Se não tiver tipo de entrega definido, mostra todos os métodos ativos
          if (deliveryType == null) {
            print('     ✅ ${method.name} adicionado (sem filtro de entrega)');
            return true;
          }
          
          // Filtra por tipo de entrega
          if (deliveryType == DeliveryType.delivery && !activation.isForDelivery) {
            print('     ❌ ${method.name} não é para delivery');
            return false;
          }
          if (deliveryType == DeliveryType.pickup && !activation.isForPickup) {
            print('     ❌ ${method.name} não é para pickup');
            return false;
          }
          
          print('     ✅ ${method.name} adicionado');
          return true;
        })
        .toList();
    
    print('   ✅ Total de métodos disponíveis: ${availableMethods.length}');
    
    if (availableMethods.isEmpty) {
      // Se não houver métodos de pagamento, emite estado sem método selecionado
      print('⚠️ Nenhum método de pagamento disponível para ${deliveryType?.name ?? "todos os tipos"}');
      print('   Verifique se há métodos de pagamento configurados na loja e se estão ativos.');
      emit(state.copyWith(selectedPaymentMethod: null));
      return;
    }
    
    // Tenta encontrar um método OFFLINE/CASH, se não encontrar, pega o primeiro disponível
    final defaultMethod = availableMethods.firstWhere(
      (m) => m.method_type == 'OFFLINE' || m.method_type == 'CASH',
      orElse: () => availableMethods.first,
    );
    
    print('✅ Método de pagamento selecionado: ${defaultMethod.name} (${defaultMethod.method_type})');
    emit(state.copyWith(selectedPaymentMethod: defaultMethod));
  }
  
  /// ✅ Atualiza método de pagamento quando tipo de entrega muda
  void updateForDeliveryType(Store store, DeliveryType deliveryType) {
    initialize(store, deliveryType: deliveryType);
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

  void updateScheduling(bool isScheduled, DateTime? scheduledFor) {
    emit(state.copyWith(isScheduled: isScheduled, scheduledFor: scheduledFor));
  }

  Future<void> placeOrder({
    required AuthState authState,
    required CartState cartState,
    required AddressState addressState,
    required DeliveryFeeState feeState,
    required Store? store,
  }) async {
    emit(state.copyWith(status: CheckoutStatus.loading));

    // ✅ VALIDAÇÃO: Verifica se pode fazer checkout
    if (store != null) {
      final deliveryType = feeState.deliveryType?.name;
      final status = StoreStatusService.canCheckout(store, deliveryType);
      if (!status.canReceiveOrders) {
        emit(state.copyWith(
          status: CheckoutStatus.error,
          errorMessage: StoreStatusService.getFriendlyMessage(status),
        ));
        return;
      }
    }

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
      // ✅ SEGURANÇA: Obtém coordenadas GPS reais do cliente
      double? customerLat;
      double? customerLng;
      
      if (feeState.deliveryType == DeliveryType.delivery) {
        try {
          final position = await GeolocationService.getCurrentPosition();
          if (position != null) {
            customerLat = position.latitude;
            customerLng = position.longitude;
            print('📍 [Checkout] Coordenadas GPS obtidas: ($customerLat, $customerLng)');
          } else {
            print('⚠️ [Checkout] Não foi possível obter coordenadas GPS');
          }
        } catch (e) {
          print('⚠️ [Checkout] Erro ao obter GPS: $e');
          // Continua sem coordenadas (backend validará)
        }
      }

      final payload = CreateOrderPayload(
        paymentMethodId: state.selectedPaymentMethod!.id,
        deliveryType: feeState.deliveryType.name,
        addressId: addressState.selectedAddress?.id,
        observation: state.observation,
        needsChange: state.needsChange,
        changeFor: state.changeFor,
        deliveryFee: deliveryFeeInCents, // Usa a variável segura
        isScheduled: state.isScheduled,
        scheduledFor: state.scheduledFor?.toIso8601String(),
        customerLatitude: customerLat,
        customerLongitude: customerLng,
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