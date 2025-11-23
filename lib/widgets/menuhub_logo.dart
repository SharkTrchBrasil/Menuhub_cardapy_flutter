import 'package:flutter/material.dart';

/// Logo estática do Menuhub para uso em headers e outras partes da UI
class MenuhubLogo extends StatelessWidget {
  final double? size;
  final Color? color;
  final bool showText;
  final TextStyle? textStyle;

  const MenuhubLogo({
    super.key,
    this.size = 40,
    this.color,
    this.showText = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoColor = color ?? theme.primaryColor;
    final defaultTextStyle = textStyle ??
        TextStyle(
          fontSize: (size ?? 40) * 0.6,
          fontWeight: FontWeight.bold,
          color: logoColor,
          letterSpacing: 1.2,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoIcon(
          size: size ?? 40,
          color: logoColor,
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Text(
            'Menuhub',
            style: defaultTextStyle,
          ),
        ],
      ],
    );
  }
}

/// Ícone da logo (hub/menu estilizado)
class _LogoIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _LogoIcon({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoPainter(color: color),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;

  _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = size.width * 0.08;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    // Desenha o círculo central (hub)
    canvas.drawCircle(center, radius, paint);

    // Desenha as linhas conectadas (representando conexões/hub)
    final lineLength = size.width * 0.25;
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    // Linha superior
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius - lineLength),
      linePaint,
    );

    // Linha inferior
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy + radius + lineLength),
      linePaint,
    );

    // Linha esquerda
    canvas.drawLine(
      center,
      Offset(center.dx - radius - lineLength, center.dy),
      linePaint,
    );

    // Linha direita
    canvas.drawLine(
      center,
      Offset(center.dx + radius + lineLength, center.dy),
      linePaint,
    );

    // Desenha pequenos círculos nas extremidades das linhas (nós)
    final nodeRadius = size.width * 0.06;
    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Nó superior
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius - lineLength),
      nodeRadius,
      nodePaint,
    );

    // Nó inferior
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius + lineLength),
      nodeRadius,
      nodePaint,
    );

    // Nó esquerdo
    canvas.drawCircle(
      Offset(center.dx - radius - lineLength, center.dy),
      nodeRadius,
      nodePaint,
    );

    // Nó direito
    canvas.drawCircle(
      Offset(center.dx + radius + lineLength, center.dy),
      nodeRadius,
      nodePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

