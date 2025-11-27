import 'package:flutter/material.dart';
import 'package:totem/models/store.dart';

class StoreDetailsSidePanel extends StatefulWidget {
  final Store store;

  const StoreDetailsSidePanel({super.key, required this.store});

  static void show(BuildContext context, Store store) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar detalhes da loja',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: StoreDetailsSidePanel(store: store),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  State<StoreDetailsSidePanel> createState() => _StoreDetailsSidePanelState();
}

class _StoreDetailsSidePanelState extends State<StoreDetailsSidePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Header com botão de fechar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Sobre'),
              Tab(text: 'Horário'),
              Tab(text: 'Pagamento'),
            ],
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(),
                _buildScheduleTab(),
                _buildPaymentTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    final store = widget.store;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descrição
          if (store.description != null && store.description!.isNotEmpty) ...[
            Text(
              store.description!,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
          
          // Endereço
          const Text(
            'Endereço',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (store.street != null) ...[
            Text(
              '${store.street}, ${store.number ?? 'S/N'}${store.complement != null ? ' - ${store.complement}' : ''}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if (store.neighborhood != null)
              Text(
                store.neighborhood!,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            Text(
              '${store.city ?? ''} - ${store.state ?? ''}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if (store.zip_code != null)
              Text(
                'CEP: ${store.zip_code}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
          ],
          
          const SizedBox(height: 24),
          
          // Outras informações
          const Text(
            'Outras informações',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (store.phone.isNotEmpty)
            _buildInfoRow(Icons.phone, 'Telefone', store.phone),
          
          const SizedBox(height: 32),
          
          // Aviso
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'O MenuHub é gratuito para os usuários e todos os preços apresentados no cardápio são definidos pela própria loja.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    final hours = widget.store.hours;
    final daysOfWeek = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Horário de funcionamento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...List.generate(7, (index) {
            final dayHours = hours.where((h) => h.dayOfWeek == index).toList();
            final dayName = daysOfWeek[index];
            
            if (dayHours.isEmpty) {
              return _buildDayRow(dayName, 'Fechado', isClosed: true);
            }
            
            final hoursText = dayHours.map((h) {
              final open = _formatTimeOfDay(h.openingTime);
              final close = _formatTimeOfDay(h.closingTime);
              return '$open - $close';
            }).join(', ');
            
            return _buildDayRow(dayName, hoursText);
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentTab() {
    final paymentGroups = widget.store.paymentMethodGroups;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Formas de pagamento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (paymentGroups.isEmpty)
            const Text(
              'Nenhuma forma de pagamento cadastrada.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...paymentGroups.map((group) => _buildPaymentGroup(group)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildDayRow(String day, String hours, {bool isClosed = false}) {
    final today = DateTime.now().weekday - 1; // 0 = Segunda
    final dayIndex = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'].indexOf(day);
    final isToday = dayIndex == today;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day,
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Theme.of(context).primaryColor : Colors.black87,
              ),
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              color: isClosed ? Colors.red : Colors.black87,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentGroup(dynamic group) {
    // Traduz os nomes técnicos para nomes amigáveis
    final groupLabels = {
      'credit_cards': 'Crédito',
      'debit_cards': 'Débito',
      'digital_payments': 'Pagamentos Digitais',
      'cash_and_vouchers': 'Dinheiro e Vouchers',
      'pix': 'PIX',
    };
    
    final displayName = group.title ?? groupLabels[group.name] ?? group.name ?? 'Outros';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            displayName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (group.methods as List?)?.map<Widget>((method) {
            return Chip(
              label: Text(method.name ?? ''),
              backgroundColor: Colors.grey.shade100,
            );
          }).toList() ?? [],
        ),
      ],
    );
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

