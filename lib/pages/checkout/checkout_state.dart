// Em: lib/pages/checkout/checkout_state.dart
part of 'checkout_cubit.dart';

enum CheckoutStatus { initial, loading, success, error }

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.selectedPaymentMethod,
    this.needsChange = false,
    this.changeFor,
    this.observation,
    this.finalOrder,
    this.isScheduled = false,
    this.scheduledFor,
    this.errorMessage, // ✅ 1. Adicione a propriedade aqui
  });

  final CheckoutStatus status;
  final PlatformPaymentMethod? selectedPaymentMethod;
  final bool needsChange;
  final double? changeFor;
  final String? observation;
  final Order? finalOrder;
  final bool isScheduled;
  final DateTime? scheduledFor;
  final String? errorMessage;


  CheckoutState copyWith({
    CheckoutStatus? status,
    PlatformPaymentMethod? selectedPaymentMethod,
    bool? needsChange,
    double? changeFor,
    String? observation,
    Order? finalOrder,
    bool? isScheduled,
    DateTime? scheduledFor,
    String? errorMessage, // ✅ 2. Adicione o parâmetro aqui
  }) {
    return CheckoutState(
      status: status ?? this.status,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      needsChange: needsChange ?? this.needsChange,
      changeFor: changeFor ?? this.changeFor,
      observation: observation ?? this.observation,
      finalOrder: finalOrder ?? this.finalOrder,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      errorMessage: errorMessage, // ✅ 3. Adicione a atribuição aqui
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedPaymentMethod,
    needsChange,
    changeFor,
    observation,
    finalOrder,
    isScheduled,
    scheduledFor,
    errorMessage, // ✅ 4. Adicione à lista de props
  ];
}