import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme.dart';

import '../themes/ds_theme_switcher.dart';

class DsIconButton extends StatelessWidget {
  const DsIconButton({super.key, this.size = 48, required this.icon, this.onPressed});

  final double size;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        borderRadius: BorderRadius.circular(size / 2),
        color: onPressed != null ? theme.primaryColor : theme.inactiveColor,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(
            icon,
            color: onPressed != null ? theme.onPrimaryColor : theme.onInactiveColor,
          ),
        ),
      ),
    );
  }
}
