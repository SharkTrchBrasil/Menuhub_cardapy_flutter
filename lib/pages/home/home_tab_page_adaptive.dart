import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/home/mobile/mobile_home.dart';
import 'package:totem/pages/home/desktop/desktop_home.dart';

/// Entry point adaptativo para a página Home
/// Escolhe automaticamente entre mobile e desktop
class HomeTabPageAdaptive extends StatelessWidget {
  const HomeTabPageAdaptive({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobileBuilder: (context, constraints) => const MobileHome(),
      tabletBuilder: (context, constraints) => const MobileHome(),
      desktopBuilder: (context, constraints) => const DesktopHome(),
    );
  }
}
