// lib/cubit/orders_state.dart
part of 'orders_cubit.dart';

enum OrdersStatus { initial, loading, success, error }

class OrdersState extends Equatable {
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.errorMessage,
  });

  final OrdersStatus status;
  final List<Order> orders;
  final String? errorMessage;

  /// Pedidos em andamento (ativos) - usa lastStatus do modelo iFood
  List<Order> get activeOrders {
    return orders.where((o) => o.isActive).toList();
  }

  /// Pedidos do histórico (finalizados) - usa lastStatus do modelo iFood
  List<Order> get historyOrders {
    return orders.where((o) => !o.isActive).toList();
  }

  /// Conta de pedidos ativos (para badge no menu)
  int get activeOrdersCount => activeOrders.length;

  OrdersState copyWith({
    OrdersStatus? status,
    List<Order>? orders,
    String? errorMessage,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, orders, errorMessage];
}
