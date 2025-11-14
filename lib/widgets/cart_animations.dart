// lib/widgets/cart_animations.dart
import 'package:flutter/material.dart';

/// Animações para adicionar itens ao carrinho
class CartAnimations {
  /// Animação de escala ao adicionar item
  static Widget scaleAnimation({
    required Widget child,
    required bool isAdding,
  }) {
    return AnimatedScale(
      scale: isAdding ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: child,
    );
  }

  /// Animação de slide ao remover item
  static Widget slideAnimation({
    required Widget child,
    required bool isRemoving,
    required VoidCallback onComplete,
  }) {
    return AnimatedSlide(
      offset: isRemoving ? const Offset(1.0, 0.0) : Offset.zero,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      onEnd: isRemoving ? onComplete : null,
      child: AnimatedOpacity(
        opacity: isRemoving ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: child,
      ),
    );
  }

  /// Badge animado com número de itens
  static Widget animatedBadge({
    required int count,
    required Widget child,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: -6,
            top: -3,
            child: TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: count),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value > 0 ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$value',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Hero animation para produto sendo adicionado ao carrinho
class CartHeroAnimation extends StatelessWidget {
  final String heroTag;
  final Widget child;

  const CartHeroAnimation({
    super.key,
    required this.heroTag,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}

