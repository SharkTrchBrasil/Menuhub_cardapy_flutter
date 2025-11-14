import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/widgets/desktop_navigation.dart';
import 'simple_home_page.dart';

/// Wrapper para desktop que inclui navegação lateral e conteúdo
class DesktopHomeWrapper extends StatelessWidget {
  const DesktopHomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveBuilder.isDesktop(context)) {
      // Se não for desktop, retorna apenas o conteúdo
      return const SimpleHomePage();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Conteúdo principal (ajustado para sidebar)
          Positioned(
            left: 80,
            right: 0,
            top: 0,
            bottom: 0,
            child: const SimpleHomePage(),
          ),
          // Navegação lateral desktop
          const DesktopNavigation(),
        ],
      ),
    );
  }
}

