import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';

import '../../../models/cart_variant.dart';
import '../../../models/cart_variant_option.dart';
import '../../../models/variant_option.dart';
import '../../../themes/ds_theme_switcher.dart';

/// WIDGET DE OPÇÃO COM A LÓGICA DE "EM FALTA"
class VariantOptionItem extends StatelessWidget {
  const VariantOptionItem({
    required this.variant,
    required this.option,
    required this.onUpdate,
  });

  final CartVariant variant;
  final CartVariantOption option;
  final Function(int newQuantity) onUpdate;

  @override
  Widget build(BuildContext context) {
    // ✅ VERIFICAÇÃO PRINCIPAL: Se o item não estiver disponível, mostra o layout de "EM FALTA".
    if (!option.isActuallyAvailable) {
      return _buildOutOfStockItem(context);
    }

    // Se estiver disponível, continua com a lógica normal de construção do item interativo.
    return _buildAvailableItem(context);
  }

  // ✅ NOVO WIDGET: Constrói o layout para itens indisponíveis
  Widget _buildOutOfStockItem(BuildContext context) {
    final disabledColor = Colors.grey.shade400;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Imagem (se existir) com um filtro cinza para indicar indisponibilidade
          if (option.imageUrl != null && option.imageUrl!.isNotEmpty)
            ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
              child: SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CachedNetworkImage(
                    imageUrl: option.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          if (option.imageUrl != null && option.imageUrl!.isNotEmpty)
            const SizedBox(width: 16),

          // Coluna de Texto com cores apagadas
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: disabledColor, decoration: TextDecoration.lineThrough)),
                if (option.description != null && option.description!.isNotEmpty)
                  Text(option.description!, style: TextStyle(color: disabledColor)),
                if (option.price > 0) ...[
                  const SizedBox(height: 2),
                  Text('+ ${option.price.toCurrency}', style: TextStyle(color: disabledColor, fontSize: 14)),
                ]
              ],
            ),
          ),

          // O rótulo "EM FALTA" no lugar do controle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'EM FALTA',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ LÓGICA ANTIGA MOVIDA PARA ESTE WIDGET para organização
  Widget _buildAvailableItem(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final bool isSelected = option.quantity > 0;
    VoidCallback? onTapAction;
    Widget trailingWidget;

    switch (variant.uiDisplayMode) {
      case UIDisplayMode.QUANTITY:
        final bool canIncrement = variant.maxTotalQuantity == null ||
            variant.totalQuantitySelected < variant.maxTotalQuantity!;
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: isSelected ? theme.primaryColor : Colors.grey.shade300),
              onPressed: isSelected ? () => onUpdate(option.quantity - 1) : null,
            ),
            Text(option.quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(Icons.add_circle, color: canIncrement ? theme.primaryColor : Colors.grey.shade300),
              onPressed: canIncrement ? () => onUpdate(option.quantity + 1) : null,
            ),
          ],
        );
        break;

      case UIDisplayMode.SINGLE:
        final selectedOptionIdInGroup = variant.cartOptions.firstWhere(
              (o) => o.quantity > 0,
          // ✅ PREENCHIMENTO CORRETO AQUI
          orElse: () => CartVariantOption(
            id: -1, // O valor mais importante: um ID que nunca existirá
            name: '', // Apenas para preencher, não será mostrado
            price: 0, // Apenas para preencher
            trackInventory: false, // Valor padrão
            stockQuantity: 0, // Valor padrão
            isActuallyAvailable: false, // Valor padrão
          ),
        ).id;



        return RadioListTile<int>(
          title: Text(option.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: _buildSubtitle(),
          value: option.id,
          groupValue: selectedOptionIdInGroup,
          onChanged: (value) => onUpdate(1),
          activeColor: theme.primaryColor,
          controlAffinity: ListTileControlAffinity.trailing,
        );

      case UIDisplayMode.MULTIPLE:
        trailingWidget = Checkbox(
          value: isSelected,
          onChanged: (bool? selected) => onUpdate(selected == true ? 1 : 0),
          activeColor: theme.primaryColor,
        );
        onTapAction = () => onUpdate(isSelected ? 0 : 1);
        break;

      default:
        trailingWidget = const SizedBox.shrink();
    }

    return InkWell(
      onTap: onTapAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (option.imageUrl != null && option.imageUrl!.isNotEmpty)
              SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CachedNetworkImage(
                    imageUrl: option.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey.shade200),
                    errorWidget: (context, url, error) => const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            if (option.imageUrl != null && option.imageUrl!.isNotEmpty)
              const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  if (_buildSubtitle() != null) _buildSubtitle()!,
                ],
              ),
            ),
            trailingWidget,
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para não repetir a lógica do subtítulo
  Widget? _buildSubtitle() {
    final hasDescription = option.description != null && option.description!.isNotEmpty;
    final hasPrice = option.price > 0;

    if (!hasDescription && !hasPrice) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDescription)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(option.description!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
        if (hasPrice)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text('+ ${option.price.toCurrency}', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          ),
      ],
    );
  }
}