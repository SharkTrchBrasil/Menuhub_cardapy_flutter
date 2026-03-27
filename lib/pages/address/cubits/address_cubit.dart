// Em: lib/cubits/address/address_cubit.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';

import 'package:totem/models/customer_address.dart';
import 'package:totem/repositories/customer_repository.dart'; // Injete via DI

import 'package:equatable/equatable.dart';

import 'package:totem/core/di.dart';
import 'package:totem/controllers/customer_controller.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/models/store.dart';

part 'address_state.dart';

class AddressCubit extends Cubit<AddressState> {
  AddressCubit({required this.customerRepository})
    : super(const AddressState()) {
    _subscribeToStoreChanges();
  }

  final CustomerRepository customerRepository;
  StreamSubscription<StoreState>? _storeSubscription;
  Store? _lastStore;

  /// ✅ FIX BUG 4: Guarda hash das regras de frete para comparar apenas elas
  String _lastDeliveryRulesHash = '';

  /// Gera um hash simples das regras de frete ativas para detectar mudanças reais
  String _buildDeliveryRulesHash(Store store) {
    final rules = store.deliveryFeeRules;
    if (rules.isEmpty) return 'empty';
    final sb = StringBuffer();
    for (final r in rules) {
      sb.write('${r.id}_${r.isActive}_${r.ruleType}_${r.config.hashCode}_');
      sb.write('${r.freeDeliveryThreshold}_${r.deliveryMethod};');
    }
    return sb.toString();
  }

  void _subscribeToStoreChanges() {
    final storeCubit = getIt<StoreCubit>();
    _lastStore = storeCubit.state.store;
    if (_lastStore != null) {
      _lastDeliveryRulesHash = _buildDeliveryRulesHash(_lastStore!);
    }

    // ✅ FIX BUG 4: Escuta mudanças APENAS nas regras de frete, não em todo o Store
    _storeSubscription = storeCubit.stream.listen((storeState) {
      if (state.addresses.isNotEmpty && storeState.store != null) {
        final newHash = _buildDeliveryRulesHash(storeState.store!);
        if (newHash != _lastDeliveryRulesHash) {
          _lastDeliveryRulesHash = newHash;
          _lastStore = storeState.store;
          // ✅ FIX BUG 2: Invalida cache do DeliveryFeeCubit antes de recalcular
          try {
            final feeCubit = getIt<DeliveryFeeCubit>();
            feeCubit.invalidateCache();
            // ✅ FIX BUG 6: Recalcula NON-silent para o endereço selecionado
            // Isso faz o DeliveryFeeCubit emitir novo estado → checkout rebuilda
            if (state.selectedAddress != null) {
              double cartSubtotal = 0;
              try {
                final cartCubit = getIt<CartCubit>();
                cartSubtotal = cartCubit.state.cart.subtotal / 100.0;
              } catch (_) {}
              feeCubit.calculate(
                address: state.selectedAddress,
                store: storeState.store!,
                cartSubtotal: cartSubtotal,
              );
            }
          } catch (_) {}
          _precalculateAllFees(state.addresses);
        } else {
          _lastStore = storeState.store;
        }
      }
    });
  }

  @override
  Future<void> close() {
    _storeSubscription?.cancel();
    return super.close();
  }

  void clearAddresses() {
    emit(const AddressState());
  }

  Future<void> loadAddresses(int customerId) async {
    emit(state.copyWith(status: AddressStatus.loading));
    try {
      final result = await customerRepository.getCustomerAddresses(customerId);

      if (result.isLeft) {
        // ✅ CORREÇÃO: Emite estado de erro para não ficar em loading infinito
        // result.left é void, então usamos uma mensagem padrão
        emit(
          state.copyWith(
            status: AddressStatus.error,
            errorMessage: 'Erro ao carregar endereços.',
            addresses: const [], // Lista vazia em caso de erro
          ),
        );
      } else {
        final addresses = result.right;

        // --- ✅ LÓGICA DE SELEÇÃO INTELIGENTE REFORÇADA ---
        CustomerAddress? selected;
        if (addresses.isNotEmpty) {
          // 1. Procura por endereços marcados como favorito
          final favorites = addresses.where((addr) => addr.isFavorite).toList();

          if (favorites.isNotEmpty) {
            // Se houver múltiplos favoritos (erro de sync), pega o com maior ID (mais recente)
            favorites.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
            selected = favorites.first;
          } else {
            // 2. Se NÃO encontrar nenhum favorito, pega o primeiro da lista como fallback
            selected = addresses.first;
          }
        }
        // --- Fim da Lógica ---

        emit(
          state.copyWith(
            status: AddressStatus.success,
            addresses: addresses,
            selectedAddress: selected,
            addressFees: {}, // Reset
          ),
        );

        // ✅ PRE-CÁLCULO DE FRETE
        _precalculateAllFees(addresses);
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: AddressStatus.error,
          errorMessage: 'Erro ao carregar endereços.',
        ),
      );
    }
  }

  /// ✅ OTIMIZAÇÃO: Popula endereços diretamente a partir da resposta do login
  /// Evita chamada HTTP separada para /customer/{id}/addresses
  void setAddressesFromLogin(List<CustomerAddress> addresses) {
    // --- ✅ LÓGICA DE SELEÇÃO INTELIGENTE REFORÇADA ---
    CustomerAddress? selected;
    if (addresses.isNotEmpty) {
      final favorites = addresses.where((addr) => addr.isFavorite).toList();

      if (favorites.isNotEmpty) {
        favorites.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        selected = favorites.first;
      } else {
        selected = addresses.first;
      }
    }
    // --- Fim da Lógica ---

    emit(
      state.copyWith(
        status: AddressStatus.success,
        addresses: addresses,
        selectedAddress: selected,
        addressFees: {}, // Reset
      ),
    );

    // ✅ PRE-CÁLCULO DE FRETE
    _precalculateAllFees(addresses);
  }

  void _precalculateAllFees(List<CustomerAddress> addresses) {
    try {
      final feeCubit = getIt<DeliveryFeeCubit>();
      final storeCubit = getIt<StoreCubit>();
      final store = storeCubit.state.store;

      // ✅ FIX BUG 3: Usa subtotal real do carrinho para cálculo correto de frete grátis
      double cartSubtotal = 0;
      try {
        final cartCubit = getIt<CartCubit>();
        cartSubtotal = cartCubit.state.cart.subtotal / 100.0;
      } catch (_) {
        // CartCubit pode não estar disponível ainda (antes do login)
      }

      if (store != null) {
        for (var addr in addresses) {
          if (addr.id != null) {
            feeCubit.calculate(
              address: addr,
              store: store,
              cartSubtotal: cartSubtotal,
              isSilent: true,
              onResult: (fee, error) {
                setAddressFee(addr.id!, fee, isOutOfArea: error != null);
              },
            );
          }
        }
      }
    } catch (e) {
      print('⚠️ Erro ao disparar pré-cálculo de fretes: $e');
    }
  }

  void setAddressFee(int addressId, double? fee, {bool isOutOfArea = false}) {
    final newFees = Map<int, double?>.from(state.addressFees);
    newFees[addressId] = isOutOfArea ? -1.0 : fee;
    emit(state.copyWith(addressFees: newFees));
  }

  Future<void> selectAddress(CustomerAddress address) async {
    // Primeiro emite para a UI ficar rápida
    emit(state.copyWith(selectedAddress: address));

    // Se o endereço já é favorito, não precisa fazer nada no backend
    if (address.isFavorite) return;

    // Se tiver ID, marca como favorito no backend
    if (address.id != null) {
      try {
        final updatedAddress = address.copyWith(isFavorite: true);
        final customerId = getIt<CustomerController>().customer?.id;

        if (customerId != null) {
          // Fazemos o update de forma "silenciosa".
          // O Socket.IO se encarregará de atualizar a lista completa quando o servidor confirmar.
          customerRepository.updateCustomerAddress(
            customerId: customerId,
            address: updatedAddress,
          );
        }
      } catch (e) {
        print('⚠️ Erro ao salvar endereço selecionado como padrão: $e');
      }
    }
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
    final updatedList = List<CustomerAddress>.from(state.addresses)
      ..add(newAddress);
    emit(state.copyWith(addresses: updatedList, selectedAddress: newAddress));
    // Em segundo plano, recarrega a lista do servidor para garantir consistência
    loadAddresses(customerId);
  }

  Future<void> deleteAddress(int customerId, int addressId) async {
    // 1. Atualização Otimista: Remove da lista local imediatamente
    final updatedList =
        state.addresses.where((addr) => addr.id != addressId).toList();

    CustomerAddress? newSelected = state.selectedAddress;
    if (state.selectedAddress?.id == addressId) {
      if (updatedList.isNotEmpty) {
        newSelected =
            updatedList.firstWhereOrNull((addr) => addr.isFavorite) ??
            updatedList.first;
      } else {
        newSelected = null;
      }
    }

    emit(
      state.copyWith(
        addresses: updatedList,
        selectedAddress: newSelected,
        status: AddressStatus.success,
      ),
    );

    // 2. Envia para o servidor em background
    try {
      await customerRepository.deleteCustomerAddress(customerId, addressId);
      // O evento Socket.IO 'address_deleted' chegará para confirmar,
      // mas a UI já está atualizada.
    } catch (e) {
      print('❌ Erro ao excluir endereço no backend: $e');
      // Em caso de erro real, poderíamos recarregar a lista ou mostrar um erro
    }
  }

  /// ✅ REAL-TIME: Trata eventos granulares recebidos via Socket.IO
  void onRealtimeAddressEvent(Map<String, dynamic> payload) {
    try {
      final action = payload['action'] as String;
      final addressData = payload['address'];
      final addressId = payload['address_id'] as int?;

      final currentAddresses = List<CustomerAddress>.from(state.addresses);

      switch (action) {
        case 'created':
          if (addressData != null) {
            final newAddress = CustomerAddress.fromJson(addressData);
            if (!currentAddresses.any((a) => a.id == newAddress.id)) {
              currentAddresses.add(newAddress);
              print(
                '✅ [AddressCubit] Novo endereço adicionado via Real-time: ${newAddress.street}',
              );
            }
          }
          break;
        case 'updated':
          if (addressData != null) {
            final updatedAddress = CustomerAddress.fromJson(addressData);
            final index = currentAddresses.indexWhere(
              (a) => a.id == updatedAddress.id,
            );
            if (index != -1) {
              currentAddresses[index] = updatedAddress;
              print(
                '✅ [AddressCubit] Endereço atualizado via Real-time: ${updatedAddress.street}',
              );
            } else {
              currentAddresses.add(updatedAddress);
            }

            // Se este endereço agora é o favorito, desmarca todos os outros localmente
            if (updatedAddress.isFavorite) {
              for (var i = 0; i < currentAddresses.length; i++) {
                if (currentAddresses[i].id != updatedAddress.id) {
                  currentAddresses[i] = currentAddresses[i].copyWith(
                    isFavorite: false,
                  );
                }
              }
            }
          }
          break;
        case 'deleted':
          if (addressId != null) {
            currentAddresses.removeWhere((a) => a.id == addressId);
            print(
              '✅ [AddressCubit] Endereço $addressId removido via Real-time',
            );
          }
          break;
      }

      // Re-avalia endereço selecionado se houver mudanças que o afetem
      CustomerAddress? newSelected = state.selectedAddress;
      if (action == 'deleted' && state.selectedAddress?.id == addressId) {
        if (currentAddresses.isNotEmpty) {
          newSelected =
              currentAddresses.firstWhereOrNull((addr) => addr.isFavorite) ??
              currentAddresses.first;
        } else {
          newSelected = null;
        }
      } else if (action == 'updated' && addressData != null) {
        final updatedAddress = CustomerAddress.fromJson(addressData);
        // Se o endereço atualizado foi marcado como favorito, ele torna-se o selecionado
        if (updatedAddress.isFavorite) {
          newSelected = updatedAddress;
        } else if (state.selectedAddress?.id == updatedAddress.id) {
          newSelected = updatedAddress;
        }
      }

      emit(
        state.copyWith(
          addresses: currentAddresses,
          selectedAddress: newSelected,
          status: AddressStatus.success,
        ),
      );

      // ✅ Atualiza cálculos de frete para a nova lista se não foi deleção
      if (action != 'deleted') {
        _precalculateAllFees(currentAddresses);
      }
    } catch (e) {
      print('❌ [AddressCubit] Erro ao processar evento real-time: $e');
    }
  }
}
