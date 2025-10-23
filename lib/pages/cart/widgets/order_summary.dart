import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

class OrderSummary extends StatelessWidget {
  const OrderSummary({
    super.key,
    required this.subtotalInCents,
    required this.discountInCents,
    this.deliveryFeeInCents, // ✅ MUDANÇA: Agora recebe em centavos para consistência
  });

  final int subtotalInCents;
  final int discountInCents;
  final int? deliveryFeeInCents;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final fee = deliveryFeeInCents ?? 0;
    final totalInCents = subtotalInCents - discountInCents + fee;

    final labelStyle = TextStyle(fontSize: 14, color: theme.productTextColor.withOpacity(0.7));
    final valueStyle = TextStyle(fontSize: 14, color: theme.productTextColor, fontWeight: FontWeight.w600);
    final totalLabelStyle = TextStyle(fontSize: 16, color: theme.productTextColor, fontWeight: FontWeight.bold);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ TÍTULO ADICIONADO
          Text(
            'Resumo de valores',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.productTextColor),
          ),
          const SizedBox(height: 12),
          _buildLine('Subtotal', subtotalInCents.toCurrency, labelStyle, valueStyle),

          if (discountInCents > 0)
            _buildLine('Desconto', '-${discountInCents.toCurrency}', labelStyle, valueStyle.copyWith(color: Colors.green)),

          // A taxa de entrega só aparece se for maior que zero
          if (fee > 0)
            _buildLine('Taxa de entrega', fee.toCurrency, labelStyle, valueStyle),

          const Divider(height: 24),
          _buildLine('Total', totalInCents.toCurrency, totalLabelStyle, totalLabelStyle),
        ],
      ),
    );
  }

  Widget _buildLine(String label, String value, TextStyle labelStyle, TextStyle valueStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}