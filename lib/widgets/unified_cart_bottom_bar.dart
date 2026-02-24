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
            final cart = cartState.cart;
            
            // ✅ Não mostra se o carrinho estiver vazio
            if (cart.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
              builder: (context, feeState) {
                // ✅ Lógica unificada de cálculo de frete
                double deliveryFee = 0.0;
                bool isDeliveryFreeFromRule = false;

                if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
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
                  final appliedCoupon = storeCoupons.where(
                    (c) => c.code.toUpperCase() == cart.couponCode!.toUpperCase()
                  ).firstOrNull;
                  
                  if (appliedCoupon != null && appliedCoupon.isFreeDelivery) {
                    hasFreeDeliveryCoupon = true;
                  } else if (cart.isFreeDelivery) {
                    hasFreeDeliveryCoupon = true;
                  }
                }

                final isFreeDelivery = isDeliveryFreeFromRule || hasFreeDeliveryCoupon;
                final effectiveFee = isFreeDelivery ? 0.0 : deliveryFee;

                // ✅ Cálculo do total
                final subtotalValue = cart.subtotal / 100.0;
                final discountValue = cart.discount / 100.0;
                final finalTotal = subtotalValue - discountValue + effectiveFee;
                
                final itemCount = cart.items.fold<int>(0, (sum, item) => sum + (item.quantity > 0 ? item.quantity : 1));
                final hasCoupon = cart.discount > 0 || hasFreeDeliveryCoupon;

                // ✅ Texto dinâmico baseado no contexto
                String labelText;
                if (variant == CartBottomBarVariant.home) {
                  labelText = isFreeDelivery ? 'Total com entrega grátis' : 'Total com entrega';
                } else {
                  labelText = isFreeDelivery ? 'Total com entrega grátis' : 'Total com entrega';
                }

                // ✅ Texto do botão baseado na variante
                String buttonLabel = overrideButtonLabel ?? '';
                if (buttonLabel.isEmpty) {
                  switch (variant) {
                  case CartBottomBarVariant.home:
                    buttonLabel = 'Ver sacola';
                    break;
                  case CartBottomBarVariant.cart:
                  case CartBottomBarVariant.address:
                    buttonLabel = 'Continuar';
                    break;
                  case CartBottomBarVariant.checkout:
                    buttonLabel = 'Finalizar';
                    break;
                }
                } // Fecha o if (buttonLabel.isEmpty)

                // ✅ Build baseado na variante
                if (variant == CartBottomBarVariant.home) {
                  return _buildHomeVariant(
                    context: context,
                    theme: theme,
                    storeLogoUrl: storeLogoUrl,
                    labelText: labelText,
                    finalTotal: finalTotal,
                    itemCount: itemCount,
                    hasCoupon: hasCoupon,
                    isFreeDelivery: isFreeDelivery,
                    buttonLabel: buttonLabel,
                  );
                } else {
                  return _buildStandardVariant(
                    context: context,
                    theme: theme,
                    labelText: labelText,
                    finalTotal: finalTotal,
                    itemCount: itemCount,
                    hasCoupon: hasCoupon,
                    isFreeDelivery: isFreeDelivery,
                    buttonLabel: buttonLabel,
                    minOrder: minOrder,
                    store: store,
                  );
                }
              },
            );
          },
        );
      },
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
    required String buttonLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/cart'),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    child: (storeLogoUrl != null && storeLogoUrl.isNotEmpty)
                        ? Image.network(
                            storeLogoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
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
                      // ✅ Texto do label (Total com entrega grátis)
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
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
                          // ✅ Ícone de ticket verde
                          if (hasCoupon || isFreeDelivery) ...[
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
                              color: (hasCoupon || isFreeDelivery) ? Colors.green.shade700 : Colors.black87,
                            ),
                          ),
                          
                          // ✅ Qtd Itens
                          Text(
                            ' / $itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.normal, // Mantém peso normal
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ✅ Botão arredondado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
    required String buttonLabel,
    required double minOrder,
    required dynamic store,
  }) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8,),
          child: Row(
            children: [
              // ✅ Informações do carrinho (sem logo)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Texto do label (Total com entrega grátis)
                    // Se for frete grátis, usa RichText para fazer apenas "entrega grátis" bold
                    if (isFreeDelivery)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800, // Texto base preto/cinza
                          ),
                          children: [
                            const TextSpan(text: 'Total com '),
                            TextSpan(
                              text: 'entrega grátis',
                              style: const TextStyle(fontWeight: FontWeight.bold), // Apenas isso em bold
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
                    
                    const SizedBox(height: 2), // Pequeno espaçamento

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ✅ Ícone de ticket verde se tiver desconto ou frete grátis
                        if (hasCoupon || isFreeDelivery) ...[
                          Icon(
                            Icons.confirmation_number_rounded, // Ícone estilo ticket
                            color: Colors.green.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                        ],
                        
                        // ✅ Valor Total (Verde se tem benefício)
                        Text(
                          finalTotal.toCurrency(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: (hasCoupon || isFreeDelivery) ? Colors.green.shade700 : Colors.black87,
                          ),
                        ),
                        
                        // ✅ Quantidade de itens (Cinza)
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
                onTap: onContinuePressed ?? () => _handleContinue(context, store, minOrder, finalTotal),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
  void _handleContinue(BuildContext context, dynamic store, double minOrder, double finalTotal) {
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
      builder: (_) => Padding(
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
}
