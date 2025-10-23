import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/core/extensions.dart';
import '../../../models/product.dart';

class ProductItem extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductItem({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final hasPromo = product.activatePromotion;
    final oldPrice = product.basePrice;
    final newPrice = hasPromo ? product.promotionPrice ?? oldPrice : oldPrice;

    final discountPercent = hasPromo
        ? (((oldPrice - newPrice) / oldPrice) * 100).round()
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Material(


        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Parte esquerda: info do produto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome
                    Text(
                      product.name ?? 'Sem nome',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),


                    const SizedBox(height: 8),
                    Text(
                      product.description ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87

                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),
                    // Preços
                    Row(
                      children: [
                        Text(
                          newPrice.toCurrency,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasPromo)
                          Text(
                            oldPrice.toCurrency,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (hasPromo)
                          const SizedBox(width: 8),
                        if (hasPromo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[600],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '-$discountPercent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),


                    if (hasPromo)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Item promocional',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              _buildProductImage(product),


            ],
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
        width: 80,  // Defina a largura desejada
        height: 80, // Defina a altura desejada
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



  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.fastfood, size: 40, color: Colors.grey),
      ),
    );
  }
}
