import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/themes/ds_theme.dart';

import '../themes/ds_theme_switcher.dart';

class DsLoadingIndicator extends StatelessWidget {
  const DsLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return CircularProgressIndicator(
      color: theme.primaryColor,
    );
  }
}
