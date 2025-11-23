import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/home/desktop/desktop_home_with_appbar.dart';
import 'simple_home_page.dart';

/// Wrapper para desktop que usa AppBar horizontal estilo iFood
class DesktopHomeWrapper extends StatelessWidget {
  const DesktopHomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveBuilder.isDesktop(context)) {
      // Se não for desktop, retorna apenas o conteúdo mobile
      return const SimpleHomePage();
    }

    // Desktop usa AppBar horizontal estilo iFood (sem sidebar)
    return const DesktopHomeWithAppBar();
  }
}

