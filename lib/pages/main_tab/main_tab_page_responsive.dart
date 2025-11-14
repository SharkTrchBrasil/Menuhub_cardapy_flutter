import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'main_tab_page.dart';
import '../home/simple_home_page.dart';

/// Wrapper responsivo que usa tabs no mobile e rotas no desktop
class MainTabPageResponsive extends StatelessWidget {
  const MainTabPageResponsive({super.key});

  @override
  Widget build(BuildContext context) {
    // Mobile: usa tabs
    if (ResponsiveBuilder.isMobile(context)) {
      return const MainTabPage();
    }
    
    // Desktop: usa home simples (rotas serão gerenciadas pelo GoRouter)
    return const SimpleHomePage();
  }
}

