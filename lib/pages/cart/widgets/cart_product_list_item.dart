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

    // ✅ FUNÇÃO CORRIGIDA COM VALIDAÇÃO DE cartItemId
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
      
      // ✅ VALIDAÇÃO ADICIONAL: Garante que item.id é válido para modo edição
      if (item.id <= 0) {
        print("ERRO: O item '${item.product.name}' não tem ID válido (id: ${item.id}).");
        return null;
      }

      // 3. Cria o payload com o categoryId correto.
      print("🔍 [CART] Criando payload: cartItemId=${item.id}, productId=${item.product.id}, qty=$newQuantity");
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
                // ✅ Usa sizeImageUrl (imagem do tamanho) se disponível, senão usa imageUrl do produto
                imageUrl: item.sizeImageUrl ?? item.product.imageUrl ?? 'https://placehold.co/72/e0e0e0/a0a0a0?text=Sem+Foto',
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ TÍTULO DO PRODUTO
                    Text(
                      item.sizeName ?? item.product.name, 
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w600, 
                        color: theme.cartTextColor.withOpacity(0.8)
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // ✅ DESCRIÇÃO DO PRODUTO (se houver)
                    if (item.product.description != null && item.product.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.product.description!,
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.w400, 
                          color: theme.cartTextColor.withOpacity(0.7)
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),
                    _buildPriceSection(context, item, theme),
                    
                    // ✅ COMPLEMENTOS
                    if (item.variants.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildVariantsSection(item, theme),
                    ],
                    
                    // ✅ OBSERVAÇÃO
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
              const SizedBox(width: 12),
              // ✅ CONTROLE DE QUANTIDADE AGORA ALINHADO À DIREITA DE TODO BLOCO
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

  // ✅ MÉTODO: Exibe complementos estilo iFood (linhas separadas)
  // Formato iFood (imagem 04):
  // - 1 Massa Tradicional + Borda Calabresa
  // - 1 1/2 Pepperoni
  // - 1 1/2 Pizza 4 queijos
  Widget _buildVariantsSection(CartItem item, DsTheme theme) {
    // Agrupa opções por tipo
    String? massaText;
    String? bordaText;
    final flavorTexts = <String>[];
    final otherTexts = <String>[];

    for (final variant in item.variants) {
      // ✅ Ignora variant de tamanho (SIZE) - já está no size_name
      final isSizeGroup = variant.name.toLowerCase().contains('tamanho') || 
          variant.name.toLowerCase().contains('size');
      
      if (isSizeGroup) {
        continue;
      }
      
      // Identifica tipo de grupo
      final isMassaGroup = variant.name.toLowerCase().contains('massa');
      final isBordaGroup = variant.name.toLowerCase().contains('borda') || 
                           variant.name.toLowerCase().contains('edge');
      final isFlavorGroup = variant.name.toLowerCase().contains('sabor') ||
                            variant.name.toLowerCase().contains('topping') ||
                            variant.name.toLowerCase().contains('flavor');
      
      for (final option in variant.options) {
        if (option.quantity > 0 && option.name.isNotEmpty) {
          if (isMassaGroup) {
            massaText = option.name;
          } else if (isBordaGroup) {
            bordaText = option.name;
          } else if (isFlavorGroup) {
            // ✅ Formato sabor: "1 1/2 Pepperoni" ou "1 Calabresa"
            String displayText;
            if (option.name.toLowerCase().contains('1/2') || 
                option.name.toLowerCase().contains('1/3') ||
                option.name.toLowerCase().contains('meio')) {
              // Nome já contém fração
              displayText = '1 ${option.name}';
            } else {
              // Adiciona "1" na frente (individual)
              displayText = '1 ${option.name}';
            }
            flavorTexts.add(displayText);
          } else {
            // Outros complementos (adiconais etc)
            if (option.quantity > 1) {
              otherTexts.add('${option.quantity}x ${option.name}');
            } else {
              otherTexts.add('1x ${option.name}');
            }
          }
        }
      }
    }

    // ✅ Monta lista de widgets em linhas separadas
    final lineWidgets = <Widget>[];
    
    // Primeira linha: Massa + Borda (se houver)
    if (massaText != null || bordaText != null) {
      String combinedLine = '';
      if (massaText != null && bordaText != null) {
        combinedLine = '1 $massaText + Borda $bordaText';
      } else if (massaText != null) {
        combinedLine = '1 $massaText';
      } else if (bordaText != null) {
        combinedLine = '1 Borda $bordaText';
      }
      if (combinedLine.isNotEmpty) {
        lineWidgets.add(_buildVariantLine(combinedLine, theme));
      }
    }
    
    // Linhas de sabores (um por linha)
    for (final flavor in flavorTexts) {
      lineWidgets.add(_buildVariantLine(flavor, theme));
    }
    
    // Linhas de outros complementos (um por linha)
    for (final other in otherTexts) {
      lineWidgets.add(_buildVariantLine(other, theme));
    }

    if (lineWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lineWidgets,
      ),
    );
  }
  
  // ✅ Helper: Cria linha individual de variant
  Widget _buildVariantLine(String text, DsTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet point estilo iFood
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: theme.cartTextColor.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.cartTextColor.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}