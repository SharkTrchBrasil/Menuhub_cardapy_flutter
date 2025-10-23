// Em: lib/cubits/address/address_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';

import 'package:totem/models/customer_address.dart';
import 'package:totem/repositories/customer_repository.dart'; // Injete via DI

import 'package:equatable/equatable.dart';

part 'address_state.dart';

class AddressCubit extends Cubit<AddressState> {
  AddressCubit({required this.customerRepository}) : super(const AddressState());

  final CustomerRepository customerRepository;



  Future<void> loadAddresses(int customerId) async {
    emit(state.copyWith(status: AddressStatus.loading));
    try {
      final result = await customerRepository.getCustomerAddresses(customerId);

      if (result.isLeft) {
        final error = result.left;
        // emit(state.copyWith(status: AddressStatus.error, errorMessage: error));
      } else {
        final addresses = result.right;

        // --- ✅ LÓGICA DE SELEÇÃO INTELIGENTE ---
        CustomerAddress? selected;
        if (addresses.isNotEmpty) {
          // 2. Procura primeiro por um endereço marcado como favorito.
          selected = addresses.firstWhereOrNull((addr) => addr.isFavorite);

          // 3. Se NÃO encontrar nenhum favorito, aí sim pega o primeiro da lista como padrão.
          selected ??= addresses.first;
        }
        // --- Fim da Lógica ---

        emit(state.copyWith(
          status: AddressStatus.success,
          addresses: addresses,
          selectedAddress: selected, // Usa o endereço encontrado pela lógica acima
        ));
      }
    } catch (e) {
      emit(state.copyWith(status: AddressStatus.error, errorMessage: 'Erro ao carregar endereços.'));
    }
  }



  void selectAddress(CustomerAddress address) {
    emit(state.copyWith(selectedAddress: address));
  }

  // ✅ NOVO MÉTODO PARA SALVAR
  Future<void> saveAddress(int customerId, CustomerAddress address) async {
    // Se o endereço tem um ID, é uma atualização. Senão, é uma criação.
    if (address.id != null) {
      await _updateAddress(customerId, address);
    } else {
      await _addAddress(customerId, address);
    }
  }

  Future<void> _addAddress(int customerId, CustomerAddress address) async {
    emit(state.copyWith(status: AddressStatus.loading));
    final result = await customerRepository.addCustomerAddress(
      customerId: customerId,
      address: address,
    );

    if (result.isRight) {
      // Recarrega a lista para pegar o novo endereço com seu ID do banco
      await loadAddresses(customerId);
    } else {
    //  emit(state.copyWith(status: AddressStatus.error, errorMessage: result.left));
    }
  }

  Future<void> _updateAddress(int customerId, CustomerAddress address) async {
    emit(state.copyWith(status: AddressStatus.loading));
    final result = await customerRepository.updateCustomerAddress(
      customerId: customerId,
      address: address,
    );

    if (result.isRight) {
      await loadAddresses(customerId);
    } else {
     // emit(state.copyWith(status: AddressStatus.error, errorMessage: result.left));
    }
  }




  void addAndSelectAddress(CustomerAddress newAddress, int customerId) {
    // Atualiza a UI imediatamente para uma melhor experiência
    final updatedList = List<CustomerAddress>.from(state.addresses)..add(newAddress);
    emit(state.copyWith(
      addresses: updatedList,
      selectedAddress: newAddress,
    ));
    // Em segundo plano, recarrega a lista do servidor para garantir consistência
    loadAddresses(customerId);
  }

  Future<void> deleteAddress(int customerId, int addressId) async {
    emit(state.copyWith(status: AddressStatus.loading));
    final success = await customerRepository.deleteCustomerAddress(
      customerId,
      addressId,
    );

    if (success) {
      final updatedList = state.addresses
          .where((addr) => addr.id != addressId)
          .toList();

      CustomerAddress? newSelected;
      if (state.selectedAddress?.id == addressId) {
        if (updatedList.isNotEmpty) {
          newSelected = updatedList.firstWhereOrNull((addr) => addr.isFavorite)
              ?? updatedList.first;
        }
      } else {
        newSelected = state.selectedAddress;
      }

      emit(state.copyWith(
        addresses: updatedList,
        selectedAddress: newSelected,
        status: AddressStatus.success,
      ));
    } else {
      emit(state.copyWith(
        status: AddressStatus.error,
        errorMessage: 'Erro ao excluir endereço.',
      ));
    }
  }

}