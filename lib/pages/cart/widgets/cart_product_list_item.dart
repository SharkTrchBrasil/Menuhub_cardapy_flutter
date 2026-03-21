import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/themes/ds_theme.dart';
import '../../../helpers/navigation_helper.dart';
import '../../../models/cart_item.dart';
import '../../../models/option_group.dart';
import '../../../models/update_cart_payload.dart';
import '../../../themes/ds_theme_switcher.dart';
import 'cart_quantity_control.dart';

class CartItemListItem extends StatelessWidget {
  final CartItem item;

  const CartItemListItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    UpdateCartItemPayload? createUpdatePayload(int newQuantity) {
      final firstCategoryLink = item.product.categoryLinks.firstOrNull;
      if (firstCategoryLink == null) return null;
      if (item.id <= 0) return null;

      return UpdateCartItemPayload(
        cartItemId: item.id,
        productId: item.product.id!,
        categoryId: firstCategoryLink.categoryId,
        quantity: newQuantity,
        note: item.note,
        variants: item.variants,
        sizeName: item.sizeName,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageSection(context, theme),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.sizeName ?? item.product.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.cartTextColor.withOpacity(0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // ✅ Oculta descrições genéricas de pizza (ex: "Pizza tamanho X - Categoria: Pizza")
                        if (item.product.description != null &&
                            item.product.description!.trim().isNotEmpty &&
                            !item.product.description!.toLowerCase().contains(
                              'categoria:',
                            ) &&
                            !item.product.description!.toLowerCase().contains(
                              'tamanho',
                            )) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.product.description!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: theme.cartTextColor.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildPriceSection(context, item, theme),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CartQuantityControl(
                    quantity: item.quantity,
                    textStyle: theme.bodyTextStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    onRemove: () {
                      final payload = createUpdatePayload(item.quantity - 1);
                      if (payload != null)
                        context.read<CartCubit>().updateItem(payload);
                    },
                    onAdd: () {
                      final payload = createUpdatePayload(item.quantity + 1);
                      if (payload != null)
                        context.read<CartCubit>().updateItem(payload);
                    },
                  ),
                ],
              ),
              if (item.variants.isNotEmpty) ...[
                _buildVariantsSection(context, theme),
              ],
              if (item.note != null && item.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  "Obs: ${item.note!.trim()}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context, DsTheme theme) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl:
                (item.sizeImageUrl != null && item.sizeImageUrl!.isNotEmpty)
                    ? item.sizeImageUrl!
                    : (item.product.imageUrl != null &&
                        item.product.imageUrl!.isNotEmpty)
                    ? item.product.imageUrl!
                    : 'https://placehold.co/72/e0e0e0/a0a0a0?text=Sem+Foto',
            height: 72,
            width: 72,
            fit: BoxFit.cover,
            errorWidget:
                (_, __, ___) => Container(
                  height: 72,
                  width: 72,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => goToEditCartItemPage(context, item),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cartBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.edit, size: 14, color: theme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection(
    BuildContext context,
    CartItem item,
    DsTheme theme,
  ) {
    // ✅ CORREÇÃO: Usa getter hasPromotion para detecção robusta de promoção
    final firstCategoryLink = item.product.categoryLinks.firstOrNull;

    // Verifica promoção no link
    final bool hasPromo = firstCategoryLink?.hasPromotion ?? false;

    if (hasPromo) {
      final originalUnitButton = firstCategoryLink!.price;

      // ✅ Calcula total de complementos/variantes para somar ao preço original
      int variantsTotal = 0;
      for (final variant in item.variants) {
        for (final option in variant.options) {
          variantsTotal += option.price * option.quantity;
        }
      }

      // O preço original deve incluir os complementos, pois o preço final (item.totalPrice) também inclui
      final originalTotalPrice =
          (originalUnitButton + variantsTotal) * item.quantity;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ✅ Preço Promocional em VERDE
          Text(
            item.totalPrice.toCurrency,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.green.shade700, // Verde escuro para destaque
            ),
          ),
          const SizedBox(width: 8),
          // ✅ Preço Original Riscado em CINZA
          Text(
            originalTotalPrice.toCurrency,
            style: TextStyle(
              fontSize: 13, // Levemente menor
              color: Colors.grey.shade400, // Cinza claro
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.grey.shade400,
            ),
          ),
        ],
      );
    }

    // Preço Normal
    return Text(
      item.formattedTotalPrice,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: theme.productTextColor,
      ),
    );
  }

  Widget _buildVariantsSection(BuildContext context, DsTheme theme) {
    String? massaText;
    String? bordaText;
    final flavorOptions = <CartItemVariantOption>[];
    final otherOptions = <CartItemVariantOption>[];

    for (final variant in item.variants) {
      if (variant.name.toLowerCase().contains('tamanho')) continue;

      final variantNameLower = variant.name.toLowerCase();
      final groupType = OptionGroupType.fromString(variant.groupType);
      final groupNameLower = variant.name.toLowerCase();

      final isFlavorGroup =
          groupType == OptionGroupType.topping ||
          groupType == OptionGroupType.flavor ||
          groupNameLower.contains('sabor') ||
          variant.options.any((o) => RegExp(r'^1/\d+\s+').hasMatch(o.name));

      // ✅ Usa EXCLUSIVAMENTE o enum do tipo de grupo — sem fallback de string
      final isMassaGroup = groupType == OptionGroupType.crust;
      final isBordaGroup = groupType == OptionGroupType.edge;
      final isPreferenceGroup =
          groupType == OptionGroupType.generic &&
          (variantNameLower.contains('preferência') ||
              variantNameLower.contains('preferencia'));

      for (final option in variant.options) {
        if (option.quantity <= 0) continue;

        final optionNameLower = option.name.toLowerCase();

        // Detecta combo "Massa + Borda" pelo nome da OPÇÃO
        if (optionNameLower.contains(' + ') || isPreferenceGroup) {
          if (optionNameLower.contains(' + ')) {
            final parts = option.name.split(' + ');
            if (parts.length >= 2) {
              massaText = parts[0].trim();
              bordaText = parts[1].trim();
            }
            continue;
          }
        }

        // Detecta Massa (somente via groupType enum)
        if (isMassaGroup) {
          massaText = option.name;
          continue;
        }

        // Detecta Borda (somente via groupType enum)
        if (isBordaGroup) {
          bordaText = option.name;
          continue;
        }

        // Sabores
        if (isFlavorGroup) {
          flavorOptions.add(option);
        } else {
          otherOptions.add(option);
        }
      }
    }

    // Coleta um mapa de preços: option.effectiveId → price
    // assim podemos exibir o preço fracionado de cada opção
    final optionPrices = <int, int>{};
    for (final variant in item.variants) {
      for (final option in variant.options) {
        if (option.quantity > 0 && option.price > 0) {
          optionPrices[option.effectiveId] = option.price;
        }
      }
    }

    final lineWidgets = <Widget>[];

    // 1. Massa + Borda (Unificado)
    if (massaText != null || bordaText != null) {
      String cleanMassa = massaText ?? '';
      String cleanBorda = bordaText ?? '';

      // Limpeza de prefixos redundantes
      while (RegExp(
        r'^[Mm]assa\s+',
        caseSensitive: false,
      ).hasMatch(cleanMassa)) {
        cleanMassa = cleanMassa.replaceFirst(
          RegExp(r'^[Mm]assa\s+', caseSensitive: false),
          '',
        );
      }
      while (RegExp(
        r'^[Bb]orda\s+',
        caseSensitive: false,
      ).hasMatch(cleanBorda)) {
        cleanBorda = cleanBorda.replaceFirst(
          RegExp(r'^[Bb]orda\s+', caseSensitive: false),
          '',
        );
      }

      String combinedText = '';
      if (massaText != null && bordaText != null) {
        combinedText = 'Massa $cleanMassa + Borda $cleanBorda';
      } else if (massaText != null) {
        combinedText = 'Massa $cleanMassa';
      } else {
        combinedText = 'Borda $cleanBorda';
      }
      lineWidgets.add(
        _buildVariantRow(
          context,
          '1',
          combinedText,
          theme,
          price: 0, // ✅ Oculta preço individual de Massa + Borda
        ),
      );
    }

    // 2. Sabores com Frações (sem preço individual)
    final flavorCount = flavorOptions.length;
    final fraction = flavorCount > 1 ? '1/$flavorCount ' : '';
    for (final flavor in flavorOptions) {
      String name = flavor.name;
      // Remove frações existentes se houver (o backend já pode ter adicionado)
      name = name.replaceAll(RegExp(r'^1/\d+\s*'), '').trim();
      lineWidgets.add(_buildVariantRow(context, '1', '$fraction$name', theme));
    }

    // 3. Outros
    for (final other in otherOptions) {
      lineWidgets.add(
        _buildVariantRow(context, other.quantity.toString(), other.name, theme),
      );
    }

    if (lineWidgets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lineWidgets,
      ),
    );
  }

  Widget _buildVariantRow(
    BuildContext context,
    String quantity,
    String text,
    DsTheme theme, {
    int price = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              quantity,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.cartTextColor.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.cartTextColor.withOpacity(0.75),
                height: 1.2,
              ),
            ),
          ),
          // ✅ Exibe preço fracionado do sabor (quando disponível)
          if (price > 0) ...[
            const SizedBox(width: 8),
            Text(
              price.toCurrency,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.cartTextColor.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
