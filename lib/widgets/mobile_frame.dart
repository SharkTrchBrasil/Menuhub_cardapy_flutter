import 'package:flutter/material.dart';

/// ✅ MOBILE-FRAME: Limita o conteúdo a max 412px de largura (mobile real)
/// No desktop, centraliza com espaço igual nos lados (igual iFood/123rifas)
/// O fundo fora do frame fica com cor neutra.
/// 
/// Usa LayoutBuilder para injetar MediaQuery com largura mobile,
/// garantindo que widgets internos (que usam MediaQuery.of(context).size)
/// calculem layout baseado na largura mobile, não na largura real da janela.
class MobileFrame extends StatelessWidget {
  final Widget child;
  final Color sideColor;

  /// Largura máxima do viewport mobile (Pixel/Android padrão)
  static const double maxMobileWidth = 412.0;

  const MobileFrame({
    super.key,
    required this.child,
    this.sideColor = const Color(0xFFF0F0F0),
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Se já está em mobile, não aplica frame
    if (screenWidth <= maxMobileWidth) {
      return child;
    }

    final mediaData = MediaQuery.of(context);

    return ColoredBox(
      color: sideColor,
      child: Center(
        child: SizedBox(
          width: maxMobileWidth,
          child: MediaQuery(
            // ✅ Override: widgets filhos verão 412px como largura da "tela"
            data: mediaData.copyWith(
              size: Size(maxMobileWidth, mediaData.size.height),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
