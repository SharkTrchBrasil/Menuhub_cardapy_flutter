import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:collection/collection.dart'; // Collection for firstWhereOrNull

import 'package:totem/core/responsive_builder.dart';
import 'package:totem/themes/classic/widgets/store_hours_widget.dart';
import 'package:totem/core/extensions.dart'; // ToCurrency

import '../../../cubit/store_cubit.dart';
import '../../ds_theme_switcher.dart';
import '../../../pages/address/cubits/address_cubit.dart';
import '../../../services/store_status_service.dart';
import '../../../helpers/store_hours_helper.dart';
import 'package:totem/models/delivery_type.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';

class StoreCardData extends StatelessWidget {
  const StoreCardData({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreCubit>().state.store;
    bool isDesktop = ResponsiveBuilder.isDesktop(context);
    final double xyz = MediaQuery.of(context).size.width - 1170;
    final double realSpaceNeeded = xyz / 2;
    final theme = context.watch<DsThemeSwitcher>().theme;

    // ✅ Get User Address for Distance Calculation
    final addressState = context.watch<AddressCubit>().state;
    final userAddress = addressState.selectedAddress;

    // ✅ SEGURANÇA: Store Loading
    if (store == null) {
      return SliverAppBar(
        expandedHeight:
            isDesktop
                ? 250
                : 250, // Increased height for mobile too to fit new layout
        pinned: false,
        backgroundColor: theme.sidebarBackgroundColor,
        flexibleSpace: const Center(child: CircularProgressIndicator()),
      );
    }

    final deliveryFeeState = context.watch<DeliveryFeeCubit>().state;

    final imageUrl =
        (store.image?.url?.isNotEmpty ?? false)
            ? store.image!.url!
            : 'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png';

    // ✅ CALCULAR DISTÂNCIA
    String? distanceText;
    if (deliveryFeeState is DeliveryFeeLoaded &&
        deliveryFeeState.deliveryType == DeliveryType.delivery &&
        deliveryFeeState.distanceKm != null) {
      final distanceKm = deliveryFeeState.distanceKm!;
      distanceText =
          distanceKm < 1
              ? '${(distanceKm * 1000).round()} m'
              : '${distanceKm.toStringAsFixed(1)} km';
    } else if (userAddress?.latitude != null &&
        userAddress?.longitude != null &&
        store.latitude != null &&
        store.longitude != null) {
      try {
        final distMeters = Geolocator.distanceBetween(
          userAddress!.latitude!,
          userAddress.longitude!,
          store.latitude!,
          store.longitude!,
        );
        if (distMeters < 1000) {
          distanceText = '${distMeters.round()} m';
        } else {
          distanceText = '${(distMeters / 1000).toStringAsFixed(1)} km';
        }
      } catch (e) {
        // Ignora erro de calculo
      }
    }

    // ✅ VALIDAR STATUS DA LOJA (Aberto/Fechado)
    final storeStatus = StoreStatusService.validateStoreStatus(store);
    final isClosed = !storeStatus.canReceiveOrders;

    // Texto de "Abre X" ou "Fecha Y"
    final statusMsg = StoreStatusHelper(hours: store.hours).statusMessage;

    // ✅ DADOS DE ENTREGA E PEDIDO MÍNIMO
    final minOrderVal = store.getMinOrderForDelivery();
    final hasMinOrder = minOrderVal > 0;

    // Tenta pegar regra ativa para tempo e preço
    final activeDeliveryRule =
        store.deliveryFeeRules
            .where((r) => r.isActive && r.deliveryMethod == 'delivery')
            .firstOrNull;

    // Tempo de entrega (Prioriza regra, depois config da loja)
    String deliveryTimeText;
    if (activeDeliveryRule?.estimatedMinMinutes != null) {
      deliveryTimeText =
          '${activeRuleValue(activeDeliveryRule?.estimatedMinMinutes)}-${activeRuleValue(activeDeliveryRule?.estimatedMaxMinutes)} min';
    } else {
      deliveryTimeText =
          store.store_operation_config != null
              ? '${store.store_operation_config!.deliveryEstimatedMin}-${store.store_operation_config!.deliveryEstimatedMax} min'
              : '30-45 min';
    }

    // Frete grátis a partir de X (só exibe se free_delivery_threshold > 0)
    // ✅ CORREÇÃO: O frete real é calculado dinamicamente baseado no endereço e regras
    // Aqui só exibimos se há promoção de "frete grátis a partir de X"
    // ✅ OBSERVAÇÃO: freeDeliveryThreshold já vem em REAIS (conversão feita no DeliveryFeeRule.fromJson)
    String? freeDeliveryText;
    if (activeDeliveryRule != null) {
      final freeThreshold = activeDeliveryRule.freeDeliveryThreshold ?? 0;

      // Só mostra se tiver threshold de frete grátis configurado e > 0
      if (freeThreshold > 0) {
        // ✅ CORREÇÃO: Valor já está em REAIS, não precisa dividir por 100
        freeDeliveryText =
            'Frete grátis a partir de ${freeThreshold.toCurrency()}';
      }
      // Se freeThreshold é 0 ou nulo, não mostra nada (frete será calculado dinamicamente)
    }

    return SliverAppBar(
      expandedHeight: isDesktop ? 220 : 200,
      pinned:
          false, // ✅ Não fixa no topo - apenas o header sticky deve ficar fixo
      backgroundColor: theme.sidebarBackgroundColor,
      elevation: 0,
      leading:
          (!isDesktop && GoRouter.of(context).canPop())
              ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
                onPressed: () => GoRouter.of(context).pop(),
              )
              : null,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.search,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
          onPressed: () => GoRouter.of(context).push('/search'),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Imagem de Fundo
            ColorFiltered(
              colorFilter:
                  isClosed
                      ? const ColorFilter.mode(
                        Colors.grey,
                        BlendMode.saturation,
                      )
                      : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      ),
              child: Image.network(
                store.banner?.url ??
                    'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png',
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(color: Colors.grey[300]),
              ),
            ),

            // 2. Overlay Gradiente para legibilidade
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.4), // Gradiente mais suave
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.4, 0.7, 1.0],
                ),
              ),
            ),

            // 3. Conteúdo (Info da Loja)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isClosed)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Loja fechada • $statusMsg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Logo com borda
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              store.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 2),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Linha de Detalhes (Correções mantidas: Distância, MinOrder, Tempo)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                // Rating
                                if (store.ratingsSummary != null) ...[
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  Text(
                                    store.ratingsSummary!.averageRating
                                        .toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    '•',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],

                                // Distância
                                if (distanceText != null) ...[
                                  Text(
                                    distanceText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    '•',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],

                                // Tempo
                                Text(
                                  deliveryTimeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),

                                // Frete Grátis (só exibe se tiver promoção configurada)
                                if (freeDeliveryText != null) ...[
                                  const Text(
                                    '•',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    freeDeliveryText,
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (hasMinOrder)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Pedido mínimo ${minOrderVal.toCurrency()}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Ícone de Info/Detalhes
                      IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                        ),
                        onPressed: () => context.go('/store-details', extra: 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper safe value
  dynamic activeRuleValue(dynamic val) => val ?? 0;
}
