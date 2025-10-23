import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme.dart';

import '../themes/ds_theme_switcher.dart';

class DsSecondaryButton extends StatelessWidget {
  const DsSecondaryButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor:
        onPressed != null ? theme.secondaryColor : theme.inactiveColor,
        side: BorderSide(
            color:
            onPressed != null ? theme.secondaryColor : theme.inactiveColor),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: theme.bodyTextStyle
            .weighted(FontWeight.w600)
            .colored(theme.secondaryColor),
      ),
      child: Text(
        label,
      ),
    );
  }
}
