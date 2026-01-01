import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';
import 'package:collection/collection.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import '../../../models/option_group.dart';
import '../../../services/availability_service.dart';
import '../../../pages/cart/cart_cubit.dart';
import '../../../models/update_cart_payload.dart';
import '../../../widgets/clear_cart_confirmation.dart';

class ProductItem extends StatelessWidget {
  final Product product;
  final Category category; // Categoria necessária para o contexto de preço
  final VoidCallback? onTap;

  const ProductItem({
    super.key,
    required this.product,
    required this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    int? displayPrice;
    int? originalPrice;
    bool showAsStartingFrom = false;

    // Lógica de preço para categoria customizável (pizzas)
    if (category.isCustomizable) {
      // ✅ CORREÇÃO: Para pizzas, busca o menor preço dos tamanhos
      // O unitMinPrice que vem do backend agora é o preço CHEIO (não dividido)
      final sizeGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.size,
      );
      
      if (sizeGroup != null && sizeGroup.items.isNotEmpty) {
        int minPrice = 99999999;
        bool found = false;
        
        for (var size in sizeGroup.items.where((s) => s.isActive)) {
          if (size.price > 0 && size.price < minPrice) {
            minPrice = size.price;
            found = true;
          }
        }
        
        if (found && minPrice < 99999999) {
          displayPrice = minPrice;
          showAsStartingFrom = true;
        }
      }
      
      // Fallback: Se não encontrou preço nos tamanhos, tenta product.prices
      if (displayPrice == null && product.prices.isNotEmpty) {
        final validPrices = product.prices.where((p) => p.price > 0).map((p) => p.price);
        displayPrice = validPrices.isNotEmpty ? validPrices.reduce(min) : 0;
        showAsStartingFrom = true;
      }
    } else {
      // Lógica para categoria geral
      final link = product.categoryLinks.firstWhereOrNull((l) => l.categoryId == category.id);
      if (link != null) {
        if (link.isOnPromotion && link.promotionalPrice != null) {
          displayPrice = link.promotionalPrice;
          originalPrice = link.price;
        } else {
          displayPrice = link.price;
        }
      }
      
      // ✅ Se preço é 0, busca menor preço nos grupos de complementos
      if ((displayPrice == null || displayPrice == 0) && product.variantLinks.isNotEmpty) {
        int minVariantPrice = 0;
        for (final variantLink in product.variantLinks) {
          final variant = variantLink.variant;
          if (variant.options.isNotEmpty) {
            for (final option in variant.options) {
              if (option.resolvedPrice > 0 && (minVariantPrice == 0 || option.resolvedPrice < minVariantPrice)) {
                minVariantPrice = option.resolvedPrice;
              }
            }
          }
        }
        if (minVariantPrice > 0) {
          displayPrice = minVariantPrice;
          showAsStartingFrom = true;
        }
      }
    }

    displayPrice ??= 0;
    final hasPromo = originalPrice != null;
    final discountPercent = hasPromo ? (((originalPrice! - displayPrice) / originalPrice) * 100).round() : 0;

    // ✅ VERIFICAÇÃO DE DISPONIBILIDADE
    final isAvailable = AvailabilityService.isProductAvailableNow(product);
    
    // ✅ Verifica se pode fazer Quick Add (produto simples sem variantes e não é pizza)
    final hasVariants = product.variantLinks.isNotEmpty;
    final isPizza = product.prices.isNotEmpty;
    final canQuickAdd = isAvailable && !hasVariants && !isPizza;

    return GestureDetector(
      onTap: isAvailable ? onTap : null, // Desabilita clique se indisponível
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.5, // Efeito visual de desabilitado
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.description != null && product.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        product.description!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isAvailable) ...[
                          if (hasPromo) ...[
                            // Preço original riscado
                            Text(
                              originalPrice!.toCurrency,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Preço com desconto em verde
                            Text(
                              displayPrice.toCurrency,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade600),
                            ),
                            const SizedBox(width: 8),
                            // Badge de desconto
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                '-$discountPercent%',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ] else ...[
                            // Preço normal (sem promoção)
                            Text(
                              (category.isCustomizable || showAsStartingFrom) ? 'A partir de ${displayPrice.toCurrency}' : displayPrice.toCurrency,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ] else ...[
                          // Texto de indisponível
                          const Text(
                            'Indisponível no momento',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildProductImage(context, product, isAvailable, canQuickAdd),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(BuildContext context, Product product, bool isAvailable, bool canQuickAdd) {
    final coverImageUrl = product.imageUrl;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: SizedBox(
            width: 80,
            height: 80,
            child: coverImageUrl != null && coverImageUrl.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: coverImageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
              ),
              errorWidget: (context, url, error) => _buildImagePlaceholder(),
            )
                : _buildImagePlaceholder(),
          ),
        ),
        if (!isAvailable)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Center(
                child: Icon(Icons.block, color: Colors.red, size: 30),
              ),
            ),
          ),
        // ✅ NOVO: Botão Quick Add para produtos simples
        if (canQuickAdd)
          Positioned(
            bottom: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _handleQuickAdd(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ✅ NOVO: Função para adicionar produto simples ao carrinho rapidamente
  Future<void> _handleQuickAdd(BuildContext context) async {
    // ✅ SEGURANÇA: Verifica se o carrinho tem itens de outra loja
    final canProceed = await canAddToCart(
      context: context,
      productStoreId: product.storeId,
    );
    
    if (!canProceed) {
      return; // Usuário cancelou, não adiciona
    }
    
    final firstCategoryLink = product.categoryLinks.firstOrNull;
    if (firstCategoryLink == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${product.name} não pertence a nenhuma categoria.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final payload = UpdateCartItemPayload(
      productId: product.id!,
      categoryId: firstCategoryLink.categoryId,
      quantity: 1,
      variants: null,
    );

    try {
      await context.read<CartCubit>().updateItem(payload);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} adicionado à sacola!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível adicionar ${product.name}. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade100,
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/burguer.svg',
          width: 42,
          height: 42,
          colorFilter: ColorFilter.mode(Colors.grey.shade400, BlendMode.srcIn),
          semanticsLabel: 'Imagem padrão do produto',
        ),
      ),
    );
  }
}