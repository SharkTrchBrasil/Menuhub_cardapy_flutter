import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../models/product.dart';

Widget _buildProductImage(Product product) {
  // ✅ NOVA LÓGICA: Usa a galeria de imagens
  final coverImageUrl = product.coverImageUrl; // Já usa a galeria internamente

  return ClipRRect(
    borderRadius: BorderRadius.circular(8.0),
    child: SizedBox(
      width: 80,
      height: 80,
      child: coverImageUrl != null
          ? CachedNetworkImage(
        imageUrl: coverImageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      )
          : _buildPlaceholder(),
    ),
  );
}

Widget _buildPlaceholder() {
  return Container(
    color: Colors.grey.shade100,
    child: Center(
      child: SvgPicture.asset(
        'assets/icons/burguer.svg',
        width: 42,
        height: 42,
        colorFilter: ColorFilter.mode(Colors.grey.shade400, BlendMode.srcIn),
        semanticsLabel: 'Imagem padrão do produto',
      ),
    ),
  );
}