// lib/pages/address/widgets/delivery_options.dart (Nomeei como delivery_options.dart, mas pode ser DeliveryOptionDisplay.dart)
import 'package:flutter/material.dart';
import 'package:totem/models/delivery_type.dart';

class DeliveryOptionDisplay extends StatelessWidget {
  final DeliveryType deliveryType;
  final double deliveryCost;
  final double minOrderForFreeShipping;
  final double subtotal;

  const DeliveryOptionDisplay({
    Key? key,
    required this.deliveryType,
    required this.deliveryCost,
    required this.minOrderForFreeShipping,
    required this.subtotal,
  }) : super(key: key);

  String get _deliveryFeeText {
    if (deliveryType == DeliveryType.pickup) {
      return 'Grátis';
    } else {
      if (minOrderForFreeShipping > 0 && subtotal >= minOrderForFreeShipping) {
        return 'Grátis (Pedido acima de R\$${minOrderForFreeShipping.toStringAsFixed(2).replaceAll('.', ',')})';
      }
      return 'R\$ ${deliveryCost.toStringAsFixed(2).replaceAll('.', ',')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  deliveryType == DeliveryType.delivery
                      ? Icons.delivery_dining
                      : Icons.store,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  deliveryType == DeliveryType.delivery
                      ? 'Entrega em domicílio'
                      : 'Retirada na loja',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Icon(Icons.check_circle, color: Colors.green), // Indica que está selecionado
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Taxa de entrega:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _deliveryFeeText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}