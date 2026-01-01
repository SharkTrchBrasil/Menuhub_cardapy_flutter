import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

/// Widget de resumo de valores do carrinho (estilo iFood)
/// 
/// Mostra:
/// - Subtotal
/// - Taxa de entrega (ou "Grátis" quando cupom FREE_DELIVERY)
/// - Cupom / Desconto (quando aplicado)
/// - Total
class OrderSummary extends StatelessWidget {
  const OrderSummary({
    super.key,
    required this.subtotalInCents,
    required this.discountInCents,
    this.deliveryFeeInCents,
    this.isFreeDelivery = false,
    this.couponCode,
  });

  final int subtotalInCents;
  final int discountInCents;
  final int? deliveryFeeInCents;
  final bool isFreeDelivery;
  final String? couponCode;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final fee = deliveryFeeInCents ?? 0;
    
    // ✅ Se tem cupom de frete grátis, não adiciona o frete no total
    final effectiveFee = isFreeDelivery ? 0 : fee;
    final totalInCents = subtotalInCents - discountInCents + effectiveFee;

    final labelStyle = TextStyle(
      fontSize: 14, 
      color: theme.productTextColor.withOpacity(0.7),
    );
    final valueStyle = TextStyle(
      fontSize: 14, 
      color: theme.productTextColor, 
      fontWeight: FontWeight.w500,
    );
    final totalLabelStyle = TextStyle(
      fontSize: 16, 
      color: theme.productTextColor, 
      fontWeight: FontWeight.bold,
    );

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
          // ✅ Título
          Text(
            'Resumo de valores',
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold, 
              color: theme.productTextColor,
            ),
          ),
          const SizedBox(height: 12),
          
          // ✅ Subtotal
          _buildLine(
            'Subtotal', 
            subtotalInCents.toCurrency, 
            labelStyle, 
            valueStyle,
          ),

          // ✅ Taxa de entrega (mostra "Grátis" quando cupom de frete grátis)
          _buildDeliveryLine(
            fee: fee,
            isFreeDelivery: isFreeDelivery,
            labelStyle: labelStyle,
            valueStyle: valueStyle,
            theme: theme,
          ),

          // ✅ Desconto do cupom (quando aplicado)
          if (discountInCents > 0)
            _buildLine(
              couponCode != null ? 'Cupom' : 'Desconto',
              '- ${discountInCents.toCurrency}',
              labelStyle,
              valueStyle.copyWith(color: Colors.green),
            ),

          const Divider(height: 24),
          
          // ✅ Total
          _buildLine(
            'Total', 
            totalInCents.toCurrency, 
            totalLabelStyle, 
            totalLabelStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildLine(
    String label, 
    String value, 
    TextStyle labelStyle, 
    TextStyle valueStyle,
  ) {
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

  /// Linha de taxa de entrega com suporte a "Grátis"
  Widget _buildDeliveryLine({
    required int fee,
    required bool isFreeDelivery,
    required TextStyle labelStyle,
    required TextStyle valueStyle,
    required dynamic theme,
  }) {
    // Não mostra a linha se não tem frete e não é grátis
    if (fee == 0 && !isFreeDelivery) {
      return const SizedBox.shrink();
    }

    String displayValue;
    TextStyle displayStyle;

    if (isFreeDelivery) {
      // ✅ Cupom de frete grátis aplicado
      displayValue = 'Grátis';
      displayStyle = valueStyle.copyWith(
        color: Colors.green,
        fontWeight: FontWeight.w600,
      );
    } else if (fee > 0) {
      // Frete normal
      displayValue = fee.toCurrency;
      displayStyle = valueStyle;
    } else {
      // Frete grátis sem cupom (promoção ou regra)
      displayValue = 'Grátis';
      displayStyle = valueStyle.copyWith(
        color: Colors.green,
        fontWeight: FontWeight.w600,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Taxa de entrega', style: labelStyle),
          Row(
            children: [
              // ✅ Mostra valor riscado quando tem frete grátis
              if (isFreeDelivery && fee > 0) ...[
                Text(
                  fee.toCurrency,
                  style: labelStyle.copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: labelStyle.color,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(displayValue, style: displayStyle),
            ],
          ),
        ],
      ),
    );
  }
}