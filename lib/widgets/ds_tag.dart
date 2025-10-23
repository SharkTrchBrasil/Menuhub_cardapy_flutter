import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme.dart';

import '../themes/ds_theme_switcher.dart';

class DsTag extends StatelessWidget {
  const DsTag({super.key, required this.label, this.icon, this.onTap}) : textSize = 11;

  final String label;
  final double textSize;
  final Widget? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {

    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if(icon != null) ... [
              icon!,
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.displayLargeTextStyle
                  .colored(theme.onPrimaryColor)
                  .weighted(FontWeight.w900)
                  .copyWith(
                fontSize: textSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
