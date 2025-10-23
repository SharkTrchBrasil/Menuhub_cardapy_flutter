import 'package:flutter/material.dart';

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    required this.mobileBuilder,
    required this.tabletBuilder,
    required this.desktopBuilder,
    super.key,
  });

  final Widget Function(
      BuildContext context,
      BoxConstraints constraints,
      ) mobileBuilder;

  final Widget Function(
      BuildContext context,
      BoxConstraints constraints,
      ) tabletBuilder;

  final Widget Function(
      BuildContext context,
      BoxConstraints constraints,
      ) desktopBuilder;

  // Dispositivos pequenos (celulares)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  // Dispositivos médios (tablets)
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
          MediaQuery.of(context).size.width < 1024;

  // Dispositivos grandes (notebooks e desktops)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024) {
          return desktopBuilder(context, constraints);
        } else if (constraints.maxWidth >= 768) {
          return tabletBuilder(context, constraints);
        } else {
          return mobileBuilder(context, constraints);
        }
      },
    );
  }
}
