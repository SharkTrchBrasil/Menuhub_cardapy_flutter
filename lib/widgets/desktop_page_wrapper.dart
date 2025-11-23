import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';

/// Wrapper genérico para páginas desktop (sem sidebar)
/// Páginas que precisam de AppBar devem implementá-lo internamente
class DesktopPageWrapper extends StatelessWidget {
  final Widget child;

  const DesktopPageWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Retorna apenas o conteúdo, sem sidebar
    // O AppBar deve ser implementado pela própria página se necessário
    return child;
  }
}

