import 'package:flutter/material.dart';

class WaveProgressIndicator extends StatefulWidget {
  final double value;
  final Color baseColor;
  final Color waveColor;
  final double height;

  const WaveProgressIndicator({
    super.key,
    required this.value,
    this.baseColor = const Color(0xFFE8F5E9),
    this.waveColor = Colors.green,
    this.height = 4.0,
  });

  @override
  State<WaveProgressIndicator> createState() => _WaveProgressIndicatorState();
}

class _WaveProgressIndicatorState extends State<WaveProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.baseColor,
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: widget.waveColor.withOpacity(0.1),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Barra de progresso base
              FractionallySizedBox(
                widthFactor: widget.value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.waveColor,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.waveColor.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              // Efeito de onda / brilho neon se movendo
              if (widget.value > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.value.clamp(0.0, 1.0),
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment(
                            -1.0 + (_controller.value * 2.5),
                            0.0,
                          ),
                          end: Alignment(-0.1 + (_controller.value * 2.5), 0.0),
                          colors: [
                            widget.waveColor.withOpacity(0.0),
                            Colors.white.withOpacity(0.6),
                            widget.waveColor.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(rect);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(
                            widget.height / 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
