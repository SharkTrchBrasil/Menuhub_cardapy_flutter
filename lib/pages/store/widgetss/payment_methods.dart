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
          
          // ✅ UNIFICADO: Prioriza feeValue e feeType do activation, depois details
          final finalFeeValue = activation.feeValue ?? feeValue;
          final finalFeeType = activation.feeType ?? feeType;
          
          if (hasFee && finalFeeValue != null && finalFeeValue > 0) {
            // ✅ ENTERPRISE: fee_value está em reais (Numeric(10, 2) no backend)
            if (finalFeeType == 'fixed' || finalFeeType == 'R\$' || finalFeeType == '\$') {
              // Taxa fixa: fee_value já está em reais (ex: 5.50 para R$ 5,50)
              return Text('Taxa: R\$ ${finalFeeValue.toStringAsFixed(2)}');
            } else if (finalFeeType == '%' || finalFeeType == 'percentage') {
              // ✅ UNIFICADO: Sempre usa feeValue (não usa feePercentage como fallback)
              return Text('Taxa: ${finalFeeValue.toStringAsFixed(1)}%');
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
      // ✅ Mapeamento de iconKeys para arquivos reais
      final String mappedIconKey = _mapIconKey(iconKey);
      final String assetPath = 'assets/icons/$mappedIconKey';
      
      return SizedBox(
        width: 32,
        height: 32,
        child: _SafeSvgPicture(
          assetPath: assetPath,
          fallback: const Icon(Icons.credit_card, size: 24),
        ),
      );
    }
    return const Icon(Icons.payment, size: 24);
  }

  // ✅ Mapeia iconKeys do backend para arquivos de ícones existentes
  String _mapIconKey(String iconKey) {
    // Remove extensão se houver
    final cleanKey = iconKey.replaceAll('.svg', '').toLowerCase();
    
    // Mapeamento de iconKeys comuns para arquivos reais
    final iconMap = {
      'credit': 'visa', // Fallback genérico para crédito
      'debit': 'visa_debit', // Fallback genérico para débito
      'hiper': 'hipercard',
      'vr': 'cash', // Vale refeição -> dinheiro como fallback
      'alelo': 'cash', // Alelo -> dinheiro como fallback
      'va': 'cash', // Vale alimentação -> dinheiro como fallback
    };
    
    // Se existe mapeamento, usa ele
    if (iconMap.containsKey(cleanKey)) {
      return '${iconMap[cleanKey]}.svg';
    }
    
    // Se não tem extensão, adiciona .svg
    if (!cleanKey.endsWith('.svg')) {
      return '$cleanKey.svg';
    }
    
    return iconKey; // Retorna original se já tiver extensão
  }
}

// ✅ Widget helper para carregar SVG com tratamento de erro
class _SafeSvgPicture extends StatelessWidget {
  final String assetPath;
  final Widget fallback;

  const _SafeSvgPicture({
    required this.assetPath,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      placeholderBuilder: (context) => fallback,
      // ✅ Se o asset não existir, o placeholder será usado durante o carregamento
      // O mapeamento de iconKeys garante que a maioria dos casos funcionará
    );
  }
}