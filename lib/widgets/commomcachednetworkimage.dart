import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

/// Widget otimizado para imagens de rede com cache
/// ✅ OTIMIZADO: Usa CachedNetworkImage em todas as plataformas
Widget commonCacheImageWidget(String? url, double height,
    {double? width, BoxFit? fit, Color? color}) {
  if (url.validate().startsWith('http')) {
    // ✅ CORREÇÃO: Usa cache em todas as plataformas (mobile e web)
    return CachedNetworkImage(
      imageUrl: url!,
      height: height,
      width: width,
      color: color,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) => Container(
        height: height,
        width: width,
        color: Colors.grey.shade200,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        width: width,
        color: Colors.grey.shade100,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey.shade400,
          size: 32,
        ),
      ),
      // ✅ PERFORMANCE: Define tamanhos máximos para cache
      memCacheWidth: width?.toInt(),
      memCacheHeight: height.toInt(),
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
    );
  } else if (url != null && url.isNotEmpty) {
    return Image.asset(
      url,
      height: height,
      width: width,
      fit: fit ?? BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: width,
        color: Colors.grey.shade100,
      ),
    );
  }
  
  // URL vazia ou nula
  return Container(
    height: height,
    width: width,
    color: Colors.grey.shade100,
    child: Icon(
      Icons.image_outlined,
      color: Colors.grey.shade400,
      size: 32,
    ),
  );
}

Widget? Function(BuildContext, String) placeholderWidgetFn() =>
    (_, s) => placeholderWidget();

Widget placeholderWidget() => Container(
  color: Colors.grey.shade200,
  child: const Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  ),
);