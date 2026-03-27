import 'dart:math' as math;
import 'package:flutter/material.dart';

class DotLoading extends StatefulWidget {
  final Color color;
  final double size;
  final double spacing;

  const DotLoading({
    super.key,
    this.color = Colors.black,
    this.size = 10.0,
    this.spacing = 6.0,
  });

  @override
  State<DotLoading> createState() => _DotLoadingState();
}

class _DotLoadingState extends State<DotLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _controller.addListener(_tick);
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final delay = index * 0.2;
        final t = (_controller.value - delay) % 1.0;
        final bounce = math.sin(t * math.pi).clamp(0.0, 1.0);
        return Container(
          width: widget.size,
          height: widget.size,
          margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.4 + bounce * 0.6),
            shape: BoxShape.circle,
          ),
          transform: Matrix4.translationValues(0, -bounce * 6, 0),
        );
      }),
    );
  }
}
