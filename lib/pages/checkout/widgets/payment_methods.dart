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
    // Filtra apenas os grupos que têm métodos de pagamento disponíveis
    final activeGroups = widget.paymentGroups
        .where((group) => group.categories.any((cat) => cat.methods.isNotEmpty))
        .toList();

    return DefaultTabController(
      length: activeGroups.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Escolha o Pagamento'),
          bottom: TabBar(
            tabs: activeGroups.map((group) => Tab(text: group.name)).toList(),
          ),
        ),
        body: TabBarView(
          children: activeGroups.map((group) {
            return _buildSelectionListForGroup(group);
          }).toList(),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: DsPrimaryButton(
            // O botão só fica ativo se um método foi selecionado
            onPressed: _selectedMethod == null
                ? null
                : () {
              // Retorna o método selecionado para a tela anterior (checkout)
              Navigator.pop(context, _selectedMethod);
            },
            label: 'Confirmar',
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionListForGroup(PaymentMethodGroup group) {
    return ListView.builder(
      itemCount: group.categories.length,
      itemBuilder: (context, index) {
        final category = group.categories[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.categories.length > 1) // Só mostra o título da categoria se houver mais de uma
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            // Gera a lista de métodos de pagamento com botões de rádio
            ...category.methods.map((method) {
              return RadioListTile<PlatformPaymentMethod>(
                title: Text(method.name),
                secondary:_buildPaymentIcon(method.iconKey),
                value: method,
                groupValue: _selectedMethod,
                onChanged: (PlatformPaymentMethod? value) {
                  setState(() {
                    _selectedMethod = value;
                  });
                },
              );
            }),
          ],
        );
      },
    );
  }

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