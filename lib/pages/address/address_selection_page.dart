// Em: lib/pages/address/address_selection_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/models/delivery_type.dart';
import 'package:totem/models/store.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import '../../controllers/customer_controller.dart';
import '../../core/di.dart';
import '../../repositories/customer_repository.dart';
import 'cubits/address_cubit.dart';
import 'cubits/delivery_fee_cubit.dart';
import 'edit_adress.dart';

class AddressSelectionPage extends StatefulWidget {
  const AddressSelectionPage({super.key});

  @override
  State<AddressSelectionPage> createState() => _AddressSelectionPageState();
}

class _AddressSelectionPageState extends State<AddressSelectionPage> {
  // O estado local gerencia qual aba está selecionada
  late DeliveryType _selectedType;

  void _showEditAddressModal({CustomerAddress? addressToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Permite que o modal cresça
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        // Usamos o BlocProvider.value para passar a instância existente do AddressCubit
        // para dentro do modal, garantindo que ele possa chamar a função de salvar.
        return BlocProvider.value(
          value: context.read<AddressCubit>(),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: EditAddressPage(addressToEdit: addressToEdit),
          ),
        );
      },
    );
  }
  @override
  void initState() {
    super.initState();
    final storeConfig = context.read<StoreCubit>().state.store?.store_operation_config;
    final deliveryEnabled = storeConfig?.deliveryEnabled ?? false;
    final pickupEnabled = storeConfig?.pickupEnabled ?? false;

// Pega o estado completo
    final deliveryFeeState = context.watch<DeliveryFeeCubit>().state;

// Acessa o tipo de entrega diretamente e de forma segura
    final currentDeliveryType = deliveryFeeState.deliveryType;

    // ✅ LÓGICA DE INICIALIZAÇÃO INTELIGENTE
    // Pega o tipo de entrega atual do cubit
    DeliveryType currentType = context.read<DeliveryFeeCubit>().state.deliveryType;

    // Se o tipo atual for 'entrega' mas a entrega estiver desabilitada,
    // e a retirada estiver habilitada, muda para 'retirada'.
    if (currentType == DeliveryType.delivery && !deliveryEnabled && pickupEnabled) {
      currentType = DeliveryType.pickup;
    }
    // Se o tipo atual for 'retirada' mas a retirada estiver desabilitada,
    // e a entrega estiver habilitada, muda para 'entrega'.
    else if (currentType == DeliveryType.pickup && !pickupEnabled && deliveryEnabled) {
      currentType = DeliveryType.delivery;
    }

    _selectedType = currentType;
    // Atualiza o cubit caso a gente tenha feito uma mudança forçada
    context.read<DeliveryFeeCubit>().updateDeliveryType(_selectedType);
  }

  void _onTabSelected(DeliveryType type) {
    setState(() {
      _selectedType = type;
    });
    context.read<DeliveryFeeCubit>().updateDeliveryType(type);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreCubit>().state.store;
    // ✅ Pega as configurações de operação da loja
    final deliveryEnabled = store?.store_operation_config?.deliveryEnabled ?? false;
    final pickupEnabled = store?.store_operation_config?.pickupEnabled ?? false;

    return Scaffold(
      floatingActionButton:
      // Mostra o botão apenas se a entrega estiver habilitada e selecionada
      _selectedType == DeliveryType.delivery && deliveryEnabled
          ? FloatingActionButton(
        onPressed: () => _showEditAddressModal(),
        tooltip: 'Adicionar Novo Endereço',
        child: const Icon(Icons.add),
      )
          : null,
      appBar: AppBar(
        title: const Text('Opção de Entrega'), // Título mais claro
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            _TabSelector(
              selectedType: _selectedType,
              onSelected: _onTabSelected,
              // ✅ Passa as flags de habilitação para o seletor de abas
              deliveryEnabled: deliveryEnabled,
              pickupEnabled: pickupEnabled,
            ),
            const SizedBox(height: 24),
            Expanded(
              // ✅ LÓGICA DE EXIBIÇÃO DO CONTEÚDO
              child: _buildTabContent(deliveryEnabled, pickupEnabled, store),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ConfirmButton(
        selectedType: _selectedType,
        // ✅ Desabilita o botão de confirmar se a opção selecionada não estiver disponível
        isEnabled: (_selectedType == DeliveryType.delivery && deliveryEnabled) ||
            (_selectedType == DeliveryType.pickup && pickupEnabled),
      ),
    );
  }

  // ✅ NOVO MÉTODO para decidir qual conteúdo de aba mostrar
  Widget _buildTabContent(bool deliveryEnabled, bool pickupEnabled, Store? store) {
    if (_selectedType == DeliveryType.delivery) {
      return deliveryEnabled
          ? const _DeliveryTabContent()
          : const _UnavailableOptionMessage(
        icon: Icons.no_transfer_outlined,
        message: 'A entrega não está disponível no momento.',
      );
    } else { // _selectedType == DeliveryType.pickup
      return pickupEnabled
          ? _PickupTabContent(store: store)
          : const _UnavailableOptionMessage(
        icon: Icons.store_mall_directory_outlined,
        message: 'A retirada na loja não está disponível no momento.',
      );
    }
  }
}


// ✅ NOVO WIDGET para mensagens de indisponibilidade
class _UnavailableOptionMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  const _UnavailableOptionMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final DeliveryType selectedType;
  final bool isEnabled; // ✅ NOVO

  const _ConfirmButton({required this.selectedType, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DsPrimaryButton(
        // ✅ Usa a flag 'isEnabled' para habilitar/desabilitar
        onPressed: isEnabled
            ? () {
          final addressState = context.read<AddressCubit>().state;
          if (selectedType == DeliveryType.delivery && addressState.selectedAddress == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Por favor, selecione um endereço.')),
            );
            return;
          }
          // ✅ MUDANÇA: Use context.pop() se esta tela for sempre
          // chamada a partir da tela de endereço. É mais seguro que go().
          if (context.canPop()) {
            context.pop();
          } else {
            context.pop();
          }
        }
            : null, // Passar null desabilita o botão
        label: 'Confirmar',
      ),
    );
  }
}

// --- WIDGETS AUXILIARES PARA ESTA TELA ---

// --- WIDGETS AUXILIARES MODIFICADOS ---

class _TabSelector extends StatelessWidget {
  final DeliveryType selectedType;
  final Function(DeliveryType) onSelected;
  final bool deliveryEnabled; // ✅ NOVO
  final bool pickupEnabled;   // ✅ NOVO

  const _TabSelector({
    required this.selectedType,
    required this.onSelected,
    required this.deliveryEnabled,
    required this.pickupEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            label: 'Entregar', // Mais curto
            isSelected: selectedType == DeliveryType.delivery,
            // ✅ Desabilita o botão se a entrega não estiver ativa
            onPressed: deliveryEnabled ? () => onSelected(DeliveryType.delivery) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabButton(
            label: 'Retirar', // Mais curto
            isSelected: selectedType == DeliveryType.pickup,
            // ✅ Desabilita o botão se a retirada não estiver ativa
            onPressed: pickupEnabled ? () => onSelected(DeliveryType.pickup) : null,
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  // ... (construtor)
  final String label;
  final bool isSelected;
  final VoidCallback? onPressed; // ✅ Alterado para aceitar nulo

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // A propriedade `onPressed: null` desabilita o botão automaticamente.
    // Vamos adicionar um estilo visual para quando estiver desabilitado.
    final bool isEnabled = onPressed != null;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : (isEnabled ? Colors.red : Colors.grey),
        backgroundColor: isSelected ? Colors.red : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: isSelected ? Colors.red : (isEnabled ? Colors.red : Colors.grey.shade300)),
        ),
        elevation: isSelected ? 2 : 0,
      ),
      child: Text(label),
    );
  }
}

// Conteúdo da aba "Entregar"
class _DeliveryTabContent extends StatelessWidget {
  const _DeliveryTabContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Lista de endereços
        Expanded(
          child: BlocBuilder<AddressCubit, AddressState>(
            builder: (context, state) {
              if (state.status == AddressStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.addresses.isEmpty) {
                return const Center(child: Text('Nenhum endereço cadastrado.'));
              }
              return ListView.builder(
                itemCount: state.addresses.length,
                itemBuilder: (context, index) {
                  final address = state.addresses[index];
                  final isSelected = state.selectedAddress?.id == address.id;
                  return _AddressListItem(
                    address: address,
                    isSelected: isSelected,
                    onTap: () {
                      context.read<AddressCubit>().selectAddress(address);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddressListItem extends StatefulWidget {
  final CustomerAddress address;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddressListItem({
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AddressListItem> createState() => _AddressListItemState();
}

class _AddressListItemState extends State<_AddressListItem> {
  @override
  Widget build(BuildContext context) {
    final addressLine1 = '${widget.address.street}, ${widget.address.number}';
    final addressLine2 = '${widget.address.neighborhood} - ${widget.address.city}';

    return Card(
      elevation: widget.isSelected ? 4 : 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isSelected ? Colors.red : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: widget.onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: const Icon(Icons.home_outlined, color: Colors.black54),
        ),
        title: Text(
          widget.address.label ?? 'Endereço',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$addressLine1\n$addressLine2'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isSelected) const Icon(Icons.check_circle, color: Colors.red),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  // Abre o modal de edição
                  final parentState =
                      context
                          .findAncestorStateOfType<
                            _AddressSelectionPageState
                          >();
                  parentState?._showEditAddressModal(addressToEdit: widget.address);
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: const Text('Excluir Endereço'),
                          content: const Text(
                            'Tem certeza que deseja excluir este endereço?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                  );

                  // Verifica se o widget ainda está montado antes de continuar
                  if (!mounted) return;

                  if (confirm == true) {
                    final customerId = getIt<CustomerController>().customer!.id;
                    final deleted = await getIt<CustomerRepository>()
                        .deleteCustomerAddress(customerId!, widget.address.id!);

                    // Verifica novamente se o widget ainda está montado
                    if (!mounted) return;

                    if (deleted) {
                      context.read<AddressCubit>().deleteAddress(
                        customerId,
                        widget.address.id!,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Endereço excluído com sucesso!'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Erro ao excluir endereço.'),
                        ),
                      );
                    }
                  }
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.black54),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Excluir'),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }
}

// Conteúdo da aba "Retirar na loja"
class _PickupTabContent extends StatelessWidget {
  final Store? store;

  const _PickupTabContent({required this.store});

  @override
  Widget build(BuildContext context) {
    if (store == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final address = store!;
    final addressLine1 = '${address.street}, ${address.number}';
    final addressLine2 = '${address.neighborhood} - ${address.city}';
    final String? imageUrl = address.image!.url;
    return Card(
      child: ListTile(
        leading: Container(
          decoration: BoxDecoration(
            // Borda sutil para dar um acabamento
            border: Border.all(color: Colors.grey.shade300, width: 1),
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 28, // Um pouco menor para se ajustar bem ao ListTile
            backgroundColor: Colors.grey.shade100, // Fundo para o caso de não ter imagem
            // Mostra a imagem da rede se a URL existir e não estiver vazia
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                ? NetworkImage(imageUrl)
                : null,
            // ✅ BOA PRÁTICA: Se não houver imagem, mostra um ícone padrão
            child: (imageUrl == null || imageUrl.isEmpty)
                ? const Icon(
              Icons.store_mall_directory_outlined,
              color: Colors.black54,
              size: 24,
            )
                : null,
          ),
        ),
        title: Text(
          store!.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$addressLine1\n$addressLine2'),
      ),
    );
  }
}


