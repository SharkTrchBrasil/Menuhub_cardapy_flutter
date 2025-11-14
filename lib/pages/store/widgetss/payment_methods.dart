// ✅ ATUALIZADO: Agora segue o padrão do Admin, usando methods diretamente (sem categories)

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/models/payment_method.dart';

class PaymentMethodsWidget extends StatelessWidget {
  final List<PaymentMethodGroup> paymentGroups;

  const PaymentMethodsWidget({super.key, required this.paymentGroups});

  @override
  Widget build(BuildContext context) {
    // ✅ ATUALIZADO: Filtra grupos que têm métodos ativos (seguindo padrão do Admin)
    final activeGroups = paymentGroups
        .where((group) => group.methods.any((method) => method.activation?.isActive == true))
        .toList();

    if (activeGroups.isEmpty) {
      return const SizedBox.shrink(); // Não mostra nada se não houver pagamentos ativos
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Formas de pagamento",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // ✅ Lista de grupos com métodos ativos (seguindo padrão do Admin - PaymentGroupView)
        ...activeGroups.map((group) => _buildPaymentGroup(context, group)),
      ],
    );
  }

  // ✅ Método que constrói um grupo de pagamento (similar ao PaymentGroupView do Admin)
  Widget _buildPaymentGroup(BuildContext context, PaymentMethodGroup group) {
    // Filtra apenas métodos ativos
    final activeMethods = group.methods
        .where((method) => method.activation?.isActive == true)
        .toList();

    if (activeMethods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título do grupo (ex: "Cartões de Crédito", "Pagamento Digital")
          // ✅ Usa title se disponível, senão usa name
          if ((group.title ?? group.name).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                group.title ?? group.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          // Lista de métodos de pagamento ativos
          ...activeMethods.map((method) => _buildPaymentMethodTile(method)),
        ],
      ),
    );
  }

  // ✅ Método que constrói um item de método de pagamento (similar ao PaymentMethodTile do Admin, mas sem edição)
  Widget _buildPaymentMethodTile(PlatformPaymentMethod method) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _buildPaymentIcon(method.iconKey),
        title: Text(
          method.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        // ✅ ENTERPRISE: Mostra taxa se houver (corrigido para usar fee_value do backend)
        subtitle: () {
          final activation = method.activation;
          if (activation == null) return null;
          
          final details = activation.details ?? {};
          final hasFee = details['has_fee'] as bool? ?? false;
          final feeType = details['fee_type'] as String?;
          final feeValue = details['fee_value'] as num?;
          
          if (hasFee && feeValue != null && feeValue > 0) {
            // ✅ ENTERPRISE: fee_value está em reais (Numeric(10, 2) no backend)
            if (feeType == 'fixed' || feeType == 'R\$' || feeType == '\$') {
              // Taxa fixa: fee_value já está em reais (ex: 5.50 para R$ 5,50)
              return Text('Taxa: R\$ ${feeValue.toStringAsFixed(2)}');
            } else if (feeType == '%' || feeType == 'percentage' || activation.feePercentage > 0) {
              // Taxa percentual: usa feePercentage do activation ou fee_value
              final percentage = activation.feePercentage > 0 
                  ? activation.feePercentage 
                  : feeValue.toDouble();
              return Text('Taxa: ${percentage.toStringAsFixed(1)}%');
            }
          }
          return null;
        }(),
      ),
    );
  }

  // ✅ Método para construir ícone do método de pagamento (seguindo padrão do Admin)
  Widget _buildPaymentIcon(String? iconKey) {
    if (iconKey != null && iconKey.isNotEmpty) {
      final String assetPath = 'assets/icons/$iconKey';
      return SizedBox(
        width: 32,
        height: 32,
        child: SvgPicture.asset(
          assetPath,
          placeholderBuilder: (context) => const Icon(Icons.credit_card, size: 24),
        ),
      );
    }
    return const Icon(Icons.payment, size: 24);
  }
}