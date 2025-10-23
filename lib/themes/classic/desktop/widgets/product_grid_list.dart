// themes/classic/widgets/product_item.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/product.dart'; // ✅ Importe seu modelo de produto

class ProductItemGrid extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductItemGrid({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Lógica para determinar o preço a ser exibido
    final bool hasPromo = product.promotionPrice != null && product.promotionPrice! > 0;
    final displayPrice = hasPromo ? product.promotionPrice! : product.basePrice;
    final originalPrice = hasPromo ? product.basePrice : null;

    final imageUrl = (product.coverImageUrl?.isNotEmpty ?? false)
        ? product.coverImageUrl!
        : 'https://placehold.co/128/e0e0e0/a0a0a0?text=Produto';

    return Material(
      elevation: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12)
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna com Textos (Título, Descrição, Preço)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Seção de Título e Descrição
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (product.description.isNotEmpty)
                            Text(
                              product.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
        
        
        
                      // Seção de Preço
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              displayPrice.toCurrency,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (originalPrice != null)
                              Text(
                                originalPrice.toCurrency,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        
                const SizedBox(width: 16),
        
                // Imagem do Produto
                _buildProductImage(product)



              ],
            ),
          ),
        ),
      ),
    );
  }

  // Função para construir a imagem do produto de forma segura
  Widget _buildProductImage(Product product) {
    // 1. Pega a URL da imagem de capa, se existir.
    final coverImageUrl = (product.images.isNotEmpty)
        ? product.images.first.url
        : null;

    // 2. Usa um ClipRRect para ter as bordas arredondadas.
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: SizedBox(
        width: 96,  // Defina a largura desejada
        height: 96, // Defina a altura desejada
        child: coverImageUrl != null
        // 3. Se tiver uma imagem, usa CachedNetworkImage para carregar e cachear.
            ? CachedNetworkImage(
          imageUrl: coverImageUrl,
          fit: BoxFit.cover,
          // Widget que aparece enquanto a imagem está carregando
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
          ),
          // Widget que aparece se der erro ao carregar a imagem
          errorWidget: (context, url, error) => const Icon(Icons.error),
        )
        // 4. Se não houver imagem, mostra o placeholder.
            : Container(
          color: Colors.grey.shade100,
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/burguer.svg', // Verifique se este asset existe no seu app de cardápio
              width: 42,
              height: 42,
              colorFilter: ColorFilter.mode(Colors.grey.shade400, BlendMode.srcIn),
              semanticsLabel: 'Imagem padrão do produto',
            ),
          ),
        ),
      ),
    );
  }

}