import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'desktop_navigation.dart';

/// Wrapper genérico para páginas desktop com navegação lateral
class DesktopPageWrapper extends StatelessWidget {
  final Widget child;

  const DesktopPageWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveBuilder.isDesktop(context)) {
      // Se não for desktop, retorna apenas o conteúdo
      return child;
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
            child: child,
          ),
          // Navegação lateral desktop
          const DesktopNavigation(),
        ],
      ),
    );
  }
}

