import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/delivery_type.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';

import '../../cart/cart_state.dart';

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Ouve as mudanças no carrinho e na taxa de entrega para se reconstruir
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            final cart = cartState.cart;

            // Lógica para determinar a taxa de entrega a ser exibida
            final deliveryFee = (feeState.deliveryType == DeliveryType.delivery)
                ? feeState.calculatedDeliveryFee
                : 0;

            final grandTotal = (cart.total / 100.0) + deliveryFee;

            // Formata os valores para exibição
            final subtotalString = UtilBrasilFields.obterReal(cart.subtotal / 100.0);
            final deliveryFeeString = deliveryFee > 0 ? UtilBrasilFields.obterReal(deliveryFee.toDouble()) : 'Grátis';
            final totalString = UtilBrasilFields.obterReal(grandTotal);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo de valores',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow(
                  context,
                  title: 'Subtotal',
                  value: subtotalString,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  context,
                  title: 'Taxa de entrega',
                  value: deliveryFeeString,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  context,
                  title: 'Total',
                  value: totalString,
                  isBold: true, // Deixa a linha do total em negrito
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Widget auxiliar para criar cada linha do resumo (ex: Subtotal R$ 10,00)
  Widget _buildSummaryRow(BuildContext context, {
    required String title,
    required String value,
    bool isBold = false,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: isBold ? Colors.black87 : Colors.grey.shade700,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: style),
        Text(value, style: style),
      ],
    );
  }
}