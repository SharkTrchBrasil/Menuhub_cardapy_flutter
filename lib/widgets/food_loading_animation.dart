// lib/widgets/food_loading_animation.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget de loading animado com ícones de comida
/// Exibe ícones de comida que pulam/flutuam com animação
/// Melhora a UX durante carregamento comparado ao CircularProgressIndicator
class FoodLoadingAnimation extends StatefulWidget {
  final double size;
  final Color? primaryColor;
  final String? message;
  final bool showMessage;

  const FoodLoadingAnimation({
    super.key,
    this.size = 80,
    this.primaryColor,
    this.message,
    this.showMessage = true,
  });

  @override
  State<FoodLoadingAnimation> createState() => _FoodLoadingAnimationState();
}

class _FoodLoadingAnimationState extends State<FoodLoadingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _bounceController;
  late AnimationController _scaleController;
  late List<AnimationController> _iconControllers;
  
  // Ícones de comida para animação
  static const List<IconData> _foodIcons = [
    Icons.restaurant, // Garfo e faca
    Icons.local_pizza, // Pizza
    Icons.fastfood, // Hamburguer
    Icons.local_cafe, // Café
    Icons.icecream, // Sorvete
    Icons.ramen_dining, // Macarrão
    Icons.cake, // Bolo
    Icons.local_bar, // Bebida
  ];
  
  // Cores para os ícones
  static const List<Color> _iconColors = [
    Color(0xFFEA1D2C), // Vermelho iFood
    Color(0xFFFF6B35), // Laranja
    Color(0xFFFFD93D), // Amarelo
    Color(0xFF6BCB77), // Verde
    Color(0xFF4D96FF), // Azul
    Color(0xFFC74B50), // Rosa escuro
    Color(0xFFB83B5E), // Rosa
    Color(0xFF6A0572), // Roxo
  ];

  late int _currentIconIndex;

  @override
  void initState() {
    super.initState();
    _currentIconIndex = 0;

    // Controller de rotação do círculo
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Controller de bounce principal
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Controller de escala pulsante
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Controllers individuais para cada ícone flutuante
    _iconControllers = List.generate(5, (index) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 800 + (index * 150)),
      );
      controller.repeat(reverse: true);
      return controller;
    });

    // Troca o ícone central periodicamente
    _startIconRotation();
  }

  void _startIconRotation() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _currentIconIndex = (_currentIconIndex + 1) % _foodIcons.length;
        });
        _startIconRotation();
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _bounceController.dispose();
    _scaleController.dispose();
    for (var controller in _iconControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size * 1.8,
            height: widget.size * 1.8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Círculo de fundo pulsante
                AnimatedBuilder(
                  animation: _scaleController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 0.9 + (_scaleController.value * 0.15),
                      child: Container(
                        width: widget.size * 1.4,
                        height: widget.size * 1.4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withOpacity(0.1),
                        ),
                      ),
                    );
                  },
                ),

                // Ícones flutuantes ao redor
                ..._buildFloatingIcons(),

                // Círculo de progresso rotativo
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: SizedBox(
                        width: widget.size,
                        height: widget.size,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor.withOpacity(0.5),
                          ),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                    );
                  },
                ),

                // Ícone central animado
                AnimatedBuilder(
                  animation: _bounceController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -8 + (_bounceController.value * 16)),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          _foodIcons[_currentIconIndex],
                          key: ValueKey<int>(_currentIconIndex),
                          size: widget.size * 0.5,
                          color: _iconColors[_currentIconIndex],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          if (widget.showMessage) ...[
            const SizedBox(height: 24),
            _buildLoadingText(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFloatingIcons() {
    final List<Widget> icons = [];
    
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72) * (math.pi / 180); // Espaçar 72 graus
      final radius = widget.size * 0.9;
      final iconIndex = (i + 2) % _foodIcons.length;
      
      icons.add(
        AnimatedBuilder(
          animation: _iconControllers[i],
          builder: (context, child) {
            final bounceOffset = -4 + (_iconControllers[i].value * 8);
            final x = math.cos(angle) * radius;
            final y = math.sin(angle) * radius + bounceOffset;
            
            return Transform.translate(
              offset: Offset(x, y),
              child: Opacity(
                opacity: 0.4 + (_iconControllers[i].value * 0.3),
                child: Icon(
                  _foodIcons[iconIndex],
                  size: widget.size * 0.22,
                  color: _iconColors[iconIndex].withOpacity(0.7),
                ),
              ),
            );
          },
        ),
      );
    }
    
    return icons;
  }

  Widget _buildLoadingText() {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, child) {
        return Opacity(
          opacity: 0.6 + (_bounceController.value * 0.4),
          child: Text(
            widget.message ?? 'Carregando...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}

/// Widget de loading compacto para uso em listas/cards
class FoodLoadingCompact extends StatefulWidget {
  final double size;
  final Color? color;

  const FoodLoadingCompact({
    super.key,
    this.size = 32,
    this.color,
  });

  @override
  State<FoodLoadingCompact> createState() => _FoodLoadingCompactState();
}

class _FoodLoadingCompactState extends State<FoodLoadingCompact>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _iconIndex = 0;

  static const List<IconData> _icons = [
    Icons.restaurant,
    Icons.local_pizza,
    Icons.fastfood,
    Icons.icecream,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _startIconCycle();
  }

  void _startIconCycle() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _iconIndex = (_iconIndex + 1) % _icons.length;
        });
        _startIconCycle();
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
    final color = widget.color ?? Theme.of(context).primaryColor;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_controller.value * 0.2),
          child: Opacity(
            opacity: 0.6 + (_controller.value * 0.4),
            child: Icon(
              _icons[_iconIndex],
              size: widget.size,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

/// Widget de loading para fullscreen/splash
class FoodLoadingFullScreen extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;
  final Color? primaryColor;

  const FoodLoadingFullScreen({
    super.key,
    this.message,
    this.backgroundColor,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.white,
      child: FoodLoadingAnimation(
        size: 100,
        primaryColor: primaryColor,
        message: message ?? 'Preparando seu cardápio...',
      ),
    );
  }
}
