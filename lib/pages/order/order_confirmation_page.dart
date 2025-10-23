import 'package:flutter/material.dart';
import '../../models/order.dart';


class OrderSummaryPage extends StatelessWidget {
  final Order? order;

  const OrderSummaryPage({Key? key, this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resumo do Pedido')),
        body: const Center(child: Text('Nenhum pedido para exibir')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Resumo do Pedido')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pedido #${order!.id}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
         //   Text('Total: R\$ ${(order!.totalPrice / 100).toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: order!.products.length,
                itemBuilder: (_, index) {
                  final product = order!.products[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text('Quantidade: ${product.quantity}'),
               //     trailing: Text('R\$ ${(product.price / 100).toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            if (order!.charge != null) ...[
              const Divider(),
            //  Text('Taxa: R\$ ${(order!.charge!.amount / 100).toStringAsFixed(2)}'),
            ],
          ],
        ),
      ),
    );
  }
}
