// Em: lib/pages/address/address_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart'; // ✅ Import para firstOrNull
import 'package:totem/models/customer_address.dart';
import 'package:totem/models/coupon.dart';
import 'package:totem/widgets/unified_cart_bottom_bar.dart';

import '../../cubit/store_cubit.dart';
import '../../cubit/store_state.dart';
import '../../models/delivery_type.dart';
import '../../models/store.dart';
import '../cart/cart_cubit.dart';
import '../cart/cart_state.dart';
import 'cubits/address_cubit.dart';
import 'cubits/delivery_fee_cubit.dart';
import 'package:totem/widgets/address_selection_bottom_sheet.dart'; // ✅ Novo bottom sheet moderno
import 'package:totem/themes/ds_theme_switcher.dart';

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
    return MultiBlocListener(
      listeners: [
        BlocListener<AddressCubit, AddressState>(
          listener: (context, state) => _triggerFeeCalculation(context),
        ),
        BlocListener<CartCubit, CartState>(
          listener: (context, state) => _triggerFeeCalculation(context),
        ),
        // ✅ ENTERPRISE: Escuta mudanças no Store para recalcular frete quando regras são atualizadas
        BlocListener<StoreCubit, StoreState>(
          listener: (context, state) {
            // Recalcula frete quando o store é atualizado (ex: regras de frete atualizadas via WebSocket)
            if (state.store != null) {
              _triggerFeeCalculation(context);
            }
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final theme = context.watch<DsThemeSwitcher>().theme;
          return Scaffold(
            backgroundColor:
                theme.cartBackgroundColor, // Mantém fundo consistente
            appBar: AppBar(
              title: const Text('ENTREGA', style: TextStyle(fontSize: 14)),
              centerTitle: true,
              backgroundColor: theme.cartBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_left,
                  color: Colors.black,
                ),
                onPressed: () => context.go('/cart'),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
                          builder: (context, feeState) {
                            final title =
                                feeState.deliveryType == DeliveryType.delivery
                                    ? 'Entregar no endereço'
                                    : 'Local de retirada';
                            return _SectionTitle(title: title);
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildAddressCard(),
                        const SizedBox(height: 32),
                        // ✅ NOVO: Oculta título "Opções de entrega" também
                        BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
                          builder: (context, feeState) {
                            final addressState =
                                context.watch<AddressCubit>().state;
                            if (feeState.deliveryType ==
                                    DeliveryType.delivery &&
                                addressState.selectedAddress == null) {
                              return const SizedBox.shrink();
                            }
                            return const _SectionTitle(
                              title: 'Opções de entrega',
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildDeliveryOptions(),
                      ],
                    ),
                  ),
                ),
                const UnifiedCartBottomBar(
                  variant: CartBottomBarVariant.address,
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomBar(),
          ); // Scaffold
        }, // Builder function
      ), // Builder
    ); // MultiBlocListener
  }

  void _triggerFeeCalculation(BuildContext context) async {
    if (!mounted) return;
    final addressState = context.read<AddressCubit>().state;
    final store = context.read<StoreCubit>().state.store;
    final cartSubtotal = context.read<CartCubit>().state.cart.subtotal / 100.0;
    if (store != null) {
      await context.read<DeliveryFeeCubit>().calculate(
        address: addressState.selectedAddress,
        store: store,
        cartSubtotal: cartSubtotal,
      );
    }
  }

  // ✅ NOVO: Abre bottom sheet moderno para cadastro/edição de endereço
  void _showAddressBottomSheet({CustomerAddress? addressToEdit}) {
    AddressSelectionBottomSheet.show(
      context,
      addressToEdit: addressToEdit,
      startWithSearch: true,
    );
  }

  Widget _buildAddressCard() {
    return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
      builder: (context, feeState) {
        if (feeState.deliveryType == DeliveryType.pickup) {
          final store = context.read<StoreCubit>().state.store;
          if (store == null) return const SizedBox.shrink();
          return _PickupLocationCard(store: store);
        }

        return BlocBuilder<AddressCubit, AddressState>(
          builder: (context, addressState) {
            if (addressState.status == AddressStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (addressState.selectedAddress == null) {
              return ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
                title: const Text('Nenhum endereço selecionado'),
                subtitle: const Text('Toque para escolher ou cadastrar'),
                onTap: () {
                  // ✅ NOVO: Abre o bottom sheet moderno de endereço
                  _showAddressBottomSheet();
                },
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

  Widget _buildDeliveryOptions() {
    // ✅ NOVO: Oculta opções de entrega se for Delivery e não tiver endereço selecionado
    final deliveryType = context.watch<DeliveryFeeCubit>().state.deliveryType;
    final selectedAddress = context.watch<AddressCubit>().state.selectedAddress;

    if (deliveryType == DeliveryType.delivery && selectedAddress == null) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, storeState) {
        final store = storeState.store;
        if (store == null) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final deliveryEnabled =
            store.store_operation_config?.deliveryEnabled ?? false;
        final pickupEnabled =
            store.store_operation_config?.pickupEnabled ?? false;

        final deliveryTime = store.getDeliveryTimeRange();

        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            // ✅ NOVO: Verifica se há erro de frete (fora da área)
            final bool hasDeliveryError =
                feeState is DeliveryFeeError &&
                feeState.deliveryType == DeliveryType.delivery;

            return Column(
              children: [
                if (deliveryEnabled)
                  _DeliveryOptionTile(
                    title: 'Delivery',
                    deliveryTime: deliveryTime,
                    feeState: feeState, // Passa o estado completo
                    isSelected: feeState.deliveryType == DeliveryType.delivery,
                    onTap: () {
                      context.read<DeliveryFeeCubit>().updateDeliveryType(
                        DeliveryType.delivery,
                      );
                    },
                  ),
                // ✅ NOVO: Mostra alerta de erro quando endereço está fora da área
                if (hasDeliveryError)
                  _OutOfAreaWarning(
                    message: (feeState as DeliveryFeeError).message,
                  ),
                if (pickupEnabled)
                  _DeliveryOptionTile(
                    title: 'Retirar na loja',
                    deliveryTime:
                        'Pronto em ${store.store_operation_config?.pickupEstimatedMin} min',
                    feeState: feeState, // Passa o estado completo
                    isSelected: feeState.deliveryType == DeliveryType.pickup,
                    onTap: () {
                      context.read<DeliveryFeeCubit>().updateDeliveryType(
                        DeliveryType.pickup,
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return const SizedBox.shrink(); // Removido pois agora está no body Column
  }
}

class _PickupLocationCard extends StatelessWidget {
  final Store store;
  const _PickupLocationCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = store.image?.url;
    final addressLine =
        '${store.street}, ${store.number} - ${store.neighborhood}, ${store.city}';
    return ListTile(
      leading: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1),
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey.shade100,
          backgroundImage:
              (imageUrl != null && imageUrl.isNotEmpty)
                  ? NetworkImage(imageUrl)
                  : null,
          child:
              (imageUrl == null || imageUrl.isEmpty)
                  ? const Icon(
                    Icons.store_mall_directory_outlined,
                    color: Colors.black54,
                    size: 24,
                  )
                  : null,
        ),
      ),
      title: Text(
        store.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(addressLine),
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
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final CustomerAddress address;
  final VoidCallback onTap;

  const _AddressCard({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle =
        '${address.neighborhood} ${address.complement ?? ""} - ${address.city}';
    return ListTile(
      leading: const Icon(
        Icons.location_on_outlined,
        color: Colors.black,
        size: 24,
      ),
      title: Text(
        '${address.street}, ${address.number}',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: onTap,
        child: const Text(
          'Trocar',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: onTap,
    );
  }
}

// ✅ WIDGET _DeliveryOptionTile CORRIGIDO
class _DeliveryOptionTile extends StatelessWidget {
  final String title;
  final String deliveryTime;
  final DeliveryFeeState feeState; // Recebe o estado completo
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryOptionTile({
    required this.title,
    required this.deliveryTime,
    required this.feeState,
    required this.isSelected,
    required this.onTap,
  });

  String _getFeeText(BuildContext context) {
    final state = feeState; // Apenas para facilitar a leitura

    // ✅ FIX BUG 1: Retirada é SEMPRE grátis — verificar ANTES de qualquer lógica de frete
    if (title == 'Retirar na loja') {
      return 'Grátis';
    }

    // ✅ Verifica se deve ocultar o valor do frete (hide_fee_display)
    final storeState = context.read<StoreCubit>().state;
    final store = storeState.store;
    if (store != null && _shouldHideFeeDisplay(store)) {
      return ''; // Ocultar valor
    }

    // ✅ CORREÇÃO: Verifica se tem cupom de frete grátis aplicado
    final cart = context.read<CartCubit>().state.cart;
    final storeCoupons = store?.coupons ?? [];

    Coupon? appliedCoupon;
    if (cart.couponCode != null) {
      appliedCoupon =
          storeCoupons
              .where(
                (c) => c.code.toUpperCase() == cart.couponCode!.toUpperCase(),
              )
              .firstOrNull;
    }

    // ✅ Se tem cupom de frete grátis REAL aplicado
    if (cart.couponCode != null &&
        cart.couponCode!.isNotEmpty &&
        (cart.isFreeDelivery || appliedCoupon?.isFreeDelivery == true)) {
      return 'Grátis';
    }

    if (state is DeliveryFeeRequiresAddress) {
      return 'A calcular';
    }
    // ✅ NOVO: Se houver erro e for delivery, mostra "Indisponível"
    if (state is DeliveryFeeError) {
      return 'Indisponível';
    }
    if (state is DeliveryFeeLoaded) {
      if (state.deliveryFee > 0) {
        return 'R\$ ${state.deliveryFee.toStringAsFixed(2)}';
      }
      return 'Grátis';
    }
    if (state is DeliveryFeeLoading) {
      return '...';
    }
    return 'A calcular';
  }

  bool _shouldHideFeeDisplay(Store store) {
    // ✅ REMOVIDO: Não usamos mais frete por bairros (neighborhood_fee)
    // Retorna false por padrão
    return false;
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
        subtitle: Text(
          deliveryTime,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (context) {
                final cart = context.read<CartCubit>().state.cart;
                final hasCouponApplied =
                    cart.couponCode != null && cart.couponCode!.isNotEmpty;
                final feeText = _getFeeText(context);

                return Text(
                  feeText,
                  style: TextStyle(
                    color:
                        (feeState is DeliveryFeeError && title == 'Delivery')
                            ? Colors.red
                            : (feeText == 'Grátis' && hasCouponApplied)
                            ? Colors.green
                            : Colors.black87,
                    fontWeight:
                        (feeText == 'Grátis' && hasCouponApplied)
                            ? FontWeight.bold
                            : FontWeight.normal,
                    fontSize: 14,
                  ),
                );
              },
            ),
            Radio<bool>(
              value: isSelected,
              groupValue: true,
              onChanged: (value) => onTap(),
              activeColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ NOVO: Widget de aviso quando endereço está fora da área de entrega
class _OutOfAreaWarning extends StatelessWidget {
  final String message;
  const _OutOfAreaWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_off_rounded,
              color: Colors.black87,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Não entregamos neste endereço',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por favor, escolha outro endereço ou selecione "Retirar na loja".',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
