import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/delivery_type.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/checkout/checkout_cubit.dart';
import 'package:totem/helpers/payment_method.dart';

import '../../cart/cart_state.dart';

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            return BlocBuilder<CheckoutCubit, CheckoutState>(
              builder: (context, checkoutState) {
                final cart = cartState.cart;

                // ✅ P0 - CRÍTICO: Calcula frete corretamente (considerando frete grátis por threshold)
                double deliveryFee = 0.0;
                bool isFreeDelivery = false;
                if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
                  deliveryFee = feeState.deliveryFee;
                  isFreeDelivery = feeState.isFree ?? false;
                  // ✅ P0: Se frete grátis, força deliveryFee para 0
                  if (isFreeDelivery) {
                    deliveryFee = 0.0;
                  }
                }

                // ✅ P0 - CRÍTICO: Calcula taxa de pagamento baseada no subtotal (antes do desconto)
                double paymentFee = 0.0;
                if (checkoutState.selectedPaymentMethod != null) {
                  final subtotalInReais = cart.subtotal / 100.0;
                  paymentFee = checkoutState.selectedPaymentMethod!.calculateFee(subtotalInReais);
                }

                // ✅ P0 - CRÍTICO: Total = (subtotal - desconto do cupom) + frete + taxa de pagamento
                // cart.total já vem do backend com desconto aplicado (subtotal - discount)
                final grandTotal = (cart.total / 100.0) + deliveryFee + paymentFee;

                final subtotalString = UtilBrasilFields.obterReal(cart.subtotal / 100.0);
                final deliveryFeeString = (deliveryFee > 0 && !isFreeDelivery) 
                    ? UtilBrasilFields.obterReal(deliveryFee) 
                    : 'Grátis';
                final paymentFeeString = paymentFee > 0 ? UtilBrasilFields.obterReal(paymentFee) : null;
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
                    // ✅ P0: Exibe desconto do cupom se houver
                    if (cart.discount > 0) ...[
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        context,
                        title: 'Desconto${cart.couponCode != null ? ' (${cart.couponCode})' : ''}',
                        value: '-${UtilBrasilFields.obterReal(cart.discount / 100.0)}',
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      context,
                      title: 'Taxa de entrega',
                      value: deliveryFeeString,
                    ),
                    if (paymentFeeString != null) ...[
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        context,
                        title: 'Taxa de pagamento',
                        value: paymentFeeString,
                      ),
                    ],
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