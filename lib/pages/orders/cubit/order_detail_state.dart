part of 'order_detail_cubit.dart';

enum OrderDetailStatus { initial, loading, loaded, error, canceling }

class OrderDetailState extends Equatable {
  static const _undefined = Object();
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
    Object? errorMessage = _undefined,
  }) {
    return OrderDetailState(
      status: status ?? this.status,
      order: order ?? this.order,
      errorMessage:
          errorMessage == _undefined
              ? this.errorMessage
              : errorMessage as String?,
    );
  }

  bool get canCancel {
    return order?.orderStatus.toUpperCase() == 'PENDING';
  }

  @override
  List<Object?> get props => [status, order, errorMessage];
}
