import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart'; // Import para usar o 'firstOrNull'
import 'package:totem/core/extensions.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/themes/ds_theme.dart';
import '../../../helpers/navigation_helper.dart';
import '../../../models/cart_item.dart';
import '../../../models/update_cart_payload.dart';
import '../../../themes/ds_theme_switcher.dart';
import 'cart_quantity_control.dart';

class CartItemListItem extends StatelessWidget {
  final CartItem item;

  const CartItemListItem({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    // ✅ FUNÇÃO CORRIGIDA
    UpdateCartItemPayload? createUpdatePayload(int newQuantity) {
      // 1. Pega o primeiro vínculo de categoria do produto.
      final firstCategoryLink = item.product.categoryLinks.firstOrNull;

      // 2. Validação de segurança: se o produto no carrinho não tem categoria,
      // não podemos atualizá-lo. Isso indica um problema de dados.
      if (firstCategoryLink == null) {
        print("ERRO: O produto '${item.product.name}' no carrinho não tem uma categoria associada.");
        // Retorna nulo para indicar que o payload não pôde ser criado.
        return null;
      }

      // 3. Cria o payload com o categoryId correto.
      return UpdateCartItemPayload(
        cartItemId: item.id,
        productId: item.product.id!,
        categoryId: firstCategoryLink.categoryId, // Usa o ID da categoria encontrada
        quantity: newQuantity,
        note: item.note,
        variants: item.variants,
        sizeName: item.sizeName,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: item.product.coverImageUrl ?? 'https://placehold.co/72/e0e0e0/a0a0a0?text=Sem+Foto',
                height: 72,
                width: 72,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ TÍTULO DO PRODUTO + CONTROLE DE QUANTIDADE
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.product.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.cartTextColor.withOpacity(0.8)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  CartQuantityControl(
                    quantity: item.quantity,
                    textStyle: theme.bodyTextStyle.copyWith(fontWeight: FontWeight.bold),
                    onRemove: () {
                      final payload = createUpdatePayload(item.quantity - 1);
                      if (payload != null) {
                        context.read<CartCubit>().updateItem(payload);
                      }
                    },
                    onAdd: () {
                      final payload = createUpdatePayload(item.quantity + 1);
                      if (payload != null) {
                        context.read<CartCubit>().updateItem(payload);
                      }
                    },
                  ),
                ],
              ),
              
              // ✅ DESCRIÇÃO DO PRODUTO (se houver)
              if (item.product.description != null && item.product.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.product.description!,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: theme.cartTextColor.withOpacity(0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              if (item.product.description != null)
              const SizedBox(height: 8),
              _buildPriceSection(context, item, theme),
              
              // ✅ COMPLEMENTOS COM QUANTIDADE (AJUSTE 2)
              if (item.variants.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildVariantsSection(item, theme),
              ],
              
              // ✅ OBSERVAÇÃO (por último)
              if (item.note != null && item.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  "Observação: ${item.note!.trim()}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ✅ MÉTODO: Exibe preço e preço com desconto (se houver)
  Widget _buildPriceSection(BuildContext context, CartItem item, DsTheme theme) {
    final firstCategoryLink = item.product.categoryLinks.firstOrNull;
    
    // Verifica se há promoção na categoria
    if (firstCategoryLink != null && 
        firstCategoryLink.isOnPromotion && 
        firstCategoryLink.promotionalPrice != null) {
      // Calcula o preço total original (sem desconto)
      final originalTotalPrice = firstCategoryLink.price * item.quantity;
      // O totalPrice já vem com o desconto aplicado do backend
      final discountedTotalPrice = item.totalPrice;
      
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            discountedTotalPrice.toCurrency,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: theme.productTextColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            originalTotalPrice.toCurrency,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    // Sem desconto, mostra apenas o preço atual
    return Text(
      item.formattedTotalPrice,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: theme.productTextColor,
      ),
    );
  }

  // ✅ MÉTODO: Exibe complementos com quantidade antes do nome
  Widget _buildVariantsSection(CartItem item, DsTheme theme) {
    final variantLines = <Widget>[];

    for (final variant in item.variants) {
      for (final option in variant.options) {
        if (option.quantity > 0) {
          variantLines.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: theme.cartTextColor.withOpacity(0.6)),
                  ),
                  Expanded(
                    child: Text(
                      '${option.quantity}x ${option.name}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.cartTextColor.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: variantLines,
    );
  }
}