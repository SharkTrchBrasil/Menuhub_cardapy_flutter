import 'package:flutter/material.dart';
import 'package:totem/pages/main_tab/main_tab_page.dart';

/// Classic Theme - Usa MainTabPage para gerenciar as tabs
class ClassicTheme extends StatelessWidget {
  const ClassicTheme({super.key});

  @override
  Widget build(BuildContext context) {
    // Usa o MainTabPage que gerencia todas as tabs (home/carrinho/pedidos/perfil)
    return const MainTabPage();
  }
}
