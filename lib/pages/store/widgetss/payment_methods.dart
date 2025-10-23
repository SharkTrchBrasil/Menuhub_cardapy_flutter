// Em: seu arquivo de widget

import 'package:flutter/material.dart';
import 'package:totem/models/payment_method.dart'; // Importe seus novos modelos

class PaymentMethodsWidget extends StatelessWidget {
  final List<PaymentMethodGroup> paymentGroups;

  const PaymentMethodsWidget({super.key, required this.paymentGroups});

  @override
  Widget build(BuildContext context) {
    // Filtra apenas os grupos que têm categorias e métodos ativos
    final activeGroups = paymentGroups
        .where((group) => group.categories.any((cat) => cat.methods.isNotEmpty))
        .toList();

    if (activeGroups.isEmpty) {
      return const SizedBox.shrink(); // Não mostra nada se não houver pagamentos
    }

    return DefaultTabController(
      length: activeGroups.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Formas de pagamento",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TabBar(
            isScrollable: true, // Permite rolar se tiver muitas abas
            tabs: activeGroups.map((group) => Tab(text: group.name)).toList(),
            // Estilização (ajuste conforme seu tema)
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
          ),
          SizedBox(
            // Altura para o conteúdo das abas
            height: 150, // Ajuste a altura conforme necessário
            child: TabBarView(
              children: activeGroups.map((group) {
                // Widget para exibir o conteúdo de cada grupo
                return _buildGroupContent(group);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupContent(PaymentMethodGroup group) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      children: group.categories.map((category) {
        if (category.methods.isEmpty) {
          return const SizedBox.shrink();
        }
        // Usamos ExpansionTile para agrupar por categoria (ex: Cartão de Crédito)
        return ExpansionTile(
          title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          initiallyExpanded: true, // Deixa a categoria aberta por padrão
          children: category.methods.map((method) {
            return ListTile(
              leading: Image.asset(
                'assets/icons/${method.iconKey ?? 'wallet.png'}',
                width: 28,
                height: 28,
              ),
              title: Text(method.name),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}