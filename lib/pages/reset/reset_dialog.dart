import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import 'package:totem/widgets/ds_secondary_button.dart';

import '../../themes/ds_theme_switcher.dart';

class ResetDialog extends StatefulWidget {
  const ResetDialog({super.key});

  @override
  State<ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<ResetDialog> {

  Timer? timer;
  int count = 15;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        count--;
      });
      if(count == 0) {
        reset();
      }
    });
  }

  void reset() {
    timer?.cancel();
    context.go('/start');
    // TODO: Zerar o carrinho
  }

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return Dialog(
      backgroundColor: theme.cardColor,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Você ainda está por aí?',
              style: theme.displayLargeTextStyle
                  .colored(theme.onCardColor)
                  .weighted(FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              'Se você não estiver mais aqui, o pedido será cancelado em ',
              textAlign: TextAlign.center,
              style: theme.bodyTextStyle
                  .colored(theme.onCardColor),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.timer_outlined,
              size: 70,
            ),
            Text(
              '$count segundos',
              style: theme.displayLargeTextStyle
                  .colored(theme.onCardColor)
                  .weighted(FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DsSecondaryButton(
                    label: 'Reiniciar',
                    onPressed: reset,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DsPrimaryButton(
                    label: 'Estou aqui!',
                    onPressed: context.pop,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
