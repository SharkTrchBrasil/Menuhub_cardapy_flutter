import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme.dart';

import '../themes/ds_theme_switcher.dart';

class DsTextButton extends StatelessWidget {
  const DsTextButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {


    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
          foregroundColor: theme.secondaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: theme.bodyTextStyle
              .weighted(FontWeight.w600)
              .colored(theme.secondaryColor)),
      child: Text(
        label,
      ),
    );
  }
}
