import 'package:flutter/material.dart';


class PaymentMethodsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> methods;

  const PaymentMethodsWidget({super.key, required this.methods});

  @override
  Widget build(BuildContext context) {
    final activeMethods = methods.where((m) => m['is_active'] == true).toList();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.payment),
            title: Text("Formas de pagamento"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: activeMethods.map((method) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                      "https://flutterpro6bucket.s3.amazonaws.com/${method['custom_icon']}",
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      method['custom_name'],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
