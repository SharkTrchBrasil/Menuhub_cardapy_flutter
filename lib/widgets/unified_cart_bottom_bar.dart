// lib/widgets/unified_cart_bottom_bar.dart
// ✅ Widget unificado para barra inferior do carrinho - usado em Home, Cart, Address, Checkout

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/models/delivery_type.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';
import 'package:totem/services/store_status_service.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/store_closed_widgets.dart';

/// Variantes do UnifiedCartBottomBar para diferentes contextos
enum CartBottomBarVariant {
  /// Home - mostra logo da loja, pill shape, botão "Ver sacola"
  home,

  /// Carrinho - sem logo, botão "Continuar"
  cart,

  /// Endereço - sem logo, botão "Continuar"
  address,

  /// Checkout - sem logo, botão "Finalizar pedido"
  checkout,
}

class UnifiedCartBottomBar extends StatelessWidget {
  final CartBottomBarVariant variant;
  final VoidCallback? onContinuePressed;
  final String? errorMessage;
  final String? overrideButtonLabel; // ✅ Allow custom button text

  const UnifiedCartBottomBar({
    super.key,
    required this.variant,
    this.onContinuePressed,
    this.errorMessage,
    this.overrideButtonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, storeState) {
        final store = storeState.store;
        final storeCoupons = store?.coupons ?? [];
        final storeLogoUrl = store?.image?.url;
        final minOrder = store?.getMinOrderForDelivery() ?? 0.0;

        return BlocBuilder<CartCubit, CartState>(
          builder: (context, cartState) {
            final isHomeOrderAgainProcessing =
                variant == CartBottomBarVariant.home &&
                cartState.isOrderAgainProcessing;
            final cart =
                isHomeOrderAgainProcessing
                    ? (cartState.orderAgainSnapshotCart ?? cartState.cart)
                    : cartState.cart;

            if (isHomeOrderAgainProcessing && cart.isEmpty) {
              return const SizedBox.shrink();
            }

            // ✅ Não mostra se o carrinho estiver vazio
            if (cart.isEmpty) {
              return const SizedBox.shrink();
            }

            return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
              builder: (context, feeState) {
                // ✅ Lógica unificada de cálculo de frete
                double deliveryFee = 0.0;
                bool isDeliveryFreeFromRule = false;

                if (feeState is DeliveryFeeLoaded &&
                    feeState.deliveryType == DeliveryType.delivery) {
                  deliveryFee = feeState.deliveryFee;
                  isDeliveryFreeFromRule = feeState.isFree == true;
                  if (isDeliveryFreeFromRule) {
                    deliveryFee = 0.0;
                  }
                } else if (cart.deliveryFee > 0) {
                  deliveryFee = cart.finalDeliveryFee / 100.0;
                }

                // ✅ Verifica se tem cupom de frete grátis
                bool hasFreeDeliveryCoupon = false;
                if (cart.couponCode != null) {
                  final appliedCoupon =
                      storeCoupons
                          .where(
                            (c) =>
                                c.code.toUpperCase() ==
                                cart.couponCode!.toUpperCase(),
                          )
                          .firstOrNull;

                  if (appliedCoupon != null && appliedCoupon.isFreeDelivery) {
                    hasFreeDeliveryCoupon = true;
                  } else if (cart.isFreeDelivery) {
                    hasFreeDeliveryCoupon = true;
                  }
                }

                final isFreeDelivery =
                    isDeliveryFreeFromRule || hasFreeDeliveryCoupon;
                final effectiveFee = isFreeDelivery ? 0.0 : deliveryFee;

                // ✅ Cálculo do total
                final subtotalValue = cart.subtotal / 100.0;
                final discountValue = cart.discount / 100.0;
                final finalTotal = subtotalValue - discountValue + effectiveFee;

                final itemCount = cart.items.fold<int>(
                  0,
                  (sum, item) => sum + (item.quantity > 0 ? item.quantity : 1),
                );

                // ✅ Lógica corrigida: Ícone e cor verde SÓ aparecem se houver cupom digitado/aplicado
                // Frete grátis por regra da loja (sem cupom) deve aparecer de forma neutra (preto)
                final hasCouponApplied =
                    cart.couponCode != null && cart.couponCode!.isNotEmpty;
                final isGreenStatus = hasCouponApplied;
                final hasCouponIcon = hasCouponApplied;

                // ✅ Determina se o frete está realmente incluído no total
                final bool isDeliveryFeeKnown = feeState is DeliveryFeeLoaded;
                final bool isPickup =
                    feeState.deliveryType == DeliveryType.pickup;

                // ✅ Texto dinâmico baseado no contexto real do frete
                // Prioridade: frete grátis (cupom define fee=0) > pickup > fee calculado > subtotal
                String labelText;
                if (isFreeDelivery) {
                  labelText = 'Total com entrega grátis';
                } else if (isPickup && isDeliveryFeeKnown) {
                  labelText = 'Total para retirada';
                } else if (!isDeliveryFeeKnown) {
                  labelText = 'Subtotal';
                } else {
                  labelText = 'Total com entrega';
                }

                // ✅ Texto do botão baseado na variante
                String buttonLabel = overrideButtonLabel ?? '';
                if (buttonLabel.isEmpty) {
                  switch (variant) {
                    case CartBottomBarVariant.home:
                      buttonLabel =
                          isHomeOrderAgainProcessing
                              ? 'Adicionando itens...'
                              : 'Ver sacola';
                      break;
                    case CartBottomBarVariant.cart:
                    case CartBottomBarVariant.address:
                      buttonLabel = 'Continuar';
                      break;
                    case CartBottomBarVariant.checkout:
                      buttonLabel = 'Finalizar';
                      break;
                  }
                }

                // ✅ Build baseado na variante
                final closingSoonInfo = StoreStatusService.getClosingSoonInfo(
                  store,
                );

                Widget bottomBarWidget;
                if (variant == CartBottomBarVariant.home) {
                  bottomBarWidget = _buildHomeVariant(
                    context: context,
                    theme: theme,
                    storeLogoUrl: storeLogoUrl,
                    labelText: labelText,
                    finalTotal: finalTotal,
                    itemCount: itemCount,
                    hasCoupon: hasCouponIcon,
                    isFreeDelivery: isFreeDelivery,
                    isGreenStatus: isGreenStatus,
                    buttonLabel: buttonLabel,
                    isHomeOrderAgainProcessing: isHomeOrderAgainProcessing,
                  );
                } else {
                  bottomBarWidget = _buildStandardVariant(
                    context: context,
                    theme: theme,
                    labelText: labelText,
                    finalTotal: finalTotal,
                    itemCount: itemCount,
                    hasCoupon: hasCouponIcon,
                    isFreeDelivery: isFreeDelivery,
                    isGreenStatus: isGreenStatus,
                    buttonLabel: buttonLabel,
                    minOrder: minOrder,
                    store: store,
                  );
                }

                // ✅ Mostra o aviso "colado" no topo da barra (fora da home)
                if (closingSoonInfo != null &&
                    variant != CartBottomBarVariant.home) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildClosingSoonBar(
                            closingSoonInfo['closingTime'] as TimeOfDay,
                          ),
                          bottomBarWidget,
                        ],
                      ),
                    ),
                  );
                }

                return bottomBarWidget;
              },
            );
          },
        );
      },
    );
  }

  Widget _buildClosingSoonBar(TimeOfDay closingTime) {
    final formattedTime =
        '${closingTime.hour.toString().padLeft(2, '0')}:${closingTime.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(color: Colors.black),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Centraliza o conteúdo
        children: [
          const Icon(Icons.access_time_filled, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Loja fechando • Peça até às',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold, // Mais peso nas letras
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red, // Vermelho padrão
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              formattedTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Variante Home - colado nas tabs, radius apenas no topo
  Widget _buildHomeVariant({
    required BuildContext context,
    required dynamic theme,
    required String? storeLogoUrl,
    required String labelText,
    required double finalTotal,
    required int itemCount,
    required bool hasCoupon,
    required bool isFreeDelivery,
    required bool isGreenStatus,
    required String buttonLabel,
    required bool isHomeOrderAgainProcessing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/cart'),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // ✅ Logo da loja circular
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipOval(
                    child:
                        (storeLogoUrl != null && storeLogoUrl.isNotEmpty)
                            ? Image.network(
                              storeLogoUrl,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Icon(
                                    Icons.store,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                            )
                            : Icon(
                              Icons.store,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                // ✅ Informações do carrinho
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ Texto do label
                      if (isFreeDelivery)
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade800,
                            ),
                            children: [
                              const TextSpan(text: 'Total com '),
                              TextSpan(
                                text: 'entrega grátis',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          labelText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.normal,
                          ),
                        ),

                      const SizedBox(height: 2),

                      Row(
                        children: [
                          if (hasCoupon) ...[
                            Icon(
                              Icons.confirmation_number_rounded,
                              color: Colors.green.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                          ],

                          // ✅ Valor Total
                          Text(
                            finalTotal.toCurrency(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  isGreenStatus
                                      ? Colors.green.shade700
                                      : Colors.black87,
                            ),
                          ),

                          // ✅ Qtd Itens
                          Text(
                            ' / $itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ✅ Botão arredondado
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      isHomeOrderAgainProcessing
                          ? Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          )
                          : Text(
                            buttonLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ Variante padrão - sem logo, para Cart/Address/Checkout
  Widget _buildStandardVariant({
    required BuildContext context,
    required dynamic theme,
    required String labelText,
    required double finalTotal,
    required int itemCount,
    required bool hasCoupon,
    required bool isFreeDelivery,
    required bool isGreenStatus,
    required String buttonLabel,
    required double minOrder,
    required dynamic store,
  }) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // ✅ Informações do carrinho
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFreeDelivery)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                          children: [
                            const TextSpan(text: 'Total com '),
                            TextSpan(
                              text: 'entrega grátis',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        labelText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.normal,
                        ),
                      ),

                    const SizedBox(height: 2),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasCoupon) ...[
                          Icon(
                            Icons.confirmation_number_rounded,
                            color: Colors.green.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                        ],

                        // ✅ Valor Total
                        Text(
                          finalTotal.toCurrency(),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color:
                                isGreenStatus
                                    ? Colors.green.shade700
                                    : Colors.black87,
                          ),
                        ),

                        // ✅ Quantidade de itens
                        Text(
                          ' / $itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ✅ Botão arredondado
              GestureDetector(
                onTap:
                    onContinuePressed ??
                    () => _handleContinue(context, store, minOrder, finalTotal),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Lógica de continue para Cart e Address
  void _handleContinue(
    BuildContext context,
    dynamic store,
    double minOrder,
    double finalTotal,
  ) {
    // BLINDAGEM: Validação de itens indisponíveis
    final cart = context.read<CartCubit>().state.cart;
    if (cart.hasUnavailableItems) {
      _showUnavailableItemsModal(context, cart);
      return;
    }

    // Validação de loja fechada
    if (store != null) {
      final status = StoreStatusService.validateStoreStatus(store);

      if (!status.canReceiveOrders) {
        StoreClosedHelper.showModal(
          context,
          isCartPage: variant == CartBottomBarVariant.cart,
          isDesktop: MediaQuery.of(context).size.width >= 768,
          nextOpenTime: status.message,
          onSeeOtherOptions: () {
            Navigator.of(context).pop();
          },
        );
        return;
      }
    }

    // Validação de pedido mínimo
    if (minOrder > 0 && finalTotal < minOrder) {
      _showMinOrderBottomSheet(context, minOrder);
      return;
    }

    // Navegação baseada na variante
    final authState = context.read<AuthCubit>().state;

    if (variant == CartBottomBarVariant.cart) {
      if (authState.isLoggedIn) {
        context.go('/address');
      } else {
        context.go('/signin');
      }
    } else if (variant == CartBottomBarVariant.address) {
      context.go('/checkout');
    }
  }

  void _showMinOrderBottomSheet(BuildContext context, double minOrder) {
    final theme = context.read<DsThemeSwitcher>().theme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                  'O valor mínimo para entrega é de R\$ ${minOrder.toStringAsFixed(2)}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
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
  }

  void _showUnavailableItemsModal(BuildContext context, dynamic cart) {
    final unavailableItems =
        cart.items
            .where((item) => !item.isAvailable || item.hasUnavailableOptions)
            .toList();

    // Separa itens por tipo: horário (recuperável) vs permanente
    final scheduleItems =
        unavailableItems.where((item) {
          final reason = (item.unavailableReason ?? '').toLowerCase();
          return reason.startsWith('disponível');
        }).toList();
    final permanentItems =
        unavailableItems.where((item) {
          final reason = (item.unavailableReason ?? '').toLowerCase();
          return !reason.startsWith('disponível');
        }).toList();

    final hasOnlySchedule = permanentItems.isEmpty && scheduleItems.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (modalContext) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      hasOnlySchedule
                          ? Icons.schedule_rounded
                          : Icons.error_outline_rounded,
                      color:
                          hasOnlySchedule
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasOnlySchedule
                            ? 'Itens fora do horário'
                            : 'Itens indisponíveis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              hasOnlySchedule
                                  ? Colors.orange.shade800
                                  : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasOnlySchedule
                      ? 'Alguns itens só estão disponíveis em horários específicos.'
                      : 'Remova os itens indisponíveis para finalizar seu pedido.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),

                // Itens fora do horário (laranja)
                if (scheduleItems.isNotEmpty) ...[
                  ...scheduleItems.map(
                    (item) => _buildModalItem(
                      name: item.sizeName ?? item.product.name,
                      reason: item.unavailableReason ?? 'Fora do horário',
                      icon: Icons.schedule_rounded,
                      color: Colors.orange.shade700,
                      bgColor: const Color(0xFFFFF3E0),
                    ),
                  ),
                ],

                // Itens permanentemente indisponíveis (vermelho)
                if (permanentItems.isNotEmpty) ...[
                  ...permanentItems.map((item) {
                    // Coleta razões de opções indisponíveis
                    final optReasons = <String>[];
                    for (final v in item.variants) {
                      for (final o in v.options) {
                        if (!o.isAvailable && o.unavailableReason != null) {
                          optReasons.add(o.unavailableReason!);
                        }
                      }
                    }
                    final reason =
                        item.unavailableReason ??
                        (optReasons.isNotEmpty
                            ? optReasons.first
                            : 'Item indisponível');
                    return _buildModalItem(
                      name: item.sizeName ?? item.product.name,
                      reason: reason,
                      icon: Icons.cancel_rounded,
                      color: Colors.red.shade700,
                      bgColor: Colors.red.shade50,
                      extraReasons:
                          optReasons.length > 1 ? optReasons.sublist(1) : null,
                    );
                  }),
                ],

                const SizedBox(height: 16),

                // Botão principal
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(modalContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasOnlySchedule
                              ? Colors.orange.shade600
                              : Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      hasOnlySchedule ? 'Entendi' : 'Vou revisar minha sacola',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Widget _buildModalItem({
    required String name,
    required String reason,
    required IconData icon,
    required Color color,
    required Color bgColor,
    List<String>? extraReasons,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(reason, style: TextStyle(fontSize: 12, color: color)),
                if (extraReasons != null)
                  ...extraReasons.map(
                    (r) =>
                        Text(r, style: TextStyle(fontSize: 12, color: color)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
