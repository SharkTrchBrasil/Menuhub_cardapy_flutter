// Em: lib/pages/checkout/widgets/bottom_bar_checkout.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';

import '../../../cubit/auth_cubit.dart';
import '../../../cubit/store_cubit.dart';
import '../../../models/delivery_type.dart';
import '../../../helpers/payment_method.dart';
import '../../address/cubits/address_cubit.dart';
import '../../address/cubits/delivery_fee_cubit.dart';
import '../../cart/cart_cubit.dart';
import '../../cart/cart_state.dart';
import '../checkout_cubit.dart';

class BottomBarCheckout extends StatelessWidget {
  const BottomBarCheckout({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            return BlocBuilder<CheckoutCubit, CheckoutState>(
              builder: (context, checkoutState) {
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
                  final subtotalInReais = cartState.cart.subtotal / 100.0;
                  paymentFee = checkoutState.selectedPaymentMethod!.calculateFee(subtotalInReais);
                }

                // ✅ P0 - CRÍTICO: Total = (subtotal - desconto do cupom) + frete + taxa de pagamento
                // cart.total já vem do backend com desconto aplicado (subtotal - discount)
                final grandTotal = (cartState.cart.total / 100.0) + deliveryFee + paymentFee;
                final isLoading = checkoutState.status == CheckoutStatus.loading;

                return BottomAppBar(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Total do Pedido'),
                            Text(
                              grandTotal.toCurrency(),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                          onPressed: isLoading ? null : () {
                            final store = context.read<StoreCubit>().state.store;
                            context.read<CheckoutCubit>().placeOrder(
                              authState: context.read<AuthCubit>().state,
                              cartState: cartState,
                              addressState: context.read<AddressCubit>().state,
                              feeState: feeState,
                              store: store,
                            );
                          },
                          child: isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                              : const Text('Finalizar Pedido'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}