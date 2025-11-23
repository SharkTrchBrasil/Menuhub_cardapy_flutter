import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/profile/mobile/mobile_profile.dart';
import 'package:totem/pages/profile/desktop/desktop_profile.dart';

/// Entry point adaptativo para a página de Perfil
/// Escolhe automaticamente entre mobile e desktop
class ProfileTabPageAdaptive extends StatelessWidget {
  const ProfileTabPageAdaptive({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobileBuilder: (context, constraints) => const MobileProfile(),
      tabletBuilder: (context, constraints) => const MobileProfile(),
      desktopBuilder: (context, constraints) => const DesktopProfile(),
    );
  }
}
