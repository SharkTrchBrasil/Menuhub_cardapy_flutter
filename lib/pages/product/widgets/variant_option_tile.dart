import 'package:flutter/material.dart';


class VariantOptionTile extends StatelessWidget {
  final String name;
  final String? description;
  final String priceText;
  final bool selected;
  final int quantity;
  final bool canRepeat;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const VariantOptionTile({
    super.key,
    required this.name,
    this.description,
    required this.priceText,
    this.selected = false,
    this.quantity = 0,
    this.canRepeat = false,
    this.onSelectToggle,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox ou espaço vazio
            Checkbox(
              value: selected,
              onChanged: (_) => onSelectToggle?.call(),
            ),
            const SizedBox(width: 8),
            // Nome e descrição
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (description != null && description!.isNotEmpty)
                    Text(description!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(priceText, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            // Botões + e -
            if (canRepeat)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: quantity > 0 ? onDecrement : null,
                  ),
                  Text(quantity.toString()),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: onIncrement,
                  ),
                ],
              )
          ],
        ),
        const Divider(height: 16),
      ],
    );
  }
}
