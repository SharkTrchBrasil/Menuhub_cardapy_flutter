import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/product.dart';

/// Widget que exibe os tamanhos de pizza como cards em grid
/// Similar ao layout do iFood: "PEQUENA (1 PEDAÇO)", "MÉDIA 2 SABORES (6 PEDAÇOS)", etc.
class PizzaSizeGridWidget extends StatelessWidget {
  final Category category;
  final OptionGroup sizeGroup;
  final List<Product> availableFlavors;
  final Function(OptionItem) onSizeSelected;

  const PizzaSizeGridWidget({
    super.key,
    required this.category,
    required this.sizeGroup,
    required this.availableFlavors,
    required this.onSizeSelected,
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
    final activeSizes = sizeGroup.items.where((s) => s.isActive).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: activeSizes.length,
      itemBuilder: (context, index) {
        final size = activeSizes[index];
        final minPrice = _getMinPriceForSize(size);
        final displayName = _buildSizeDisplayName(size);

        return InkWell(
          onTap: () => onSizeSelected(size),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'A partir de ${currencyFormat.format(minPrice)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// SliverGrid version para uso em CustomScrollView
class PizzaSizeGridSliver extends StatelessWidget {
  final Category category;
  final OptionGroup sizeGroup;
  final List<Product> availableFlavors;
  final Function(OptionItem) onSizeSelected;

  const PizzaSizeGridSliver({
    super.key,
    required this.category,
    required this.sizeGroup,
    required this.availableFlavors,
    required this.onSizeSelected,
  });

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
    final activeSizes = sizeGroup.items.where((s) => s.isActive).toList();

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final size = activeSizes[index];
          final minPrice = _getMinPriceForSize(size);
          final displayName = _buildSizeDisplayName(size);

          return InkWell(
            onTap: () => onSizeSelected(size),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A partir de ${currencyFormat.format(minPrice)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: activeSizes.length,
      ),
    );
  }
}

/// Gera o nome do tamanho com informações de sabores e pedaços
/// Ex: "MÉDIA 2 SABORES (6 PEDAÇOS)", "GRANDE (8 PEDAÇOS)", "PEQUENA (1 PEDAÇO)"
String _buildSizeDisplayName(OptionItem size) {
  final name = size.name.toUpperCase();
  final maxFlavors = size.maxFlavors ?? 1;
  
  // Monta o nome base com quantidade de sabores se > 1
  String baseName = name;
  if (maxFlavors > 1) {
    baseName = '$name $maxFlavors SABORES';
  }
  
  // Adiciona quantidade de pedaços se disponível (singular/plural)
  if (size.slices != null && size.slices! > 0) {
    final pedacoLabel = size.slices == 1 ? 'PEDAÇO' : 'PEDAÇOS';
    return '$baseName (${size.slices} $pedacoLabel)';
  }
  
  return baseName;
}

