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
  OrdersCubit({
    required this.orderRepository,
  }) : super(const OrdersState());

  final OrderRepository orderRepository;

  /// Carrega os pedidos do cliente
  Future<void> loadOrders(int customerId) async {
    if (state.status == OrdersStatus.loading) return;
    
    emit(state.copyWith(status: OrdersStatus.loading));
    
    try {
      final result = await orderRepository.getCustomerOrders(customerId);
      
      result.fold(
        (error) {
          AppLogger.error('Erro ao carregar pedidos: $error', tag: 'ORDERS');
          emit(state.copyWith(
            status: OrdersStatus.error,
            errorMessage: error,
          ));
        },
        (orders) {
          AppLogger.success('Pedidos carregados: ${orders.length}', tag: 'ORDERS');
          emit(state.copyWith(
            status: OrdersStatus.success,
            orders: orders,
          ));
        },
      );
    } catch (e) {
      AppLogger.error('Erro inesperado ao carregar pedidos', error: e, tag: 'ORDERS');
      emit(state.copyWith(
        status: OrdersStatus.error,
        errorMessage: 'Erro inesperado: $e',
      ));
    }
  }

  /// Recarrega os pedidos (force refresh)
  Future<void> refreshOrders(int customerId) async {
    emit(state.copyWith(status: OrdersStatus.loading));
    await loadOrders(customerId);
  }

  /// Adiciona um novo pedido à lista (após criar um pedido)
  void addOrder(Order order) {
    final updatedOrders = [order, ...state.orders];
    emit(state.copyWith(orders: updatedOrders));
  }

  /// Atualiza um pedido na lista (via WebSocket update)
  /// Recarrega do servidor para garantir consistência
  void updateOrder(String orderId) {
    // O modelo Order é imutável - precisa fazer refresh
    // Por agora, apenas logamos que houve atualização
    AppLogger.info('Pedido $orderId atualizado via WebSocket', tag: 'ORDERS');
    // TODO: Implementar atualização incremental se necessário
  }

  /// Remove um pedido da lista (cancelado)
  void removeOrder(String orderId) {
    final updatedOrders = state.orders.where((o) => o.id != orderId).toList();
    emit(state.copyWith(orders: updatedOrders));
  }

  /// Limpa os pedidos (ao fazer logout)
  void clearOrders() {
    emit(const OrdersState());
  }
}
