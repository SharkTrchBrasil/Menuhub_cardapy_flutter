// Em: lib/pages/checkout/widgets/bottom_bar_checkout.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';

import '../../../cubit/auth_cubit.dart';
import '../../../models/delivery_type.dart';
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
                // ✅ CORREÇÃO APLICADA AQUI
                // Calcula a taxa de entrega de forma segura
                double deliveryFee = 0.0;
                if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
                  deliveryFee = feeState.deliveryFee;
                }

                // O total do carrinho já vem do backend, somamos a taxa de entrega localmente
                final grandTotal = (cartState.cart.total / 100.0) + deliveryFee;
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
                            context.read<CheckoutCubit>().placeOrder(
                              authState: context.read<AuthCubit>().state,
                              cartState: cartState,
                              addressState: context.read<AddressCubit>().state,
                              feeState: feeState,
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