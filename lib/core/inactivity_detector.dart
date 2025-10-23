// totem/core/inactivity_detector.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Importe GoRouter

class InactivityDetector extends StatefulWidget {
  // Adicione a instância do GoRouter aqui
  final GoRouter appRouter; // <-- Novo parâmetro
  const InactivityDetector({super.key, required this.child, required this.appRouter}); // <-- Adicione no construtor

  final Widget child;

  @override
  State<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends State<InactivityDetector> {
  Timer? timer;

  final monitoredPaths = ['/', 'product', 'add-coupon'];

  void _handleRouteChange() {
    // Acesse o router através de widget.appRouter
    final path = widget.appRouter.routerDelegate.currentConfiguration.last.route.path;

    if (monitoredPaths.contains(path)) {
      start();
    } else {
      timer?.cancel();
    }
  }

  void start() {
    timer?.cancel();
    timer = Timer(const Duration(seconds: 600), () {
      // Acesse o router através de widget.appRouter
      widget.appRouter.push('/reset');
    });
  }

  @override
  void initState() {
    super.initState();
    // Adicione o listener ao router passado
    widget.appRouter.routerDelegate.addListener(_handleRouteChange);
  }

  @override
  void dispose() {
    // Remova o listener do router passado
    widget.appRouter.routerDelegate.removeListener(_handleRouteChange);
    timer?.cancel(); // Cancelar o timer também no dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapInside: (_) {
        start();
      },
      child: widget.child,
    );
  }
}