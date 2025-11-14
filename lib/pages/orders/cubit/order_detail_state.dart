part of 'order_detail_cubit.dart';

enum OrderDetailStatus {
  initial,
  loading,
  loaded,
  error,
  canceling,
}

class OrderDetailState extends Equatable {
  final OrderDetailStatus status;
  final Order? order;
  final String? errorMessage;

  const OrderDetailState({
    this.status = OrderDetailStatus.initial,
    this.order,
    this.errorMessage,
  });

  OrderDetailState copyWith({
    OrderDetailStatus? status,
    Order? order,
    String? errorMessage,
  }) {
    return OrderDetailState(
      status: status ?? this.status,
      order: order ?? this.order,
      errorMessage: errorMessage,
    );
  }

  bool get canCancel {
    return order?.orderStatus.toUpperCase() == 'PENDING';
  }

  @override
  List<Object?> get props => [status, order, errorMessage];
}

