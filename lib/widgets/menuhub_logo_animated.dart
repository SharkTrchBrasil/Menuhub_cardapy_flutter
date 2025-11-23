import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Logo animada do Menuhub para splash screen
class MenuhubLogoAnimated extends StatefulWidget {
  final double? size;
  final Color? color;
  final bool showText;
  final TextStyle? textStyle;

  const MenuhubLogoAnimated({
    super.key,
    this.size = 120,
    this.color,
    this.showText = true,
    this.textStyle,
  });

  @override
  State<MenuhubLogoAnimated> createState() => _MenuhubLogoAnimatedState();
}

class _MenuhubLogoAnimatedState extends State<MenuhubLogoAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Animação de escala (entrada suave)
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // Animação de fade (texto aparece depois)
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    // Animação de rotação sutil (pulso)
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.05,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Inicia a animação
    _controller.forward();

    // Loop suave de pulso após a animação inicial
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoColor = widget.color ?? theme.primaryColor;
    final defaultTextStyle = widget.textStyle ??
        TextStyle(
          fontSize: (widget.size ?? 120) * 0.5,
          fontWeight: FontWeight.bold,
          color: logoColor,
          letterSpacing: 2.0,
        );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 0.1, // Rotação muito sutil
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnimatedLogoIcon(
                  size: widget.size ?? 120,
                  color: logoColor,
                  animationValue: _controller.value,
                ),
                if (widget.showText) ...[
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Menuhub',
                      style: defaultTextStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ícone animado da logo
class _AnimatedLogoIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double animationValue;

  const _AnimatedLogoIcon({
    required this.size,
    required this.color,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AnimatedLogoPainter(
        color: color,
        animationValue: animationValue,
      ),
    );
  }
}

class _AnimatedLogoPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _AnimatedLogoPainter({
    required this.color,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = size.width * 0.08;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Animação de pulso no raio do círculo central
    final baseRadius = size.width * 0.35;
    final pulseRadius = baseRadius * (1.0 + math.sin(animationValue * 0.1) * 0.1);

    // Desenha o círculo central (hub) com pulso
    canvas.drawCircle(center, pulseRadius, paint);

    // Desenha as linhas conectadas com animação
    final lineLength = size.width * 0.25;
    final animatedLineLength = lineLength * (1.0 + math.sin(animationValue * 0.15) * 0.1);
    
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    // Linha superior
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - pulseRadius - animatedLineLength),
      linePaint,
    );

    // Linha inferior
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy + pulseRadius + animatedLineLength),
      linePaint,
    );

    // Linha esquerda
    canvas.drawLine(
      center,
      Offset(center.dx - pulseRadius - animatedLineLength, center.dy),
      linePaint,
    );

    // Linha direita
    canvas.drawLine(
      center,
      Offset(center.dx + pulseRadius + animatedLineLength, center.dy),
      linePaint,
    );

    // Desenha pequenos círculos nas extremidades (nós) com animação de pulso
    final nodeRadius = size.width * 0.06;
    final nodePulseRadius = nodeRadius * (1.0 + math.sin(animationValue * 0.2) * 0.2);
    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Nó superior
    canvas.drawCircle(
      Offset(center.dx, center.dy - pulseRadius - animatedLineLength),
      nodePulseRadius,
      nodePaint,
    );

    // Nó inferior
    canvas.drawCircle(
      Offset(center.dx, center.dy + pulseRadius + animatedLineLength),
      nodePulseRadius,
      nodePaint,
    );

    // Nó esquerdo
    canvas.drawCircle(
      Offset(center.dx - pulseRadius - animatedLineLength, center.dy),
      nodePulseRadius,
      nodePaint,
    );

    // Nó direito
    canvas.drawCircle(
      Offset(center.dx + pulseRadius + animatedLineLength, center.dy),
      nodePulseRadius,
      nodePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _AnimatedLogoPainter) {
      return oldDelegate.animationValue != animationValue;
    }
    return true;
  }
}

