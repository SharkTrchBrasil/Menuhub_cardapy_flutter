// lib/widgets/address_add_flow.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/models/store.dart';
import 'package:totem/models/store_city.dart';
import 'package:totem/models/store_neig.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/services/address_search_service.dart';
import 'package:totem/widgets/address_autocomplete_field.dart';
import 'package:totem/widgets/mapbox_address_map.dart';

/// Dialog com múltiplos steps para adicionar endereço (estilo iFood)
class AddressAddFlow extends StatefulWidget {
  const AddressAddFlow({super.key});

  @override
  State<AddressAddFlow> createState() => _AddressAddFlowState();
}

enum AddressFlowStep {
  search,    // Step 1: Busca de endereço
  map,       // Step 2: Mapa com formulário integrado
}

class _AddressAddFlowState extends State<AddressAddFlow> {
  AddressFlowStep _currentStep = AddressFlowStep.search;
  AddressSearchResult? _selectedAddress;
  double? _mapLatitude;
  double? _mapLongitude;

  void _onAddressSelected(AddressSearchResult result) {
    setState(() {
      _selectedAddress = result;
      _mapLatitude = result.latitude;
      _mapLongitude = result.longitude;
      _currentStep = AddressFlowStep.map;
    });
  }

  void _onMapConfirmed(double latitude, double longitude, Map<String, String> formData) async {
    final authState = context.read<AuthCubit>().state;
    if (authState.status != AuthStatus.success || authState.customer == null) {
      return;
    }

    final customerId = authState.customer!.id!;
    final store = context.read<StoreCubit>().state.store!;

    final newAddress = CustomerAddress(
      label: formData['favorite'] ?? '',
      isFavorite: formData['favorite']?.isNotEmpty ?? false,
      street: formData['street'] ?? '',
      number: formData['number'] ?? '',
      complement: formData['complement'],
      neighborhood: formData['neighborhood'] ?? '',
      city: formData['city'] ?? '',
      reference: formData['reference'],
      cityId: formData['cityId']?.isNotEmpty == true ? int.tryParse(formData['cityId']!) : null,
      neighborhoodId: formData['neighborhoodId']?.isNotEmpty == true ? int.tryParse(formData['neighborhoodId']!) : null,
      latitude: latitude,
      longitude: longitude,
    );

    final tempDeliveryFeeCubit = DeliveryFeeCubit();

    await tempDeliveryFeeCubit.calculate(
      address: newAddress,
      store: store,
      cartSubtotal: 0,
    );

    final deliveryState = tempDeliveryFeeCubit.state;

    if (deliveryState is DeliveryFeeError) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Endereço fora da área'),
            content: Text(deliveryState.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      await context.read<AddressCubit>().saveAddress(customerId, newAddress);
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sucesso!'),
            content: const Text('Endereço adicionado com sucesso!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Fecha dialog de sucesso
                  Navigator.pop(context); // Fecha dialog principal
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Erro'),
            content: Text('Erro ao salvar endereço: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _onBack() {
    if (_currentStep == AddressFlowStep.map) {
      setState(() => _currentStep = AddressFlowStep.search);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreCubit>().state.store;
    if (store == null) {
      return const Center(child: Text('Erro: Loja não encontrada'));
    }

    // ✅ Dialog com steps - muda conteúdo dentro do mesmo dialog
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.white,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStep(store),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(Store store) {
    switch (_currentStep) {
      case AddressFlowStep.search:
        return _buildSearchStep(store);
      case AddressFlowStep.map:
        return _buildMapStep(store);
    }
  }

  Widget _buildSearchStep(Store store) {
    return Column(
      key: const ValueKey('search'),
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Onde você quer receber seu pedido?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey.shade600),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Campo de busca
        Padding(
          padding: const EdgeInsets.all(16),
          child: AddressAutocompleteField(
            onAddressSelected: _onAddressSelected,
          ),
        ),

        // Lista vazia inicial
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Digite seu endereço para buscar',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapStep(Store store) {
    if (_mapLatitude == null || _mapLongitude == null) {
      return const Center(child: Text('Erro: Coordenadas não disponíveis'));
    }

    return MapboxAddressMap(
      key: const ValueKey('map'),
      initialLatitude: _mapLatitude!,
      initialLongitude: _mapLongitude!,
      addressDescription: _selectedAddress?.description ?? '',
      store: store,
      onConfirmed: _onMapConfirmed,
      onBack: _onBack,
    );
  }
}

