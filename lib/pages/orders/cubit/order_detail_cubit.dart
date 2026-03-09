import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:totem/models/order.dart';
import 'package:totem/repositories/order_repository.dart';
import 'package:totem/repositories/realtime_repository.dart';

part 'order_detail_state.dart';

class OrderDetailCubit extends Cubit<OrderDetailState> {
  final OrderRepository _orderRepository;
  final RealtimeRepository _realtimeRepository;
  StreamSubscription? _orderUpdateSubscription;
  final int orderId;

  OrderDetailCubit({
    required OrderRepository orderRepository,
    required RealtimeRepository realtimeRepository,
    required this.orderId,
    Order? initialOrder,
  }) : _orderRepository = orderRepository,
       _realtimeRepository = realtimeRepository,
       super(
         initialOrder != null
             ? OrderDetailState(
               status: OrderDetailStatus.loaded,
               order: initialOrder,
             )
             : const OrderDetailState(),
       ) {
    if (initialOrder == null) {
      _loadOrder();
    }
    _listenToOrderUpdates();
  }

  Future<void> _loadOrder() async {
    emit(state.copyWith(status: OrderDetailStatus.loading));

    final result = await _orderRepository.getOrderById(orderId);

    if (result.isLeft) {
      emit(
        state.copyWith(
          status: OrderDetailStatus.error,
          errorMessage: result.left,
        ),
      );
      return;
    }

    emit(state.copyWith(status: OrderDetailStatus.loaded, order: result.right));
  }

  void _listenToOrderUpdates() {
    // ✅ Escuta atualizações em tempo real do pedido via Socket.IO
    _orderUpdateSubscription = _realtimeRepository.orderController.stream.listen(
      (updatedOrder) {
        // ✅ Só atualiza se for o mesmo pedido
        if (updatedOrder.id == orderId.toString()) {
          emit(state.copyWith(order: updatedOrder));
          print(
            '🔄 [OrderDetailCubit] Pedido atualizado em tempo real: ${updatedOrder.orderStatus}',
          );
        }
      },
      onError: (error) {
        print('❌ [OrderDetailCubit] Erro ao escutar atualizações: $error');
      },
    );
  }

  Future<void> cancelOrder({String? reason}) async {
    if (state.order == null) return;

    final currentOrder = state.order!;

    // ✅ Verifica se pode cancelar
    if (currentOrder.orderStatus.toUpperCase() != 'PENDING') {
      emit(
        state.copyWith(
          status: OrderDetailStatus.error,
          errorMessage: 'Pedido não pode mais ser cancelado',
        ),
      );
      return;
    }

    emit(state.copyWith(status: OrderDetailStatus.canceling));

    final result = await _orderRepository.cancelOrder(
      orderId: orderId,
      reason: reason ?? 'Cancelado pelo cliente',
    );

    if (result.isLeft) {
      emit(
        state.copyWith(
          status: OrderDetailStatus.error,
          errorMessage: result.left,
        ),
      );
      return;
    }

    // ✅ Recarrega o pedido para ter o status atualizado
    await _loadOrder();
  }

  Future<void> refreshOrder() async {
    await _loadOrder();
  }

  @override
  Future<void> close() {
    _orderUpdateSubscription?.cancel();
    return super.close();
  }
}
