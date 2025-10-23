import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'classic/Classic.dart';
import 'HomeDarkBurguerPage.dart';
import 'HomeModernPage.dart';
import 'ds_theme_switcher.dart';

class HomeSelectorPage extends StatelessWidget {
  const HomeSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme.themeName;

    final themes = <String, WidgetBuilder>{
      'classic': (_) => const ClassicTheme(),
      'fancy': (_) => const HomeDarkBurguerPage(),
      'modern': (_) => const HomeModernPage(),
      'minimal': (_) => const HomeModernPage(),
    };

    // Escolhe o tema com base no nome; se não encontrar, usa 'Classic'
    return themes[theme.name]?.call(context) ?? const ClassicTheme();
  }
}
