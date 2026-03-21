import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import '../../../cubit/auth_cubit.dart';
import '../../../themes/ds_theme_switcher.dart';
import '../../../widgets/ds_primary_button.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/widgets/store_closed_widgets.dart';
import 'package:totem/services/store_status_service.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/models/delivery_type.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';

class CartBottomBar extends StatelessWidget {
  const CartBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    // ✅ Reativo: Ouve alterações no StoreCubit para minOrder e cupons
    final storeState = context.watch<StoreCubit>().state;
    final minOrder = storeState.store?.getMinOrderForDelivery() ?? 0;
    final storeCoupons = storeState.store?.coupons ?? [];

    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        final cart = cartState.cart;

        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            // ✅ Mesma lógica do OrderSummaryCard
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

            // ✅ CORREÇÃO ROBUSTA: Verifica o tipo do cupom na store
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
            final effectiveFee = isFreeDelivery ? 0.0 : deliveryFee;

            // Totais
            final subtotalValue = cart.subtotal / 100.0;
            final discountValue = cart.discount / 100.0;
            // Total Visual = (Subtotal - Desconto) + Frete Efetivo
            final finalTotal = subtotalValue - discountValue + effectiveFee;

            final itemCount = cart.items.fold<int>(
              0,
              (sum, item) => sum + (item.quantity > 0 ? item.quantity : 1),
            );
            // ✅ CORREÇÃO: hasCoupon considera desconto direto OU cupom de frete grátis
            final hasCoupon = cart.discount > 0 || hasFreeDeliveryCoupon;

            // ✅ Label do texto
            final labelText =
                isFreeDelivery
                    ? 'Total com entrega grátis'
                    : 'Total com entrega';

            return Container(
              color: Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      // ✅ Informações do carrinho (sem logo)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              labelText,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isFreeDelivery
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                fontWeight:
                                    isFreeDelivery
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  finalTotal.toCurrency(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        hasCoupon
                                            ? Colors.green.shade700
                                            : Colors.black87,
                                  ),
                                ),
                                Text(
                                  ' / $itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: DsPrimaryButton(
                          label: 'Continuar',
                          onPressed: () {
                            // BLINDAGEM: Validação de itens indisponíveis
                            final cartState = context.read<CartCubit>().state;
                            if (cartState.cart.hasUnavailableItems) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Remova os itens indisponíveis antes de continuar',
                                  ),
                                  backgroundColor: Colors.red.shade600,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            // Validação de loja fechada
                            final activeStore =
                                context.read<StoreCubit>().state.store;
                            if (activeStore != null) {
                              final status =
                                  StoreStatusService.validateStoreStatus(
                                    activeStore,
                                  );

                              if (!status.canReceiveOrders) {
                                StoreClosedHelper.showModal(
                                  context,
                                  isCartPage: true,
                                  isDesktop:
                                      MediaQuery.of(context).size.width >= 768,
                                  nextOpenTime: status.message,
                                  onSeeOtherOptions: () {
                                    Navigator.of(context).pop();
                                  },
                                );
                                return;
                              }
                            }

                            if (minOrder > 0 && finalTotal < minOrder) {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder:
                                    (_) => Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Valor mínimo do pedido.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: theme.cartTextColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            'O valor mínimo para entrega é de R\$ ${minOrder.toCurrency()}.',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DsPrimaryButton(
                                                  onPressed:
                                                      () => context.pop(),
                                                  label: 'Adicionar mais itens',
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          GestureDetector(
                                            onTap: () => Navigator.pop(context),
                                            child: Text(
                                              'Ok, entendi',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: theme.primaryColor,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                              );
                            } else {
                              final authState = context.read<AuthCubit>().state;

                              if (authState.isLoggedIn) {
                                context.push('/address');
                              } else {
                                context.push('/signin');
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
