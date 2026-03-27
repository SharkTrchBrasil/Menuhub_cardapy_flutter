import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Widget que rotaciona dinamicamente entre múltiplas animações Lottie de food.
/// A cada instância, escolhe uma animação aleatória da lista.
class DynamicFoodLoading extends StatelessWidget {
  final double width;
  final double height;

  /// Lista de animações Lottie disponíveis em assets/animations/
  /// Adicione novos arquivos .json aqui para expandir a rotação.
  static const List<String> _animations = [
    'assets/animations/food_burger.json',
    'assets/animations/food_pizza.json',
    'assets/animations/food_coffee.json',
    'assets/animations/food_cupcake.json',
    'assets/animations/Cooking.json',
  ];

  /// Índice aleatório selecionado na criação do widget
  final int _selectedIndex;

  DynamicFoodLoading({super.key, this.width = 180, this.height = 180})
    : _selectedIndex = Random().nextInt(_animations.length);

  @override
  Widget build(BuildContext context) {
    final asset = _animations[_selectedIndex];

    return SizedBox(
      width: width,
      height: height,
      child: Lottie.asset(
        asset,
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (context, error, stackTrace) {
          // Fallback: tenta a primeira animação, ou CircularProgressIndicator
          if (_selectedIndex != 0) {
            return Lottie.asset(
              _animations[0],
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (_, __, ___) => const _FallbackSpinner(),
            );
          }
          return const _FallbackSpinner();
        },
      ),
    );
  }
}

class _FallbackSpinner extends StatelessWidget {
  const _FallbackSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 50,
        height: 50,
        child: CircularProgressIndicator(
          strokeWidth: 4,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      ),
    );
  }
}
