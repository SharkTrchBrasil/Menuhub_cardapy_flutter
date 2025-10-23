// pages/checkout/widgets/delivery_options.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/pages/checkout/checkout_cubit.dart';

import '../../../models/delivery_type.dart';

import '../../../cubit/store_cubit.dart'; // Certifique-se de ter o enum DeliveryType

class DeliveryOptionSelection extends StatelessWidget {
  final bool deliveryEnabled;
  final bool pickupEnabled;
  final DeliveryType? selectedDeliveryType;
  final ValueChanged<DeliveryType?> onDeliveryTypeChanged;

  final double deliveryCost; // NOVO: Custo da entrega
  final double minOrderForFreeShipping; // NOVO: Valor mínimo para frete grátis
  final double subtotal; // NOVO: Subtotal do carrinho

  const DeliveryOptionSelection({
    super.key,
    required this.deliveryEnabled,
    required this.pickupEnabled,
    required this.selectedDeliveryType,
    required this.onDeliveryTypeChanged,

    this.deliveryCost = 0.0,
    this.minOrderForFreeShipping = 0.0,
    this.subtotal = 0.0,
  });

  @override
  Widget build(BuildContext context) {

    final bool isFreeShipping =
        deliveryEnabled && subtotal >= minOrderForFreeShipping && minOrderForFreeShipping > 0;
    final store = context.watch<StoreCubit>().state.store;


    final minDeliveryTime = store?.store_operation_config?.deliveryEstimatedMin;
        final maxDeliveryTime =  store?.store_operation_config?.deliveryEstimatedMax;


    final minPickupDeliveryTime = store?.store_operation_config?.pickupEstimatedMin;
    final maxPickupDeliveryTime =  store?.store_operation_config?.pickupEstimatedMax;



    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (deliveryEnabled)
          _buildDeliveryOption(
            context: context,
            deliveryType: DeliveryType.delivery,
            title: 'Delivery',
            subtitle: '$minDeliveryTime - $maxDeliveryTime min',
            cost: isFreeShipping ? 0.0 : deliveryCost / 100,
            isSelected: selectedDeliveryType == DeliveryType.delivery,
            onChanged: onDeliveryTypeChanged,
            isFreeShipping: isFreeShipping,
          ),
        if (deliveryEnabled && !pickupEnabled) const SizedBox(height: 16),
        if (pickupEnabled)
          _buildDeliveryOption(
            context: context,
            deliveryType: DeliveryType.pickup,
            title: 'Retirada na Loja',
            subtitle: '$minPickupDeliveryTime - $maxPickupDeliveryTime min', // Pode adicionar tempo de preparo aqui se tiver
            cost: 0.0 , // Retirada geralmente não tem custo
            isSelected: selectedDeliveryType == DeliveryType.pickup,
            onChanged: onDeliveryTypeChanged,
            isFreeShipping: false, // Frete grátis não se aplica a retirada
          ),

      ],
    );
  }

  Widget _buildDeliveryOption({
    required BuildContext context,
    required DeliveryType deliveryType,
    required String title,
    required String subtitle,
    required double cost,
    required bool isSelected,
    required ValueChanged<DeliveryType?> onChanged,
    required bool isFreeShipping,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
            color: isSelected ? Colors.black : Colors.transparent,
            width: isSelected ? 1 : 0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RadioListTile<DeliveryType>(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        secondary: isSelected && isFreeShipping && deliveryType == DeliveryType.delivery
            ? const Text('GRÁTIS', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            : Text(cost.toCurrency(), style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),),
        value: deliveryType,
        groupValue: selectedDeliveryType,
        onChanged: onChanged,
      ),
    );
  }
}

// Extensão para formatação de moeda (se você já não tiver, adicione em core/extensions.dart)
extension DoubleToCurrency on double {
  String toCurrency() {
    return 'R\$ ${toStringAsFixed(2).replaceAll('.', ',')}';
  }
}