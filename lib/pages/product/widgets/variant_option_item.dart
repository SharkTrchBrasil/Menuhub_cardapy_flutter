import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';

import '../../../helpers/enums/displaymode.dart';
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
          orElse: () => CartVariantOption(
            id: -1,
            name: '',
            price: 0,
            trackInventory: false,
            stockQuantity: 0,
            isActuallyAvailable: false,
          ),
        ).id;

        final bool isSelectedRadio = option.id == selectedOptionIdInGroup;
        
        // ✅ Se tem imagem, usa layout customizado para sabores
        if (option.imageUrl != null && option.imageUrl!.isNotEmpty) {
          return InkWell(
            onTap: () => onUpdate(1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Row(
                children: [
                  // Informações do sabor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (option.description != null && option.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            option.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 3, // ✅ IFOOD STYLE: Máximo 3 linhas para descrição
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (option.price > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+ ${option.price.toCurrency}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Imagem do sabor
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: CachedNetworkImage(
                        imageUrl: option.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey.shade200),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.local_pizza, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Radio button
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelectedRadio ? theme.primaryColor : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelectedRadio
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.primaryColor,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        }
        
        // Radio sem imagem (layout original)
        return RadioListTile<int>(
          title: Text(
            option.name.isEmpty ? 'Opção sem nome' : option.name, 
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)
          ),
          subtitle: _buildSubtitle(),
          value: option.id,
          groupValue: selectedOptionIdInGroup,
          onChanged: (value) => onUpdate(1),
          activeColor: theme.primaryColor,
          controlAffinity: ListTileControlAffinity.trailing,
        );

      case UIDisplayMode.MULTIPLE:
        // ✅ IFOOD STYLE: Usa +/- para permitir múltiplas unidades da mesma opção
        // Usa maxSelectedOptions como limite quando maxTotalQuantity é null
        final effectiveMaxTotal = variant.maxTotalQuantity ?? variant.maxSelectedOptions;
        final bool canIncrementMultiple = variant.totalQuantitySelected < effectiveMaxTotal;
        
        // Se ainda não selecionou nenhum, mostra apenas o botão +
        if (!isSelected) {
          trailingWidget = IconButton(
            icon: Icon(Icons.add, color: theme.primaryColor, size: 28),
            onPressed: canIncrementMultiple ? () => onUpdate(1) : null,
          );
          onTapAction = canIncrementMultiple ? () => onUpdate(1) : null;
        } else {
          // Já selecionou, mostra -/quantidade/+
          trailingWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: theme.primaryColor, size: 24),
                onPressed: () => onUpdate(option.quantity - 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  option.quantity.toString(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle, color: canIncrementMultiple ? theme.primaryColor : Colors.grey.shade300, size: 24),
                onPressed: canIncrementMultiple ? () => onUpdate(option.quantity + 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          );
        }
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
                  Text(
                    option.name.isEmpty ? 'Opção sem nome' : option.name, 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)
                  ),
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
            child: Text(
              option.description!, 
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              maxLines: 3, // ✅ Consistência com o layout SINGLE
              overflow: TextOverflow.ellipsis,
            ),
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