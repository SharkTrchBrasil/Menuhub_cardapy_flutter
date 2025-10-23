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
import '../../../pages/home/widgets/ds_card.dart'; // Seu widget de card personalizado

class ProductGridCard extends StatelessWidget { // Classe renomeada para Grid
  const ProductGridCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return DsCard( // Assumimos que DsCard provê a aparência geral do card (padding, elevação, border radius)
      onTap: () {
        // Navega para a página de detalhes do produto quando o cartão é tocado
        goToProductPage(context, product);
      },
      // Para itens de grade, geralmente não precisamos de IntrinsicHeight;
      // eles se baseiam em AspectRatio ou altura fixa para o layout.
      child: Column( // Layout principal para um item de grade: imagem no topo, detalhes abaixo
        crossAxisAlignment: CrossAxisAlignment.start, // Alinha o conteúdo ao início (esquerda)
        children: [
          // Seção superior: Imagem com cantos arredondados e selo de promoção
          AspectRatio(
            aspectRatio: 1, // Imagem quadrada, comum para itens de grade
            child: ClipRRect( // Recorta a imagem para ter cantos superiores arredondados
              borderRadius: const BorderRadius.only( // Assumindo que DsCard tem raio de 8.0
                topLeft: Radius.circular(8.0),
                topRight: Radius.circular(8.0),
              ),
              child: Stack(
                children: [
                  Positioned.fill( // Faz com que a imagem preencha todo o Stack
                    child: CachedNetworkImage(
                       imageUrl: product.coverImageUrl?.isNotEmpty == true
                    ? product.coverImageUrl!
                      : 'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png', // URL padrão ou imagem local

                      placeholder: (context, url) => CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    )
                  ),
                  // Selo de Promoção (exibido condicionalmente se activatePromotion for verdadeiro)
                  if (product.activatePromotion)
                    Positioned(
                      top: 8, // Distância da borda superior
                      left: 8, // Distância da borda esquerda
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[600], // Uma cor vermelha distinta para o selo de promoção
                          borderRadius: BorderRadius.circular(6), // Cantos levemente arredondados para o selo
                        ),
                        child: const Text(
                          'PROMOÇÃO!', // Texto personalizável para o selo
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5, // Um pequeno espaçamento para melhor legibilidade
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Seção inferior: Detalhes do produto (nome, descrição, preços)
          Padding(
            padding: const EdgeInsets.all(12), // Preenchimento para o conteúdo de texto
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome do Produto
                Text(
                  product.name,
                  maxLines: 1, // Limita o nome do produto a 2 linhas
                  overflow: TextOverflow.ellipsis, // Adiciona reticências se o nome exceder as linhas
                  style: TextStyle(
                    color: theme.productTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4), // Pequeno espaço vertical

                // Descrição do Produto (se disponível)
                if (product.description != null && product.description!.isNotEmpty)
                  Text(
                    product.description!,
                    maxLines: 1, // Limita a descrição a 1 linha
                    overflow: TextOverflow.ellipsis, // Adiciona reticências se a descrição exceder a linha
                    style: TextStyle(
                      color: theme.productTextColor.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                // Adiciona um pouco de espaço abaixo da descrição se ela existir, ou logo abaixo do nome
                product.description != null && product.description!.isNotEmpty
                    ? const SizedBox(height: 8)
                    : const SizedBox(height: 4), // Menos espaço se não houver descrição

                // Preços
                Row(

                  children: [
                    // Preço base riscado (exibido apenas se activatePromotion for verdadeiro)
                    if (product.activatePromotion)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            product.basePrice.toCurrency,
                            style: TextStyle(
                              color: theme.priceTextColor.withOpacity(0.6), // Cor levemente desbotada
                              decoration: TextDecoration.lineThrough, // Aplica o risco
                              fontSize: 12, // Tamanho de fonte menor para o preço original
                            ),
                          ),
                        ),
                      ),
                    // Preço atual (Preço de promoção se activatePromotion for verdadeiro, caso contrário Preço base)
                    Flexible(
                      child: Text(
                        (product.activatePromotion ? product.promotionPrice : product.basePrice)!.toCurrency,
                        style: TextStyle(
                          color: theme.priceTextColor, // Usa a cor de texto de preço do seu tema
                          fontWeight: FontWeight.bold,
                          fontSize: 16, // Maior e em negrito para o preço principal exibido
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
