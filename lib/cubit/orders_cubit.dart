// lib/cubit/orders_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:totem/models/order.dart';
import 'package:totem/repositories/order_repository.dart';
import 'package:totem/core/utils/app_logger.dart';

part 'orders_state.dart';

/// OrdersCubit global - gerencia os pedidos do cliente logado
/// Carregado automaticamente após o login para ter os pedidos disponíveis
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({required this.orderRepository}) : super(const OrdersState());

  final OrderRepository orderRepository;

  /// Carrega os pedidos do cliente
  Future<void> loadOrders(int customerId) async {
    if (state.status == OrdersStatus.loading) return;

    emit(state.copyWith(status: OrdersStatus.loading));

    try {
      final result = await orderRepository.getCustomerOrders(customerId);

      result.fold(
        (error) {
          AppLogger.e('Erro ao carregar pedidos: $error', tag: 'ORDERS');
          emit(state.copyWith(status: OrdersStatus.error, errorMessage: error));
        },
        (orders) {
          AppLogger.i('Pedidos carregados: ${orders.length}', tag: 'ORDERS');
          emit(state.copyWith(status: OrdersStatus.success, orders: orders));
        },
      );
    } catch (e) {
      AppLogger.e(
        'Erro inesperado ao carregar pedidos',
        error: e,
        tag: 'ORDERS',
      );
      emit(
        state.copyWith(
          status: OrdersStatus.error,
          errorMessage: 'Erro inesperado: $e',
        ),
      );
    }
  }

  /// Recarrega os pedidos (force refresh)
  Future<void> refreshOrders(int customerId) async {
    emit(state.copyWith(status: OrdersStatus.loading));
    await loadOrders(customerId);
  }

  /// ✅ OTIMIZAÇÃO: Popula pedidos diretamente a partir da resposta do login
  /// Evita chamada HTTP separada para /customer/{id}/orders
  void setOrdersFromLogin(List<Order> orders) {
    emit(state.copyWith(status: OrdersStatus.success, orders: orders));
    AppLogger.d(
      '${orders.length} pedidos carregados do login (sem HTTP)',
      tag: 'ORDERS',
    );
  }

  /// Adiciona um novo pedido à lista (após criar um pedido)
  void addOrder(Order order) {
    final updatedOrders = [order, ...state.orders];
    emit(state.copyWith(orders: updatedOrders));
  }

  /// Atualiza um pedido na lista (via WebSocket update)
  void onRealtimeOrderUpdate(Order order) {
    final currentOrders = List<Order>.from(state.orders);
    final index = currentOrders.indexWhere((o) => o.id == order.id);

    if (index != -1) {
      currentOrders[index] = order;
      emit(state.copyWith(orders: currentOrders));
      AppLogger.i(
        '✅ [ORDERS] Pedido ${order.shortId} atualizado via Real-time (status: ${order.lastStatus})',
        tag: 'ORDERS',
      );
    } else {
      // Se não encontrou (ex: pedido novo de outro totem ou se a lista estava vazia)
      addOrder(order);
    }
  }

  /// Remove um pedido da lista (cancelado)
  void removeOrder(String orderId) {
    final updatedOrders = state.orders.where((o) => o.id != orderId).toList();
    emit(state.copyWith(orders: updatedOrders));
  }

  /// Cancela um pedido
  Future<void> cancelOrder(int orderId, {String? reason}) async {
    try {
      final result = await orderRepository.cancelOrder(
        orderId: orderId,
        reason: reason,
      );

      result.fold(
        (error) {
          AppLogger.e(
            'Erro ao cancelar pedido $orderId: $error',
            tag: 'ORDERS',
          );
        },
        (_) {
          AppLogger.i('Pedido $orderId cancelado com sucesso', tag: 'ORDERS');
          // A atualização virá via WebSocket (onRealtimeOrderUpdate),
          // mas opcionalmente podemos marcar localmente
        },
      );
    } catch (e) {
      AppLogger.e(
        'Erro inesperado ao cancelar pedido',
        error: e,
        tag: 'ORDERS',
      );
    }
  }

  /// Limpa os pedidos (ao fazer logout)
  void clearOrders() {
    emit(const OrdersState());
  }
}
