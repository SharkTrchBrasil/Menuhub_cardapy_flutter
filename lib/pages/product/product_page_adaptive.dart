import 'package:flutter/material.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/product/product_page.dart';

/// Entry point adaptativo para a página de Produto
/// Simplesmente delega para ProductPage que já tem lógica responsiva
class ProductPageAdaptive extends StatelessWidget {
  const ProductPageAdaptive({super.key});

  @override
  Widget build(BuildContext context) {
    // ProductPage já tem lógica responsiva interna
    // Apenas delegamos para ele
    return const ProductPage();
  }
}
