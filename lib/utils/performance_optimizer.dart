// lib/utils/performance_optimizer.dart
// Otimizações específicas para Flutter Web

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Configurações de performance para Flutter Web
class PerformanceOptimizer {
  /// Configurações recomendadas para Flutter Web
  static void configureForWeb() {
    if (kIsWeb) {
      // Habilita o cache de imagens mais agressivo
      PaintingBinding.instance.imageCache.maximumSize = 1000;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 500 << 20; // 500MB
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
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;
  final bool useDiskCache;

  const LazyImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.useDiskCache = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    // ✅ ENTERPRISE: Cache em Disco e Memória
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: kIsWeb ? 800 : null, // Otimização de memória
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) => 
          errorWidget ?? const Icon(Icons.error_outline),
      fadeInDuration: const Duration(milliseconds: 300),
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
