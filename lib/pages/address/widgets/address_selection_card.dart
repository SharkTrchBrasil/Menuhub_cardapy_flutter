// Em: pages/checkout/widgets/_address_display_and_selection.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:totem/models/customer_address.dart';
import 'package:totem/services/dialog_service.dart';


import '../../../cubit/auth_cubit.dart';
import '../../../cubit/store_cubit.dart';
import '../cubits/address_cubit.dart';
import '../edit_adress.dart';

class AddressDisplayAndSelection extends StatelessWidget {
  const AddressDisplayAndSelection({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ CORREÇÃO 1: Ouve o AddressCubit, que é o especialista em endereços.
    return BlocBuilder<AddressCubit, AddressState>(
      builder: (context, state) {
        final selectedAddress = state.selectedAddress;
        final customerAddresses = state.addresses;

        return GestureDetector(
          // ✅ CORREÇÃO 2: A lógica agora verifica se a lista está VAZIA.
          onTap: () {
            if (customerAddresses.isEmpty) {
              _openEditAddressPage(context);
            } else {
              _showAddressSelectionBottomSheet(context, customerAddresses);
            }
          },
          child: Container(
            // Estilização do Container (pode adicionar de volta a borda, etc.)
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 30, color: Colors.blueAccent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectedAddress != null) ...[
                        Text(
                          '${selectedAddress.street}, ${selectedAddress.number}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${selectedAddress.neighborhood} - ${selectedAddress.city}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ] else
                        const Text(
                          'Nenhum endereço. Toque para adicionar.',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddressSelectionBottomSheet(
      BuildContext context, List<CustomerAddress> addresses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que o conteúdo cresça
      builder: (BuildContext bc) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecione um endereço',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Limita a altura caso haja muitos endereços
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: addresses.map((address) {
                      final currentState = context.read<AddressCubit>().state;
                      final isSelected = currentState.selectedAddress?.id == address.id;

                      // Usamos um ListTile para ter mais controle
                      return ListTile(
                        // A ação principal do ListTile é selecionar o endereço
                        onTap: () {
                          context.read<AddressCubit>().selectAddress(address);
                          Navigator.pop(context); // Fecha o bottom sheet
                        },
                        leading: Radio<CustomerAddress>(
                          value: address,
                          groupValue: currentState.selectedAddress,
                          onChanged: (newAddress) {
                            if (newAddress != null) {
                              context.read<AddressCubit>().selectAddress(newAddress);
                              Navigator.pop(context);
                            }
                          },
                        ),
                        title: Text('${address.street}, ${address.number}'),
                        subtitle: Text('${address.neighborhood}, ${address.city}'),

                        // ✅ AQUI ADICIONAMOS O BOTÃO DE EDITAR
                        trailing: IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Theme.of(context).primaryColor.withOpacity(0.8),
                          ),
                          onPressed: () {
                            // 1. Fecha o BottomSheet atual para não ficar um sobre o outro
                            Navigator.pop(context);

                            _openEditAddressPage(context, addressToEdit: address);


                          },
                        ),
                      );




                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Adicionar Novo Endereço'),
                  onPressed: () {
                    Navigator.pop(context); // Fecha o bottom sheet
                    _openEditAddressPage(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Dentro da sua AddressPage (ou onde você chama o Dialog)

  void _openEditAddressPage(BuildContext context, {CustomerAddress? addressToEdit}) {
    final customerId = context.read<AuthCubit>().state.customer!.id!;
    final store = context.read<StoreCubit>().state.store!;

    showDialog(
      context: context,
      builder: (_) {
        return BlocProvider.value(
          value: context.read<AddressCubit>(), // Pega o Cubit que JÁ EXISTE no context da página
          child: EditAddressPage(
            addressToEdit: addressToEdit,
          ),
        );
      },
    );
  }
}