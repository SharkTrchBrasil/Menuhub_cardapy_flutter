// Em: lib/pages/checkout/widgets/bottom_bar_checkout.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';

import '../../../cubit/auth_cubit.dart';
import '../../address/cubits/address_cubit.dart';
import '../../address/cubits/delivery_fee_cubit.dart';
import '../../cart/cart_cubit.dart';
import '../../cart/cart_state.dart';
import '../checkout_cubit.dart';
// ... outros imports

class BottomBarCheckout extends StatelessWidget {
  const BottomBarCheckout({super.key});

  @override
  Widget build(BuildContext context) {
    // Ouve múltiplos cubits para montar a UI e ter os dados para o pedido
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            // Ouve também o CheckoutCubit para saber o estado de loading
            return BlocBuilder<CheckoutCubit, CheckoutState>(
              builder: (context, checkoutState) {

                // Este valor é calculado e enviado pelo backend, 100% confiável.
                final grandTotal = (cartState.cart.total / 100.0) + feeState.calculatedDeliveryFee;


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
                          // Desabilita o botão durante o carregamento
                          onPressed: isLoading ? null : () {
                            // ✅ AÇÃO FINAL SIMPLIFICADA: Coleta os dados e chama o especialista
                            context.read<CheckoutCubit>().placeOrder(
                              authState: context.read<AuthCubit>().state,
                              cartState: context.read<CartCubit>().state,
                              addressState: context.read<AddressCubit>().state,
                              feeState: feeState, // Já temos o feeState deste builder
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