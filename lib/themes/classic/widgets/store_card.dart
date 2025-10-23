import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:totem/core/responsive_builder.dart';
import 'package:totem/themes/classic/widgets/store_hours_widget.dart';


import '../../../cubit/store_cubit.dart';


import '../../ds_theme_switcher.dart';


class StoreCardData extends StatelessWidget {
  const StoreCardData({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreCubit>().state.store;
    bool isDesktop = ResponsiveBuilder.isDesktop(context);
    final double xyz = MediaQuery.of(context).size.width - 1170;
    final double realSpaceNeeded = xyz / 2;
    final theme = context.watch<DsThemeSwitcher>().theme;

    // ✅ 2. A GUARDA DE SEGURANÇA:
    // Se a loja ainda não carregou, mostramos um widget de placeholder/loading.
    if (store == null) {
      return SliverAppBar(
        expandedHeight: isDesktop ? 250 : 220,
        backgroundColor: theme.sidebarBackgroundColor,
        // Mostra um loading simples enquanto os dados não chegam
        flexibleSpace: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }




    final imageUrl = (store?.image?.url?.isNotEmpty ?? false)
        ? store!.image!.url!
        : 'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png';

    final pedidoMinimo = store?.store_operation_config?.deliveryMinOrder!.toStringAsFixed(2) ?? '0.00';
    final tempoEntrega = store?.store_operation_config != null
        ? '${store!.store_operation_config!.deliveryEstimatedMin}-${store.store_operation_config!.deliveryEstimatedMax} min'
        : '30-45 min';

    return SliverAppBar(
      expandedHeight: isDesktop ? 250 : 220,

      elevation: 0.5,
      backgroundColor: theme.sidebarBackgroundColor,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = constraints.biggest.height;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Imagem de fundo
              ClipRRect(
              //  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: Image.network(
                  store?.banner?.url ?? 'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png',
                  fit: BoxFit.cover,
                  height: double.infinity,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey,
                    height: double.infinity,
                    child: const Icon(Icons.store, size: 100, color: Colors.white54),
                  ),
                ),
              ),

              // Card central com imagem flutuante
              Positioned(
                bottom: -70,
                left: isDesktop ? realSpaceNeeded : 16,
                right: isDesktop ? realSpaceNeeded : 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Card
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                      decoration: BoxDecoration(
                        color: theme.sidebarBackgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          // Nome da loja com trailing
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: GestureDetector(
                              // Exemplo de como você chamaria a navegação


                              onTap: () {
                                context.go('/store-details', extra: 1);
                              },

                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      store?.name ?? 'Nome da Loja',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: theme.sidebarTextColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                 Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.sidebarIconColor,),
                                ],
                              ),
                            ),

                            subtitle: Padding(
                              padding: const EdgeInsets.symmetric(vertical:12.0),
                              child: Column(
                                children: [



                                  if (store?.ratingsSummary != null)
                                    GestureDetector(
                                       onTap: () {
                                             context.go('/store-details', extra: 0);
                                            },

                                      child: Row(
                                        children: [


                                          Expanded(
                                            child: Row(
                                              children: [

                                                Text(
                                                  store!.ratingsSummary!.averageRating
                                                      .toStringAsFixed(1),
                                                  style: TextStyle(fontSize: 16,   color: theme.sidebarTextColor,),
                                                ),

                                                const SizedBox(width: 8),


                                                Row(
                                                  children: List.generate(5, (index) {
                                                    final starIndex = index + 1;
                                                    return Icon(
                                                      starIndex <=
                                                          store.ratingsSummary!
                                                              .averageRating
                                                              .round()
                                                          ? Icons.star
                                                          : Icons.star_border,
                                                      color: Colors.amber,
                                                      size: 20,
                                                    );
                                                  }),
                                                ),
                                                const SizedBox(width: 8),

                                                Text(
                                                  '(${store.ratingsSummary!.totalRatings} avaliações)',
                                                  style:  TextStyle(fontSize: 14,   color:theme.sidebarTextColor,),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(width: 8),


                                           Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.sidebarIconColor,),
                                        ],
                                      ),
                                    ),














                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                                    child: Row(
                                      children: [

                                        Expanded(
                                          child: Text(
                                            'Pedido mínimo: R\$ $pedidoMinimo',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: theme.sidebarTextColor,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10,),
                                        Text(
                                          'Entrega: $tempoEntrega',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: theme.sidebarTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),


                                  StoreHoursWidget(hours: store!.hours,)



                                ],
                              ),
                            ),

                          ),

                        ],
                      ),
                    ),

                    // Imagem da loja parcialmente fora
                    Positioned(
                      top: -40,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1),
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(imageUrl),
                          radius: 40,
                          backgroundColor: Colors.transparent
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}



