// Em: lib/pages/address/address_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/pages/address/widgets/Address_bottom_bar.dart';

import '../../cubit/auth_cubit.dart';
import '../../cubit/store_cubit.dart';
import '../../cubit/store_state.dart';
import '../../models/delivery_type.dart';
import '../../models/store.dart';
import '../cart/cart_cubit.dart';
import '../cart/cart_state.dart';
import 'cubits/address_cubit.dart';
import 'cubits/delivery_fee_cubit.dart';
class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _triggerFeeCalculation(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ OUVINTE ADICIONAL: para reconstruir a tela quando o tipo de entrega muda
    return MultiBlocListener(
      listeners: [
        BlocListener<AddressCubit, AddressState>(
          listener: (context, state) => _triggerFeeCalculation(context),
        ),
        BlocListener<CartCubit, CartState>(
          listener: (context, state) => _triggerFeeCalculation(context),
        ),
        // Este ouvinte garante que, se o tipo de entrega mudar,
        // o cálculo do frete seja refeito.
        BlocListener<DeliveryFeeCubit, DeliveryFeeState>(
          listener: (context, state) => _triggerFeeCalculation(context),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sacola'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Ouve o DeliveryFeeCubit para mudar o título dinamicamente
              BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
                builder: (context, feeState) {
                  final title = feeState.deliveryType == DeliveryType.delivery
                      ? 'Entregar no endereço'
                      : 'Local de retirada';
                  return _SectionTitle(title: title);
                },
              ),
              const SizedBox(height: 8),
              _buildAddressCard(), // Widget modificado para ser dinâmico

              const SizedBox(height: 32),

              const _SectionTitle(title: 'Opções de entrega'),
              const SizedBox(height: 8),
              _buildDeliveryOptions(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  void _triggerFeeCalculation(BuildContext context) {
    // ... (nenhuma mudança aqui)
    final addressState = context.read<AddressCubit>().state;
    final store = context.read<StoreCubit>().state.store;
    final cartSubtotal = context.read<CartCubit>().state.cart.subtotal / 100.0;
    if (store != null) {
      context.read<DeliveryFeeCubit>().calculate(
        address: addressState.selectedAddress,
        store: store,
        cartSubtotal: cartSubtotal,
      );
    }
  }

  // ✅ MUDANÇA PRINCIPAL AQUI
  Widget _buildAddressCard() {
    // Ouve o tipo de entrega PRIMEIRO
    return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
      builder: (context, feeState) {
        // Se for RETIRADA, mostra o endereço da loja
        if (feeState.deliveryType == DeliveryType.pickup) {
          final store = context.read<StoreCubit>().state.store;
          if (store == null) return const SizedBox.shrink();
          // Usa um novo widget para o local de retirada
          return _PickupLocationCard(store: store);
        }

        // Se for ENTREGA, mantém a lógica original
        return BlocBuilder<AddressCubit, AddressState>(
          builder: (context, addressState) {
            if (addressState.status == AddressStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (addressState.selectedAddress == null) {
              return ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                title: const Text('Nenhum endereço selecionado'),
                subtitle: const Text('Toque para escolher um endereço'),
                onTap: () => context.push('/select-address'),
              );
            }
            return _AddressCard(
              address: addressState.selectedAddress!,
              onTap: () => context.push('/select-address'),
            );
          },
        );
      },
    );
  }

  // --- WIDGETS AUXILIARES ---


  Widget _buildDeliveryOptions() {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, storeState) {
        final store = storeState.store;
        if (store == null) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }

        final deliveryEnabled = store.store_operation_config?.deliveryEnabled ?? false;
        final pickupEnabled = store.store_operation_config?.pickupEnabled ?? false;
        final deliveryTime =
            '${store.store_operation_config?.deliveryEstimatedMin}-${store.store_operation_config?.deliveryEstimatedMax} min';

        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            return Column(
              children: [
                if (deliveryEnabled)
                  _DeliveryOptionTile(
                    title: 'Delivery',
                   // subtitle: 'Entrega em domicílio', // Subtítulo mais genérico
                    deliveryTime: deliveryTime,      // ✅ PASSE A VARIÁVEL AQUI
                    fee: feeState.calculatedDeliveryFee,
                    isSelected: feeState.deliveryType == DeliveryType.delivery,
                    status: feeState.status, //
                    onTap: () {
                      context.read<DeliveryFeeCubit>().updateDeliveryType(DeliveryType.delivery);
                    },
                  ),
                if (pickupEnabled)
                  _DeliveryOptionTile(
                    title: 'Retirar na loja',
                   // subtitle: 'Disponível para retirada',
                    deliveryTime: 'Pronto em ${store.store_operation_config?.pickupEstimatedMin} min', // ✅ PASSE O TEMPO DE RETIRADA AQUI
                    fee: 0,
                    isSelected: feeState.deliveryType == DeliveryType.pickup,
                    onTap: () {
                      context.read<DeliveryFeeCubit>().updateDeliveryType(DeliveryType.pickup);
                    }, status: feeState.status,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            return BlocBuilder<AddressCubit, AddressState>(
              builder: (context, addressState) {
                final cartTotal = cartState.cart.total / 100.0;
                final deliveryFee = (feeState.deliveryType == DeliveryType.delivery) ? feeState.calculatedDeliveryFee : 0;
                final grandTotal = cartTotal + deliveryFee;

                continueAction() {
                  if (feeState.deliveryType == DeliveryType.delivery && addressState.selectedAddress == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, selecione um endereço.')),
                    );
                    return;
                  }
                  context.go('/checkout');
                }

                return AddressBottomBar(
                  totalPrice: grandTotal,
                  totalItems: cartState.cart.items.length,
                  onContinuePressed: continueAction,

                );
              },
            );
          },
        );
      },
    );
  }
}


class _PickupLocationCard extends StatelessWidget {
  final Store store;
  const _PickupLocationCard({required this.store});

  @override
  Widget build(BuildContext context) {
    // Assumindo que a URL da imagem está em 'store.logoUrl'.
    // Se o nome da propriedade for outro (ex: 'imageUrl', 'photo'), basta alterar abaixo.
    final String? imageUrl = store.image!.url;

    final addressLine = '${store.street}, ${store.number} - ${store.neighborhood}, ${store.city}';
    return ListTile(
      // ✅ MUDANÇA: Substituímos o Icon pelo CircleAvatar
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
      title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(addressLine),
      trailing: TextButton(
        onPressed: () => context.push('/select-address'),
        child: const Text('Trocar', style: TextStyle(color: Colors.red)),
      ),
      onTap: () => context.push('/select-address'),
    );
  }
}


class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// Cartão para exibir o endereço selecionado
class _AddressCard extends StatelessWidget {
  final CustomerAddress address;
  final VoidCallback onTap;

  const _AddressCard({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = '${address.neighborhood} ${address.complement ?? ""} - ${address.city}';
    return ListTile(


      leading: const Icon(Icons.location_on_outlined, color: Colors.black, size: 24,),
      title: Text('${address.street}, ${address.number}', style: TextStyle(fontWeight:  FontWeight.w900),),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: onTap,
        child: const Text('Trocar', style: TextStyle(color: Colors.red)),
      ),
      onTap: onTap,
    );
  }
}

// MODIFIQUE O WIDGET _DeliveryOptionTile
class _DeliveryOptionTile extends StatelessWidget {
  final String title;
  final String deliveryTime;
  final double fee;
  final bool isSelected;
  final DeliveryFeeStatus status; // ✅ RECEBE O STATUS
  final VoidCallback onTap;

  const _DeliveryOptionTile({
    required this.title,

    required this.deliveryTime,
    required this.fee,
    required this.isSelected,
    required this.status, // ✅ RECEBE O STATUS
    required this.onTap,
  });

  // ✅ NOVA FUNÇÃO para decidir o texto do frete
  String _getFeeText() {
    if (status == DeliveryFeeStatus.requiresAddress) {
      return 'A calcular';
    }
    if (fee > 0) {
      return 'R\$ ${fee.toStringAsFixed(2)}';
    }
    return 'Grátis';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.black : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(deliveryTime, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ USA A NOVA FUNÇÃO AQUI
            Text(
              _getFeeText(),
              style: TextStyle(
                  color: fee > 0 ? null : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14
              ),
            ),
            Radio<bool>(
              value: isSelected,
              groupValue: true,
              onChanged: (value) => onTap(),
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}