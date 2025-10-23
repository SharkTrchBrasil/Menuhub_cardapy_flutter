// Crie ou substitua este arquivo: lib/pages/address/widgets/address_bottom_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/ds_primary_button.dart';

import '../../../cubit/auth_cubit.dart';

class AddressBottomBar extends StatelessWidget {
  final double totalPrice;
  final int totalItems;
  final VoidCallback onContinuePressed;

  const AddressBottomBar({
    super.key,
    required this.totalPrice,
    required this.totalItems,
    required this.onContinuePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;


    return Wrap(
      children: [
        Container(
            decoration: BoxDecoration(
              color: theme.cartBackgroundColor,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
              ],
            ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total com taxa de entrega', style: TextStyle(color: theme.cartTextColor)),

                    const SizedBox(height: 4),

                    // Se houver um desconto geral (cupom), mostra o preço antigo riscado
                    // if (hasGeneralDiscount)
                    //   Text(
                    //     subtotalPrice.toCurrency(), // Mostra o subtotal riscado
                    //     style: theme.paragraphTextStyle
                    //         .colored(theme.onBackgroundColor)
                    //         .copyWith(decoration: TextDecoration.lineThrough),
                    //   ),

                    // Mostra o preço final (com ou sem desconto)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [


                        // Mostra o ícone se o desconto for por cupom
                        // if (hasCoupon && hasGeneralDiscount) ...[
                        //   Icon(Icons.local_offer, size: 18, color: Colors.green),
                        //   const SizedBox(width: 4),
                        // ],
                        Text(
                          totalPrice.toCurrency(), // Mostra o total final
                          style: theme.headingTextStyle
                              .colored(theme.onBackgroundColor)
                              .weighted(FontWeight.bold),
                        ),
                  SizedBox(width: 6,),
                        Text(
                          '${totalItems.toString()} ${totalItems > 1 ? 'itens' : 'item'}',
                          style: TextStyle(color: theme.cartTextColor),
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

                    onPressed: onContinuePressed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );







    // return Container(
    //   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    //   decoration: BoxDecoration(
    //     color: theme.cartBackgroundColor,
    //     boxShadow: const [
    //       BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
    //     ],
    //   ),
    //   child: Row(
    //     children: [
    //       Column(
    //         mainAxisSize: MainAxisSize.min,
    //         crossAxisAlignment: CrossAxisAlignment.start,
    //         children: [
    //           Text(
    //             '${totalItems.toString()} ${totalItems > 1 ? 'itens' : 'item'}',
    //             style: TextStyle(color: theme.cartTextColor),
    //           ),
    //           const SizedBox(height: 4),
    //           Text(
    //             totalPrice.toCurrency(),
    //             style: theme.headingTextStyle.weighted(FontWeight.bold),
    //           ),
    //         ],
    //       ),
    //       const Spacer(),
    //       SizedBox(
    //         width: 160,
    //         child: DsPrimaryButton(
    //           label: 'Continuar',
    //           onPressed: onContinuePressed,
    //         ),
    //       ),
    //     ],
    //   ),
    // );
    //
    //

  }
}