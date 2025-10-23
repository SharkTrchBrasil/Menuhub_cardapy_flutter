import 'package:flutter/material.dart';
import 'dart:async';

class AnimatedHourglassSequence extends StatefulWidget {
  const AnimatedHourglassSequence({super.key});

  @override
  _AnimatedHourglassSequenceState createState() => _AnimatedHourglassSequenceState();
}

class _AnimatedHourglassSequenceState extends State<AnimatedHourglassSequence>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Timer _timer;
  int _iconIndex = 0;

  final List<IconData> _icons = [
    Icons.hourglass_top,
    Icons.hourglass_bottom,
    Icons.hourglass_empty,
  ];

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Gira continuamente

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        _iconIndex = (_iconIndex + 1) % _icons.length;
      });
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotationTransition(
        turns: _rotationController,
        child: Icon(
          _icons[_iconIndex],
          size: 48,
          color: Colors.orange,
        ),
      ),
    );
  }
}
