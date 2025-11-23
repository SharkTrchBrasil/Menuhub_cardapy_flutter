import 'package:flutter/material.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/pages/product/widgets/mobilelayout.dart';
import 'package:totem/themes/ds_theme.dart';

/// Mobile Product Page
/// Implementação específica para dispositivos móveis
class MobileProduct extends StatelessWidget {
  final ProductPageState productState;
  final TextEditingController observationController;
  final DsTheme theme;

  const MobileProduct({
    super.key,
    required this.productState,
    required this.observationController,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return MobileProductPage(
      productState: productState,
      observationController: observationController,
      theme: theme,
    );
  }
}
