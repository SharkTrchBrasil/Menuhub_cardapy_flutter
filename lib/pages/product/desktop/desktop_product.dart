import 'package:flutter/material.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/pages/product/widgets/desktop/desktop_product_card.dart';

/// Desktop Product Page
/// Implementação específica para desktop
class DesktopProduct extends StatelessWidget {
  final ProductPageState productState;
  final TextEditingController observationController;

  const DesktopProduct({
    super.key,
    required this.productState,
    required this.observationController,
  });

  @override
  Widget build(BuildContext context) {
    return DesktopProductCard(
      productState: productState,
      observationController: observationController,
    );
  }
}
