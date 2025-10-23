import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme.dart';

import '../../../themes/ds_theme_switcher.dart';

class DsCard extends StatelessWidget {
  const DsCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return Material(
      elevation: 1,
      color: theme.productBackgroundColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }
}
