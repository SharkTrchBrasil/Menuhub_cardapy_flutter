import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/widgets/ds_primary_button.dart'; // Importe seus modelos atualizados

class PaymentMethodSelectionList extends StatefulWidget {
  final List<PaymentMethodGroup> paymentGroups;
  final PlatformPaymentMethod? initialSelectedMethod;

  const PaymentMethodSelectionList({
    super.key,
    required this.paymentGroups,
    this.initialSelectedMethod,
  });

  @override
  State<PaymentMethodSelectionList> createState() => _PaymentMethodSelectionListState();
}

class _PaymentMethodSelectionListState extends State<PaymentMethodSelectionList> {
  // Guarda o método de pagamento selecionado
  PlatformPaymentMethod? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialSelectedMethod;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CORREÇÃO: Filtra grupos que têm métodos ativos e disponíveis
    // ✅ Os grupos já vêm filtrados por tipo de entrega do checkout_page
    final activeGroups = widget.paymentGroups
        .where((group) => group.methods.any((method) => method.activation?.isActive == true))
        .toList();

    // ✅ CORREÇÃO: Layout mobile-first em coluna única (sem TabBar)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha o Pagamento'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: activeGroups.length,
              itemBuilder: (context, groupIndex) {
                final group = activeGroups[groupIndex];
                return _buildGroupCard(group, groupIndex == activeGroups.length - 1);
              },
            ),
          ),
          // ✅ Botão de confirmação fixo no rodapé
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: DsPrimaryButton(
              onPressed: _selectedMethod == null
                  ? null
                  : () {
                Navigator.pop(context, _selectedMethod);
              },
              label: 'Confirmar',
            ),
          ),
        ],
      ),
    );
  }
  
  /// ✅ NOVO: Constrói card de grupo com nome em cima e métodos abaixo
  Widget _buildGroupCard(PaymentMethodGroup group, bool isLast) {
    final activeMethods = group.methods
        .where((method) => method.activation?.isActive == true)
        .toList();
    
    if (activeMethods.isEmpty) return const SizedBox.shrink();
    
    // ✅ SEPARA: Métodos genéricos e flags
    final genericMethods = <PlatformPaymentMethod>[];
    final flags = <PlatformPaymentMethod>[];
    
    for (final method in activeMethods) {
      final details = method.activation?.details ?? {};
      final isFlag = details['is_flag'] as bool? ?? false;
      
      if (isFlag) {
        flags.add(method);
      } else {
        genericMethods.add(method);
      }
    }
    
    // ✅ AGRUPA: Flags por método pai (usando flag_type e método_type)
    final flagsByParent = <PlatformPaymentMethod, List<PlatformPaymentMethod>>{};
    
    for (final flag in flags) {
      final details = flag.activation?.details ?? {};
      final flagType = details['flag_type'] as String? ?? '';
      
      // ✅ Encontra o método pai correspondente usando flag_type e método_type
      PlatformPaymentMethod? parentMethod;
      
      for (final method in genericMethods) {
        final methodNameLower = method.name.toLowerCase();
        final methodType = method.method_type.toUpperCase();
        
        // ✅ Correspondência flexível baseada em flag_type e nome/tipo do método
        bool matches = false;
        if (flagType == 'credit' && 
            (methodNameLower.contains('crédito') || methodNameLower.contains('credito') || 
             methodType.contains('CREDIT'))) {
          matches = true;
        } else if (flagType == 'debit' && 
                   (methodNameLower.contains('débito') || methodNameLower.contains('debito') || 
                    methodType.contains('DEBIT'))) {
          matches = true;
        } else if (flagType == 'vr' && 
                   (methodNameLower.contains('vale refeição') || methodNameLower.contains('vale refeicao') || 
                    methodNameLower.contains('vale refeiçao') || methodType.contains('VOUCHER_VR'))) {
          matches = true;
        } else if (flagType == 'va' && 
                   (methodNameLower.contains('vale alimentação') || methodNameLower.contains('vale alimentacao') || 
                    methodNameLower.contains('vale alimentaçao') || methodType.contains('VOUCHER_VA'))) {
          matches = true;
        } else if (flagType == 'pix' && 
                   (methodNameLower == 'pix' || methodType.contains('PIX'))) {
          matches = true;
        }
        
        if (matches) {
          parentMethod = method;
          break;
        }
      }
      
      if (parentMethod != null) {
        flagsByParent.putIfAbsent(parentMethod, () => []).add(flag);
      }
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Nome do grupo em cima
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              group.title ?? group.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          // ✅ Métodos genéricos e suas flags abaixo em coluna
          ...genericMethods.map((method) {
            final methodFlags = flagsByParent[method] ?? [];
            return _buildMethodItem(method, flags: methodFlags);
          }).toList(),
        ],
      ),
    );
  }
  
  /// ✅ NOVO: Constrói item de método com bandeiras (se houver)
  Widget _buildMethodItem(PlatformPaymentMethod method, {List<PlatformPaymentMethod> flags = const []}) {
    final activation = method.activation;
    String? feeText;
    
    // ✅ Calcula taxa se houver
    if (activation != null) {
      final details = activation.details ?? {};
      final hasFee = details['has_fee'] as bool? ?? false;
      final feeType = details['fee_type'] as String?;
      final feeValue = details['fee_value'] as num?;
      
      if (hasFee && feeValue != null && feeValue > 0) {
        if (feeType == 'fixed' || feeType == 'R\$' || feeType == '\$') {
          feeText = 'Taxa: R\$ ${feeValue.toStringAsFixed(2)}';
        } else if (feeType == '%' || feeType == 'percentage' || activation.feePercentage > 0) {
          final percentage = activation.feePercentage > 0 
              ? activation.feePercentage 
              : feeValue.toDouble();
          feeText = 'Taxa: ${percentage.toStringAsFixed(1)}%';
        }
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Método principal
        RadioListTile<PlatformPaymentMethod>(
          title: Text(method.name),
          subtitle: feeText != null ? Text(feeText) : null,
          secondary: _buildPaymentIcon(method.iconKey),
          value: method,
          groupValue: _selectedMethod,
          onChanged: (PlatformPaymentMethod? value) {
            setState(() {
              _selectedMethod = value;
            });
          },
        ),
        // ✅ Flags (bandeiras) indentadas abaixo do método
        if (flags.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 56.0, right: 16.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: flags.map((flag) {
                return _buildFlagItem(flag);
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
  
  /// ✅ NOVO: Constrói item de flag (bandeira) indentado
  Widget _buildFlagItem(PlatformPaymentMethod flag) {
    final activation = flag.activation;
    String? feeText;
    
    // ✅ Calcula taxa se houver (flags herdam taxa do método pai)
    if (activation != null) {
      final details = activation.details ?? {};
      final hasFee = details['has_fee'] as bool? ?? false;
      final feeType = details['fee_type'] as String?;
      final feeValue = details['fee_value'] as num?;
      
      if (hasFee && feeValue != null && feeValue > 0) {
        if (feeType == 'fixed' || feeType == 'R\$' || feeType == '\$') {
          feeText = 'Taxa: R\$ ${feeValue.toStringAsFixed(2)}';
        } else if (feeType == '%' || feeType == 'percentage' || activation.feePercentage > 0) {
          final percentage = activation.feePercentage > 0 
              ? activation.feePercentage 
              : feeValue.toDouble();
          feeText = 'Taxa: ${percentage.toStringAsFixed(1)}%';
        }
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RadioListTile<PlatformPaymentMethod>(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          flag.name,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: feeText != null ? Text(feeText, style: const TextStyle(fontSize: 12)) : null,
        secondary: _buildPaymentIcon(flag.iconKey),
        value: flag,
        groupValue: _selectedMethod,
        onChanged: (PlatformPaymentMethod? value) {
          setState(() {
            _selectedMethod = value;
          });
        },
      ),
    );
  }

  // ✅ REMOVIDO: _buildSelectionListForGroup não é mais necessário
  // ✅ Substituído por _buildGroupCard e _buildMethodItem acima

  Widget _buildPaymentIcon(String? iconKey) {

    if (iconKey != null && iconKey.isNotEmpty) {
      final String assetPath = 'assets/icons/$iconKey';
      return SizedBox(
        width: 24,
        height: 24,
        child: SvgPicture.asset(
          assetPath,

          placeholderBuilder: (context) => Icon(Icons.credit_card, size: 24, ),
        ),
      );
    }
    return Icon(Icons.payment, size: 24);
  }
}