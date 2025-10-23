import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:totem/core/extensions.dart';

class MinOrderNotice extends StatelessWidget {
  final double minOrder;

  const MinOrderNotice({required this.minOrder, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'O pedido mínimo dessa loja é ${minOrder.toCurrency()} (sem taxa de entrega)',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
