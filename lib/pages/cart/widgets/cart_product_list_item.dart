import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/themes/ds_theme.dart';


import '../../../helpers/navigation_helper.dart';
import '../../../models/cart.dart';
import '../../../models/cart_item.dart';
import '../../../models/update_cart_payload.dart';
import '../../../themes/ds_theme_switcher.dart';
import '../../../widgets/ds_tag.dart';

import '../../product/product_page_cubit.dart';
import 'cart_quantity_control.dart';

// ✅ O widget agora recebe um CartItem, não um CartProduct.
class CartItemListItem extends StatelessWidget {
  final CartItem item;

  const CartItemListItem({
    super.key,
    required this.item,
  });


  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;


    // Função auxiliar para criar o payload de atualização de quantidade
    UpdateCartItemPayload _createUpdatePayload(int newQuantity) {
      return UpdateCartItemPayload(
        productId: item.product.id,
        quantity: newQuantity,
        note: item.note,
        // É crucial reenviar a configuração de variantes para o backend
        // identificar corretamente qual item está sendo alterado.
        variants: item.variants.map((v) => CartItemVariant(
          variantId: v.variantId,
          options: v.options.map((o) => CartItemVariantOption(
              variantOptionId: o.variantOptionId,
              quantity: o.quantity,
              name: o.name,
              price: o.price
          )).toList(),
          name: v.name,
        )).toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imagem
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: item.product.coverImageUrl ?? '',
                height: 72,
                width: 72,
                fit: BoxFit.cover,
                errorWidget:
                    (_, __, ___) => Container(
                      height: 72,
                      width: 72,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
              ),
            ),

            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {

                  goToEditCartItemPage(context, item);
                 // context.go('/product/${item.product.id}', extra: item);
                  // 2. Navega para a página de edição, passando o produto completo
                 // goToCartProductPage(context, cartProduct);
                },

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

        // Informações do produto
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Nome e descrição ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.cartTextColor.withOpacity(0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.product.description,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: theme.cartTextColor.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // --- Controle de quantidade à direita ---
                  CartQuantityControl(
                    quantity: item.quantity,
                    textStyle: theme.bodyTextStyle.weighted(FontWeight.bold),

                    onRemove: () {
                      final payload = _createUpdatePayload(item.quantity - 1);
                      context.read<CartCubit>().updateItem(payload);
                    },
                    onAdd: () {
                      final payload = _createUpdatePayload(item.quantity + 1);
                      context.read<CartCubit>().updateItem(payload);
                    },

                  ),
                ],
              ),


              const SizedBox(height: 12),
// Dentro do seu widget que recebe o `CartItem item`

// Lógica de exibição de preço
              if (item.product.activatePromotion && item.product.promotionPrice != null) ...[
                // CASO 1: O produto tem uma promoção oficial ativa.
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Preço com promoção
                    Text(
                      item.unitPrice.toCurrency, // O preço unitário já considera a promoção
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor, // Cor de destaque para promoção
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Preço original riscado
                    Text(
                      item.product.basePrice.toCurrency, // Pega o preço base original
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                )
              ] else if (item.unitPrice < item.product.basePrice) ...[
                // CASO 2: O preço final é menor que o base (provavelmente por cupom)
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      item.unitPrice.toCurrency, // Mostra o preço com desconto do cupom
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green, // Cor de destaque para desconto
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.product.basePrice.toCurrency, // Pega o preço base original
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // CASO 3: Preço normal (sem promoções ou cupons)
                Text(
                  item.unitPrice.toCurrency, // Mostra o preço unitário (base + complementos)
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.productTextColor,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ✅ A lógica de exibição de variantes agora funciona com os novos modelos
              for (final variant in item.variants)
                if (variant.options.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(variant.name, /*...*/),
                      const SizedBox(height: 4),
                      ...variant.options.map((option) => Row(
                        children: [
                          Expanded(child: Text('${option.quantity > 1 ? '${option.quantity}x ' : ''}${option.name}')),
                          if (option.price > 0) Text('+ ${option.price.toCurrency}'),
                        ],
                      )),
                      const SizedBox(height: 8),
                    ],
                  ),

              if (item.note != null && item.note!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("Observação: ${item.note!.trim()}", /*...*/),
                ),
            ],
          ),
        ),

        const SizedBox(width: 8),




      ],
    );
  }
}
