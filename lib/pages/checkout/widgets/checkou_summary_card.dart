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
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            final cart = cartState.cart;

            // ✅ CORREÇÃO APLICADA AQUI
            double deliveryFee = 0.0;
            if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
              deliveryFee = feeState.deliveryFee;
            }

            final grandTotal = (cart.total / 100.0) + deliveryFee;

            final subtotalString = UtilBrasilFields.obterReal(cart.subtotal / 100.0);
            final deliveryFeeString = deliveryFee > 0 ? UtilBrasilFields.obterReal(deliveryFee) : 'Grátis';
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
                  isBold: true,
                ),
              ],
            );
          },
        );
      },
    );
  }

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