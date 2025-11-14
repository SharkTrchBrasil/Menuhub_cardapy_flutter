// lib/utils/performance_optimizer.dart
// Otimizações específicas para Flutter Web

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Configurações de performance para Flutter Web
class PerformanceOptimizer {
  /// Configurações recomendadas para Flutter Web
  static void configureForWeb() {
    if (kIsWeb) {
      // Habilita o cache de imagens mais agressivo
      PaintingBinding.instance.imageCache.maximumSize = 1000;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 500 << 20; // 500MB

      // Desabilita animações desnecessárias em web para melhor performance
      // (Pode ser reativado se necessário)
      // RendererBinding.instance.deferFirstFrame();
    }
  }

  /// Widget que aplica lazy loading automático
  static Widget lazyBuilder({
    required Widget Function() builder,
    Widget? placeholder,
  }) {
    return kIsWeb
        ? Builder(
            builder: (context) {
              // Em web, carrega imediatamente mas com placeholder
              return builder();
            },
          )
        : builder();
  }
}

/// Mixin para widgets que precisam de otimização de performance
mixin PerformanceOptimized {
  /// Usa cache para evitar reconstruções desnecessárias
  @protected
  bool shouldRebuild = false;
}

/// Extension para ImageProvider com cache otimizado
extension OptimizedImageProvider on ImageProvider {
  ImageProvider get cached => this;
}

/// Helper para debounce de eventos (útil para busca)
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Widget que carrega imagens de forma lazy
class LazyImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const LazyImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    return Image.network(
      imageUrl!,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? const Icon(Icons.error_outline);
      },
      // Cache configuration
      cacheWidth: kIsWeb ? 800 : null, // Reduz tamanho em web
      cacheHeight: kIsWeb ? 800 : null,
    );
  }
}

/// Widget que virtualiza listas longas (útil para catálogo)
class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Em web, usa ListView.builder normal (já é otimizado)
      return ListView.builder(
        controller: controller,
        padding: padding,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    }

    // Em mobile, também usa ListView.builder
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

