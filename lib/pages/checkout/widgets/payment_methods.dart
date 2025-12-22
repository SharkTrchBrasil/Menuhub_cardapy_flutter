import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/models/store.dart';
import 'package:totem/pages/checkout/widgets/mercadopago_payment_widget.dart';
import 'package:totem/widgets/ds_primary_button.dart'; // Importe seus modelos atualizados

class PaymentMethodSelectionList extends StatefulWidget {
  final List<PaymentMethodGroup> paymentGroups;
  final PlatformPaymentMethod? initialSelectedMethod;
  final double orderTotal; // ✅ NOVO: Total do pedido para pagamento online
  final Store store; // ✅ NOVO: Loja para pagamento online

  const PaymentMethodSelectionList({
    super.key,
    required this.paymentGroups,
    this.initialSelectedMethod,
    required this.orderTotal, // ✅ NOVO
    required this.store, // ✅ NOVO
  });

  @override
  State<PaymentMethodSelectionList> createState() => _PaymentMethodSelectionListState();
}

class _PaymentMethodSelectionListState extends State<PaymentMethodSelectionList> with SingleTickerProviderStateMixin {
  // Guarda o método de pagamento selecionado
  PlatformPaymentMethod? _selectedMethod;
  late TabController _tabController;
  
  // ✅ NOVO: Variáveis de instância para grupos (acessíveis em todos os métodos)
  late final List<PaymentMethodGroup> offlineGroups;
  late final List<PaymentMethodGroup> onlineGroups;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialSelectedMethod;
    _tabController = TabController(length: 2, vsync: this);
    
    // ✅ NOVO: Separa métodos em "Pagamento na Entrega" e "Pagamento Online"
    final activeGroups = widget.paymentGroups
        .where((group) => group.methods.any((method) => method.activation?.isActive == true))
        .toList();

    // ✅ Separa métodos offline (na entrega) e online (Mercado Pago)
    final offline = <PaymentMethodGroup>[];
    final online = <PaymentMethodGroup>[];
    
    for (final group in activeGroups) {
      final hasOnline = group.methods.any((m) => 
        m.method_type == 'ONLINE' || 
        (m.activation?.details?['is_online'] == true)
      );
      
      if (hasOnline) {
        online.add(group);
      } else {
        offline.add(group);
      }
    }
    
    offlineGroups = offline;
    onlineGroups = online;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // ✅ Se não há métodos online, mostra apenas métodos offline sem tabs
    if (onlineGroups.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Escolha o Pagamento'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: offlineGroups.length,
                itemBuilder: (context, groupIndex) {
                  final group = offlineGroups[groupIndex];
                  return _buildGroupCard(group, groupIndex == offlineGroups.length - 1);
                },
              ),
            ),
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

    // ✅ Layout com tabs (Pagamento na Entrega | Pagamento Online)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha o Pagamento'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pagamento na Entrega'),
            Tab(text: 'Pagamento Online'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ✅ Tab 1: Pagamento na Entrega
                ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: offlineGroups.length,
                  itemBuilder: (context, groupIndex) {
                    final group = offlineGroups[groupIndex];
                    return _buildGroupCard(group, groupIndex == offlineGroups.length - 1);
                  },
                ),
                // ✅ Tab 2: Pagamento Online (Mercado Pago)
                _buildOnlinePaymentTab(context),
              ],
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
  
  /// ✅ NOVO: Constrói tab de pagamento online com Mercado Pago
  Widget _buildOnlinePaymentTab(BuildContext context) {
    // ✅ Sempre mostra o widget de Mercado Pago (backend valida se está conectado)
    // Se a loja não estiver conectada, o widget mostrará erro ao tentar criar pagamento
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: MercadoPagoPaymentWidget(
        store: widget.store,
        orderTotal: widget.orderTotal,
        onPaymentCreated: (paymentId, paymentData) {
          // ✅ Quando pagamento é criado, cria um método de pagamento online virtual
          final onlineMethod = PlatformPaymentMethod(
            id: 0, // ID temporário (não é um método real do backend)
            name: paymentData['payment_method_id'] == 'pix' 
                ? 'PIX (Pelo App)' 
                : 'Cartão de Crédito (Pelo App)',
            method_type: 'ONLINE',
            iconKey: paymentData['payment_method_id'] == 'pix' ? 'pix' : 'credit_card',
            activation: StorePaymentMethodActivation(
              id: 0,
              isActive: true,
              feePercentage: 0.0,
              details: {
                'mercadopago_payment_id': paymentId,
                'payment_method_id': paymentData['payment_method_id'],
                'flag_type': paymentData['payment_method_id'],
                'is_online': true,
              },
              isForDelivery: true,
              isForPickup: true,
              isForInStore: true,
            ),
          );
          
          setState(() {
            _selectedMethod = onlineMethod;
          });
          
          // ✅ Mostra mensagem de sucesso
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pagamento criado! Clique em "Confirmar" para finalizar.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        },
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
      
      // ✅ UNIFICADO: Prioriza feeValue e feeType do activation, depois details
      final finalFeeValue = activation.feeValue ?? feeValue;
      final finalFeeType = activation.feeType ?? feeType;
      
      if (hasFee && finalFeeValue != null && finalFeeValue > 0) {
        if (finalFeeType == 'fixed' || finalFeeType == 'R\$' || finalFeeType == '\$') {
          feeText = 'Taxa: R\$ ${finalFeeValue.toStringAsFixed(2)}';
        } else if (finalFeeType == '%' || finalFeeType == 'percentage') {
          // ✅ UNIFICADO: Sempre usa feeValue (não usa feePercentage como fallback)
          feeText = 'Taxa: ${finalFeeValue.toStringAsFixed(1)}%';
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
      
      // ✅ UNIFICADO: Prioriza feeValue e feeType do activation, depois details
      final finalFeeValue = activation.feeValue ?? feeValue;
      final finalFeeType = activation.feeType ?? feeType;
      
      if (hasFee && finalFeeValue != null && finalFeeValue > 0) {
        if (finalFeeType == 'fixed' || finalFeeType == 'R\$' || finalFeeType == '\$') {
          feeText = 'Taxa: R\$ ${finalFeeValue.toStringAsFixed(2)}';
        } else if (finalFeeType == '%' || finalFeeType == 'percentage') {
          // ✅ UNIFICADO: Sempre usa feeValue (não usa feePercentage como fallback)
          feeText = 'Taxa: ${finalFeeValue.toStringAsFixed(1)}%';
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
      // ✅ Mapeamento de iconKeys para arquivos reais
      final String mappedIconKey = _mapIconKey(iconKey);
      final String assetPath = 'assets/icons/$mappedIconKey';
      
      return SizedBox(
        width: 24,
        height: 24,
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
      // ✅ Se o asset não existir, o placeholder será usado
    );
  }
}