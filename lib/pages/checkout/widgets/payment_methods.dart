import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/models/store.dart';
import 'package:totem/pages/checkout/widgets/mercadopago_payment_widget.dart';
import 'package:totem/widgets/ds_button.dart'; // Importe seus modelos atualizados

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

    // ✅ Layout Unificado com Tabs (Inspirado no iFood)
    return Scaffold(
      backgroundColor: Colors.white, // Fundo branco conforme solicitado
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Escolha o Pagamento',
          style: TextStyle(
            color: Color(0xFF3F3E3E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFEA1D2C),
              indicatorWeight: 3,
              labelColor: const Color(0xFFEA1D2C),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Pagar na entrega'),
                Tab(text: 'Pagar pelo app'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ✅ Tab 1: Pagamento na Entrega
                _buildOfflinePaymentTab(),
                // ✅ Tab 2: Pagamento pelo App (Online)
                _buildOnlinePaymentTab(context),
              ],
            ),
          ),
        ],
      ),
      // ✅ Botão de confirmação movido para bottomNavigationBar (Estilo iFood limpo)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DsButton(
            onPressed: _selectedMethod == null
                ? null
                : () {
              Navigator.pop(context, _selectedMethod);
            },
            label: 'Confirmar',
            minimumSize: const Size(double.infinity, 56), // ✅ Botão bem grande (altura 56)
          ),
        ),
      ),
    );
  }

  /// ✅ NOVO: Aba de pagamento na entrega (estilo flat list com cards)
  Widget _buildOfflinePaymentTab() {
    // Coleta todos os métodos offline ativos em uma lista única
    // ✅ ATUALIZADO: Preserva informação do grupo para adicionar prefixo Crédito/Débito
    final allMethods = <PlatformPaymentMethod>[];
    for (final group in offlineGroups) {
      final groupName = group.name.toLowerCase();
      final isCredit = groupName.contains('credit');
      final isDebit = groupName.contains('debit');
      
      for (final m in group.methods.where((m) => m.activation?.isActive == true)) {
        final isFlag = m.activation?.details?['is_flag'] == true;
        
        // ✅ Se for flag de cartão, adiciona prefixo Crédito/Débito ao nome
        if (isFlag && (isCredit || isDebit)) {
          final prefix = isCredit ? 'Crédito' : 'Débito';
          allMethods.add(m.copyWith(name: '$prefix ${m.name}'));
        } else {
          allMethods.add(m);
        }
      }
    }

    // ✅ ORGANIZAÇÃO POR PRIORIDADE:
    // 1. Dinheiro e PIX (Topo da lista)
    // 2. Bandeiras de Cartão (Flags: Visa, Master, etc)
    // 3. Outros (Vales, etc)
    final priorityMethods = <PlatformPaymentMethod>[];
    final cardFlags = <PlatformPaymentMethod>[];
    final otherMethods = <PlatformPaymentMethod>[];

    for (final m in allMethods) {
      final name = m.name.toLowerCase();
      final isFlag = m.activation?.details?['is_flag'] == true;
      
      if (name.contains('dinheiro') || name.contains('pix')) {
        priorityMethods.add(m);
      } else if (isFlag) {
        cardFlags.add(m);
      } else {
        // Esconde métodos genéricos (ex: "Crédito") se houver flags específicas
        bool isGenericCard = name.contains('crédito') || name.contains('credito') || 
                            name.contains('débito') || name.contains('debito');
        
        // Se for um "Vale" ou algo do tipo, entra em outros
        if (!isGenericCard) {
          otherMethods.add(m);
        }
      }
    }

    final displayList = [...priorityMethods, ...cardFlags, ...otherMethods];

    if (displayList.isEmpty) {
      return const Center(
        child: Text('Nenhuma forma de pagamento disponível na entrega.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final method = displayList[index];
        return _buildPaymentMethodCard(method);
      },
    );
  }

  /// ✅ NOVO: Item de pagamento estilo card premium
  Widget _buildPaymentMethodCard(PlatformPaymentMethod method) {
    // Consideramos selecionado se ID e Nome batem
    bool isSelected = _selectedMethod?.id == method.id && _selectedMethod?.name == method.name;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFFEA1D2C) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Ícone lateral
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildPaymentIcon(method.iconKey),
              ),
              const SizedBox(width: 16),
              // Nome do método
              Expanded(
                child: Text(
                  method.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3F3E3E),
                  ),
                ),
              ),
              // Radio customizado
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEA1D2C) : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEA1D2C),
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ✅ Os itens são agora construídos via _buildPaymentMethodCard para layout flat

  /// ✅ TAB 2: Pagamento pelo App (Online)
  Widget _buildOnlinePaymentTab(BuildContext context) {
    if (onlineGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons. smartphone, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Pagamento pelo app não disponível',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Em breve você poderá pagar diretamente por aqui!',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: MercadoPagoPaymentWidget(
        store: widget.store,
        orderTotal: widget.orderTotal,
        onPaymentCreated: (paymentId, paymentData) {
          final onlineMethod = PlatformPaymentMethod(
            id: 0,
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
      'hipercard': 'hipercard',
      'master': 'mastercard',
      'mastercard': 'mastercard',
      'visa': 'visa',
      'elo': 'elo',
      'amex': 'amex',
      'american_express': 'amex',
      'pix': 'pix',
      'cash': 'cash',
      'dinheiro': 'cash',
      'sodexo': 'sodexo',
      'alelo': 'alelo',
      'ticket': 'ticket',
      'vr': 'vr',
      'diners': 'diners',
      'discover': 'discover',
      'va': 'ticket', // Vale alimentação -> Ticket como fallback
      'vr_refeicao': 'vr',
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