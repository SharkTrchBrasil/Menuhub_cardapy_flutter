// lib/pages/order/widgets/order_payment_widget.dart
// ✅ Widget Pagamento - Estilo iFood
// Ícone de bandeira/método, tipo de pagamento, detalhes

import 'package:flutter/material.dart';

class OrderPaymentWidget extends StatelessWidget {
  final String paymentMethod; // CREDIT, DEBIT, PIX, CASH
  final String? paymentBrand; // Mastercard, Visa, etc
  final String paymentType; // delivery, online, pickup
  final int? changeAmountCents;
  final bool isPaid;

  const OrderPaymentWidget({
    super.key,
    required this.paymentMethod,
    this.paymentBrand,
    this.paymentType = 'delivery',
    this.changeAmountCents,
    this.isPaid = false,
  });

  String _formatPrice(int cents) {
    final value = cents / 100.0;
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final methodInfo = _getPaymentMethodInfo();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          const Text(
            'Pagamento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Linha do pagamento
          Row(
            children: [
              // Ícone do método de pagamento
              Container(
                width: 32,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: methodInfo['bgColor'] as Color?,
                ),
                child: Center(
                  child: methodInfo['widget'] as Widget? ?? Icon(
                    methodInfo['icon'] as IconData,
                    color: methodInfo['iconColor'] as Color?,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Texto do pagamento
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo + Método
                    Text(
                      (methodInfo['label'] != null && methodInfo['label'].toString().isNotEmpty)
                          ? '${_getPaymentTypeLabel()} • ${methodInfo['label']}'
                          : _getPaymentTypeLabel(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Bandeira (se aplicável)
                    if (paymentBrand != null && paymentBrand!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        paymentBrand!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    // Troco (se dinheiro)
                    if (changeAmountCents != null && changeAmountCents! > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Troco para ${_formatPrice(changeAmountCents!)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
                  // Status de pagamento
              if (isPaid && paymentMethod != 'OFFLINE_CARD')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Pago',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPaymentTypeLabel() {
    switch (paymentType.toLowerCase()) {
      case 'delivery':
        return 'Pagamento na entrega';
      case 'pickup':
        return 'Pagamento na retirada';
      case 'online':
        return 'Pagamento online';
      default:
        return 'Pagamento';
    }
  }

  Map<String, dynamic> _getPaymentMethodInfo() {
    final method = paymentMethod.toUpperCase();
    
    // OFFLINE_CARD: Pagamento na entrega com cartão, mas sem exibir "OFFLINE_CARD"
    if (method == 'OFFLINE_CARD') {
      return {
        'icon': Icons.credit_card,
        'iconColor': Colors.white,
        'bgColor': Colors.grey,
        'label': '', // Oculta o tipo conforme solicitado
        'widget': _buildCardIcon(Colors.grey),
      };
    }
    
    switch (method) {
      case 'CREDIT':
      case 'CREDIT_CARD':
        return {
          'icon': Icons.credit_card,
          'iconColor': Colors.white,
          'bgColor': Colors.orange,
          'label': 'Crédito',
          'widget': _buildCardIcon(Colors.orange),
        };
      case 'DEBIT':
      case 'DEBIT_CARD':
        return {
          'icon': Icons.credit_card,
          'iconColor': Colors.white,
          'bgColor': Colors.blue,
          'label': 'Débito',
          'widget': _buildCardIcon(Colors.blue),
        };
      case 'PIX':
        return {
          'icon': Icons.pix,
          'iconColor': Colors.teal,
          'bgColor': Colors.teal.shade50,
          'label': 'PIX',
          'widget': null,
        };
      case 'CASH':
      case 'DINHEIRO':
        return {
          'icon': Icons.attach_money,
          'iconColor': Colors.green,
          'bgColor': Colors.green.shade50,
          'label': 'Dinheiro',
          'widget': null,
        };
      default:
        return {
          'icon': Icons.payment,
          'iconColor': Colors.grey,
          'bgColor': Colors.grey.shade100,
          'label': paymentMethod,
          'widget': null,
        };
    }
  }

  Widget _buildCardIcon(Color color) {
    // Simula ícone de cartão estilo Mastercard/Visa
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        Transform.translate(
          offset: const Offset(-4, 0),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
