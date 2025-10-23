// Em: lib/cubits/address/address_state.dart
part of 'address_cubit.dart';

enum AddressStatus { initial, loading, success, error }

class AddressState extends Equatable {
  const AddressState({
    this.status = AddressStatus.initial,
    this.addresses = const [],
    this.selectedAddress,
    this.errorMessage,
  });

  final AddressStatus status;
  final List<CustomerAddress> addresses;
  final CustomerAddress? selectedAddress;
  final String? errorMessage;

  AddressState copyWith({
    AddressStatus? status,
    List<CustomerAddress>? addresses,
    // Permite explicitamente que o endereço selecionado seja nulo
    CustomerAddress? selectedAddress,
    bool forceNullSelectedAddress = false,
    String? errorMessage,
  }) {
    return AddressState(
      status: status ?? this.status,
      addresses: addresses ?? this.addresses,
      selectedAddress: forceNullSelectedAddress ? null : selectedAddress ?? this.selectedAddress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, addresses, selectedAddress, errorMessage];
}