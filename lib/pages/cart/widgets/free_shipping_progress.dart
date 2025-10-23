import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FreeShippingProgress extends StatelessWidget {
  final double cartTotal;
  final double? threshold;

  const FreeShippingProgress({required this.cartTotal, required this.threshold, super.key});

  @override
  Widget build(BuildContext context) {
    if (threshold == null || threshold! <= 0) return const SizedBox();

    final progress = (cartTotal / threshold!).clamp(0.0, 1.0);
    final remaining = (threshold! - cartTotal).clamp(0.0, threshold!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cartTotal >= threshold!
              ? 'Você ganhou frete grátis!'
              : 'Faltam R\$${remaining.toStringAsFixed(2)} para frete grátis',
          style: TextStyle(
            color: cartTotal >= threshold! ? Colors.green : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            color: Colors.green,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
