import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/flavor_price.dart';

/// Dialog para seleção de tamanho da pizza
/// Mostra os tamanhos disponíveis e o preço mínimo de cada
class PizzaSizeSelectionDialog extends StatelessWidget {
  final Category category;
  final OptionGroup sizeGroup;
  final List<Product> availableFlavors;
  final Product? initialFlavor;
  final Function(OptionItem) onSizeSelected;

  const PizzaSizeSelectionDialog({
    super.key,
    required this.category,
    required this.sizeGroup,
    required this.availableFlavors,
    required this.onSizeSelected,
    this.initialFlavor,
  });

  /// Calcula o preço mínimo para um tamanho específico
  double _getMinPriceForSize(OptionItem size) {
    double minPrice = double.infinity;

    for (final flavor in availableFlavors) {
      for (final fp in flavor.prices) {
        if (fp.sizeOptionId == size.id && fp.price > 0) {
          final priceInReais = fp.price / 100.0;
          if (priceInReais < minPrice) {
            minPrice = priceInReais;
          }
        }
      }
    }

    return minPrice == double.infinity ? 0.0 : minPrice;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
                const Expanded(
                  child: Text(
                    'Escolha o tamanho',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balance the close button
              ],
            ),
            const SizedBox(height: 16),
            
            // Subtitle
            Text(
              category.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Size options
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sizeGroup.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final size = sizeGroup.items[index];
                  final minPrice = _getMinPriceForSize(size);

                  return InkWell(
                    onTap: () => onSizeSelected(size),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Size icon
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.local_pizza_outlined,
                              color: Theme.of(context).primaryColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Size name and description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  size.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (size.description != null && size.description!.isNotEmpty)
                                  Text(
                                    size.description!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Price
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'A partir de',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                currencyFormat.format(minPrice),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

