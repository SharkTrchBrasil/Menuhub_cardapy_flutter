import 'package:flutter/material.dart';
import '../responsive_builder.dart';

/// Exibe um painel responsivo: side panel no desktop, full screen no mobile
Future<T?> showResponsiveSidePanel<T>(
  BuildContext context,
  Widget panel, {
  bool useHalfScreenOnDesktop = true,
  bool useFullScreenOnDesktop = false,
  bool showCloseButton = true,
}) {
  print('📱 [SidePanel] showResponsiveSidePanel chamado');
  final bool isMobile = ResponsiveBuilder.isMobile(context);
  final bool isDesktop = ResponsiveBuilder.isDesktop(context);

  print('📱 [SidePanel] isMobile: $isMobile, isDesktop: $isDesktop');

  // ✅ MOBILE = modal bottom sheet
  if (isMobile) {
    print('📱 [SidePanel] Abrindo modal bottom sheet para mobile');
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (context) => panel,
    );
  }

  // ✅ DESKTOP FULL SCREEN = modal full screen
  if (useFullScreenOnDesktop) {
    print('📱 [SidePanel] Abrindo modal full screen para desktop');
    return Navigator.of(context, rootNavigator: true).push<T>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.5),
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullScreenMobileWrapper(
            child: panel,
            showCloseButton: showCloseButton,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: Curves.easeOutCubic));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  } else if (isDesktop) {
    // ✅ DESKTOP = Dialog centralizado (como solicitado)
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  actions: [
                    if (showCloseButton)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Fechar',
                      ),
                  ],
                ),
                body: SafeArea(child: panel),
              ),
            ),
          ),
        );
      },
    );
  } else {
    // ✅ TABLET = side panel lateral
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return _SidePanelContainer(
          child: panel,
          useHalfScreen: useHalfScreenOnDesktop,
          showCloseButton: showCloseButton,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return SlideTransition(
          position: tween.animate(anim1),
          child: Align(alignment: Alignment.centerRight, child: child),
        );
      },
    );
  }
}

class _SidePanelContainer extends StatelessWidget {
  final Widget child;
  final bool useHalfScreen;
  final bool showCloseButton;

  const _SidePanelContainer({
    required this.child,
    this.useHalfScreen = false,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    double width;
    if (useHalfScreen) {
      width = screenWidth * 0.5;
    } else {
      double calculatedWidth = screenWidth * 0.4;
      const double minWidth = 400.0;
      const double maxWidth = 600.0;
      width = calculatedWidth.clamp(minWidth, maxWidth);
    }

    return SizedBox(
      width: width,
      height: double.infinity,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(''),
          actions: [
            if (showCloseButton)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 24, color: Colors.red),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Fechar',
                ),
              ),
          ],
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(child: child),
      ),
    );
  }
}

class _FullScreenMobileWrapper extends StatelessWidget {
  final Widget child;
  final bool showCloseButton;

  const _FullScreenMobileWrapper({
    required this.child,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(''),
        actions: [
          if (showCloseButton)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: IconButton(
                icon: const Icon(Icons.close, size: 24, color: Colors.red),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
              ),
            ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(child: child),
    );
  }
}
