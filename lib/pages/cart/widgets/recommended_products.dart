import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/extensions.dart';

import '../../../helpers/navigation_helper.dart';
import '../../../models/cart_product.dart';
import '../../../models/product.dart';
import '../../../models/update_cart_payload.dart';
import '../../../themes/ds_theme_switcher.dart';
import '../../../widgets/ds_tag.dart';
import '../cart_cubit.dart';

class RecommendedProductsSection extends StatelessWidget {
  final List<Product> recommendedProducts;

  const RecommendedProductsSection({required this.recommendedProducts, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Peça também',
          style: TextStyle(
            color: theme.cartTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 192,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
          //  padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommendedProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              return RecommendedProductTile(product: recommendedProducts[i]);
            },
          ),
        ),
      ],
    );
  }
}

class RecommendedProductTile extends StatefulWidget {
  final Product product;

  const RecommendedProductTile({required this.product, super.key});

  @override
  State<RecommendedProductTile> createState() => _RecommendedProductTileState();
}

class _RecommendedProductTileState extends State<RecommendedProductTile> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    // ✅ Estado local para controlar o loading do botão deste item específico
    bool _isLoading = false;

    // ✅ CORREÇÃO 1: A verificação agora usa 'variantLinks'
    final hasVariants = (widget.product.variantLinks?.isNotEmpty ?? false);

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.product.coverImageUrl ?? '',
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    width: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 32),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  // ✅ Desabilita o tap enquanto estiver carregando
                  onTap: _isLoading
                      ? null
                      : () async { // A função agora é async
                    if (!hasVariants) {
                      // --- LÓGICA CORRIGIDA ---
                      setState(() => _isLoading = true);

                      // 1. Monta o payload para o backend
                      final payload = UpdateCartItemPayload(
                        productId: widget.product.id,
                        quantity: 1, // Sempre adiciona 1 unidade
                        variants: [], // Sem variantes
                      );

                      try {
                        // 2. Chama o método do cubit
                        await context.read<CartCubit>().updateItem(payload);

                        if (mounted) {
                          // 3. Mostra o feedback de sucesso
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${widget.product.name} adicionado ao carrinho!'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        // Trata o erro se necessário
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    } else {
                      // Navegar para a página de detalhes permanece igual
                      goToProductPage(context, widget.product);
                    }
                  },
                  child: Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    // ✅ Mostra um loading ou o ícone de adicionar
                    child: _isLoading
                        ? const CupertinoActivityIndicator()
                        : Icon(Icons.add, size: 20, color: theme.primaryColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // A sua lógica para exibir o preço já estava correta e não precisa de mudanças.
          if (widget.product.activatePromotion && widget.product.promotionPrice != null) ...[
            Row(
              children: [
                Text(
                  widget.product.promotionPrice!.toCurrency,
                  style: TextStyle(fontWeight: FontWeight.w600, color: theme.productTextColor),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.product.basePrice.toCurrency,
                  style: theme.paragraphTextStyle.copyWith(
                    color: Colors.grey,
                    fontSize: 13,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              widget.product.basePrice.toCurrency,
              style: TextStyle(fontWeight: FontWeight.w600, color: theme.productTextColor),
            ),
          ],

          const SizedBox(height: 4),
          Text(
            widget.product.name,
            style: TextStyle(color: theme.cartTextColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
