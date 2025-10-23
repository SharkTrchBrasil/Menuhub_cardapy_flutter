// Em: lib/widgets/ds_primary_button.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme.dart';

import '../themes/ds_theme_switcher.dart';

class DsPrimaryButton extends StatelessWidget {
  const DsPrimaryButton({
    super.key,
    this.label, // ✅ 1. 'label' agora é opcional
    this.child, // ✅ 2. 'child' foi adicionado como um parâmetro opcional
    this.onPressed,
  }) : assert(label != null || child != null,
  'É necessário fornecer ou uma "label" ou um "child".');
  // O assert garante que o botão nunca estará vazio.

  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.onPrimaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      child: child ?? Text(
          label!, // Usamos '!' aqui porque o assert garante que label não será nulo se child for nulo.
          style: theme.bodyTextStyle
              .copyWith(color: Colors.white, fontWeight: FontWeight.w600)
      ),
    );
  }
}