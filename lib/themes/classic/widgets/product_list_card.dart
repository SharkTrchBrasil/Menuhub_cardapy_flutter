import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart'; // Mantido para contexto, assumindo uso em outros lugares
import 'package:go_router/go_router.dart'; // Mantido para contexto, assumindo uso em outros lugares
import 'package:totem/core/extensions.dart'; // Para a extensão .toCurrency
import 'package:totem/models/product.dart'; // Sua classe Product
import 'package:totem/themes/ds_theme.dart';

import '../../../helpers/navigation_helper.dart'; // Assumindo que isso ajuda na navegação
import '../../ds_theme_switcher.dart';
import '../../../pages/home/widgets/ds_card.dart';

// Seu widget de card personalizado
class ProductListCard extends StatelessWidget {
  const ProductListCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return DsCard(
      onTap: () => goToProductPage(context, product),
      child:

       SizedBox(
      height: 120, // altura maior para melhor distribuição
       width: 180,
      child: Wrap(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Imagem com selo
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                       imageUrl: product.coverImageUrl?.isNotEmpty == true
                      ? product.coverImageUrl!
                        : 'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png', // URL padrão ou imagem local

                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (_, __, ___) => Icon(
                          Icons.image,
                          color: theme.priceTextColor.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  if (product.activatePromotion)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PROMOÇÃO!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),

              // Informações
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8), // padding interno vertical
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // distribui nome, preços e descrição
                    children: [

                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.productTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (product.activatePromotion)
                        Row(
                          children: [
                            Flexible(
                              child: Text(

                                product.promotionPrice!.toCurrency,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(

                                product.basePrice.toCurrency,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.productTextColor.withOpacity(0.5),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          product.basePrice.toCurrency,
                          style: TextStyle(
                            color: theme.priceTextColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.productTextColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),

        );
  }
}
