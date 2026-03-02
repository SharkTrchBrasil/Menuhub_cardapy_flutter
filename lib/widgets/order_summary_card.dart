import 'package:brasil_fields/brasil_fields.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/models/delivery_type.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';
import 'package:totem/models/payment_method.dart';

class OrderSummaryCard extends StatelessWidget {
  final PlatformPaymentMethod? paymentMethod;

  const OrderSummaryCard({super.key, this.paymentMethod});

  @override
  Widget build(BuildContext context) {
    // ✅ CORREÇÃO: Busca os cupons da store para verificar o tipo
    final storeState = context.watch<StoreCubit>().state;
    final storeCoupons = storeState.store?.coupons ?? [];

    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            final cart = cartState.cart;

            // Lógica de Taxa de Entrega (Unificada)
            double deliveryFee = 0.0;
            bool isDeliveryFreeFromRule = false;

            if (feeState is DeliveryFeeLoaded &&
                feeState.deliveryType == DeliveryType.delivery) {
              deliveryFee = feeState.deliveryFee;
              isDeliveryFreeFromRule = feeState.isFree ?? false;
              if (isDeliveryFreeFromRule) {
                deliveryFee = 0.0;
              }
            } else if (cart.deliveryFee > 0) {
              // ✅ FALLBACK: Usa o frete do carrinho se o DeliveryFeeCubit não estiver carregado
              deliveryFee = cart.finalDeliveryFee / 100.0;
            }

            // ✅ CORREÇÃO ROBUSTA: Verifica o tipo do cupom na store, não confia apenas em cart.isFreeDelivery
            bool hasFreeDeliveryCoupon = false;
            if (cart.couponCode != null) {
              // Busca o cupom aplicado na lista de cupons da store
              final appliedCoupon =
                  storeCoupons
                      .where(
                        (c) =>
                            c.code.toUpperCase() ==
                            cart.couponCode!.toUpperCase(),
                      )
                      .firstOrNull;

              // Se encontrou o cupom, verifica se é do tipo FREE_DELIVERY
              if (appliedCoupon != null && appliedCoupon.isFreeDelivery) {
                hasFreeDeliveryCoupon = true;
              } else if (cart.isFreeDelivery) {
                // Fallback: usa a flag do carrinho se não encontrar o cupom na store
                hasFreeDeliveryCoupon = true;
              }
            }

            final isFreeDelivery =
                isDeliveryFreeFromRule || hasFreeDeliveryCoupon;
            final effectiveDeliveryFee = isFreeDelivery ? 0.0 : deliveryFee;

            // Totais
            final subtotalValue = cart.subtotal / 100.0;
            final discountValue = cart.discount / 100.0;

            // Lógica de Taxa de Pagamento
            double paymentFee = 0.0;
            if (paymentMethod != null && paymentMethod!.activation != null) {
              paymentFee = paymentMethod!.activation!.calculateFee(
                subtotalValue,
              );
            }

            // Total Final
            final grandTotal =
                subtotalValue -
                discountValue +
                effectiveDeliveryFee +
                paymentFee;

            // ✅ CORREÇÃO: hasCoupon considera desconto direto OU cupom de frete grátis
            final hasCoupon = cart.discount > 0 || hasFreeDeliveryCoupon;

            return Container(
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumo de valores',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtotal
                  _buildRow(
                    label: 'Subtotal',
                    value: subtotalValue.toCurrency(),
                    textColor: Colors.grey.shade600,
                  ),

                  const SizedBox(height: 12),

                  // Taxa de entrega
                  _buildRow(
                    label: 'Taxa de entrega',
                    value:
                        isFreeDelivery
                            ? 'Grátis'
                            : (effectiveDeliveryFee * 100).toInt().toCurrency,
                    valueColor:
                        hasFreeDeliveryCoupon ? Colors.green.shade700 : null,
                    textColor: Colors.grey.shade600,
                  ),

                  // Cupom
                  if (hasCoupon) ...[
                    const SizedBox(height: 12),
                    _buildRow(
                      label:
                          'Cupom${cart.couponCode != null ? ' (${cart.couponCode})' : ''}',
                      // ✅ CORREÇÃO: Mostra valor correto para cupom de frete grátis vs desconto direto
                      value:
                          cart.discount > 0
                              ? '- ${cart.discount.toCurrency}'
                              : 'Frete grátis',
                      valueColor: Colors.green.shade700,
                      textColor: Colors.grey.shade600,
                    ),
                  ],

                  // Taxa de pagamento (se houver)
                  if (paymentFee > 0) ...[
                    const SizedBox(height: 12),
                    _buildRow(
                      label: 'Taxa de pagamento',
                      value: UtilBrasilFields.obterReal(paymentFee),
                      textColor: Colors.grey.shade600,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Total
                  _buildRow(
                    label: 'Total',
                    value: (grandTotal * 100).toInt().toCurrency,
                    isBold: true,
                    textColor: Colors.black,
                    fontSize: 18,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    Color? valueColor,
    Color? textColor,
    bool isBold = false,
    double fontSize = 15,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor ?? Colors.grey.shade600,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            color: valueColor ?? (isBold ? Colors.black : Colors.grey.shade600),
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
