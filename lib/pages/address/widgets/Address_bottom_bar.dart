// Crie ou substitua este arquivo: lib/pages/address/widgets/address_bottom_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

class AddressBottomBar extends StatelessWidget {
  final double totalPrice;
  final int totalItems;
  final VoidCallback? onContinuePressed; // ✅ Nullable para desabilitar quando necessário
  final String? errorMessage; // ✅ Mensagem de erro opcional

  const AddressBottomBar({
    super.key,
    required this.totalPrice,
    required this.totalItems,
    this.onContinuePressed,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final bool isDisabled = onContinuePressed == null;

    return Wrap(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.cartBackgroundColor,
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Mostra mensagem de erro se houver
              if (errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Não é possível continuar: endereço fora da área de entrega',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total com taxa de entrega',
                          style: TextStyle(color: theme.cartTextColor),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              totalPrice.toCurrency(),
                              style: theme.headingTextStyle
                                  .colored(theme.onBackgroundColor)
                                  .weighted(FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
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
                      child: ElevatedButton(
                        onPressed: onContinuePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDisabled 
                              ? Colors.grey.shade400 
                              : theme.primaryColor,
                          foregroundColor: theme.onPrimaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Continuar',
                          style: theme.bodyTextStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}