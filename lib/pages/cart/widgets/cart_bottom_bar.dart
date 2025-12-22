import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:totem/core/extensions.dart';
import 'package:totem/themes/ds_theme.dart';

import '../../../cubit/auth_cubit.dart';
import '../../../themes/ds_theme_switcher.dart';
import '../../../widgets/ds_primary_button.dart';

import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/helpers/store_hours_helper.dart';
import 'package:totem/widgets/store_closed_widgets.dart';
import 'package:totem/services/store_status_service.dart';

class CartBottomBar extends StatelessWidget {
  // ✅ CORREÇÃO: Parâmetros renomeados para clareza
  final double subtotal;
  final double finalTotal;

  final double minOrder;

  final bool hasCoupon;


  const CartBottomBar({
    super.key,
    required this.subtotal,
    required this.finalTotal,

    required this.minOrder,

    required this.hasCoupon,

  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    // ✅ CORREÇÃO: A condição agora compara subtotal e total final
    final bool hasGeneralDiscount = finalTotal < subtotal;

    return Container(
      decoration: BoxDecoration(color: theme.cartBackgroundColor),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total sem taxa de entrega', style: TextStyle(color: theme.cartTextColor)),

                const SizedBox(height: 4),

                // Se houver um desconto geral (cupom), mostra o preço antigo riscado
                if (hasGeneralDiscount)
                  Text(
                    subtotal.toCurrency(), // Mostra o subtotal riscado
                    style: theme.paragraphTextStyle
                        .colored(theme.onBackgroundColor)
                        .copyWith(decoration: TextDecoration.lineThrough),
                  ),

                // Mostra o preço final (com ou sem desconto)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mostra o ícone se o desconto for por cupom
                    if (hasCoupon && hasGeneralDiscount) ...[
                      Icon(Icons.local_offer, size: 18, color: Colors.green),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      finalTotal.toCurrency(), // Mostra o total final
                      style: theme.headingTextStyle
                          .colored(theme.onBackgroundColor)
                          .weighted(FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 160,
              child: DsPrimaryButton(
                label: 'Continuar',
                onPressed: () {
                  // ✅ NOVO: Validação de loja fechada (impossibilita continuar)
                  final activeStore = context.read<StoreCubit>().state.store;
                  if (activeStore != null) {
                    // ✅ CORREÇÃO: Usa o serviço centralizado para validar TODOS os cenários (pausa, fechado manual, horários)
                    final status = StoreStatusService.validateStoreStatus(activeStore);
                    
                    if (!status.canReceiveOrders) {
                      StoreClosedHelper.showModal(
                        context,
                        isCartPage: true,
                        isDesktop: MediaQuery.of(context).size.width >= 768,
                        nextOpenTime: status.message, // Passa a mensagem correta (ex: motivo da pausa ou horário de abertura)
                        onSeeOtherOptions: () {
                          // Apenas fecha o modal, mantendo o usuário na sacola para ver os itens
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
                                  'O valor mínimo para entrega é de R\$ ${minOrder.toCurrency()}.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DsPrimaryButton(
                                        onPressed: () => context.pop(),
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
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    );
                  } else {

                    // ✅ A verificação é simples e direta
                    final authState = context.read<AuthCubit>().state;

                    if (authState.isLoggedIn) {
                      // ✅ NOVO: Desktop vai direto para checkout unificado
                      final isDesktop = MediaQuery.of(context).size.width >= 768;
                      if (isDesktop) {
                        // ✅ Fecha o sidepanel (se estiver dentro de um) antes de navegar
                        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
                        // Use um delay pequeno para garantir que o sidepanel fechou
                        Future.microtask(() => context.go('/checkout'));
                      } else {
                        context.go('/address');
                      }
                    } else {
                      context.push('/onboarding');
                    }


                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
