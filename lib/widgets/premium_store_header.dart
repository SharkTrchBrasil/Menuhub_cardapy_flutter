import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/services/store_status_service.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/core/extensions.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';

import 'package:totem/helpers/store_hours_helper.dart';

class PremiumStoreHeader extends StatelessWidget {
  const PremiumStoreHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final storeState = context.watch<StoreCubit>().state;
    final store = storeState.store;
    final addressState = context.watch<AddressCubit>().state;
    final userAddress = addressState.selectedAddress;

    if (store == null) return const SizedBox.shrink();

    // CALCULAR DISTÂNCIA (Copiado do StoreCardData para manter consistência)
    String? distanceText;
    if (userAddress?.latitude != null &&
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
        distanceText =
            distMeters < 1000
                ? '${distMeters.round()} m'
                : '${(distMeters / 1000).toStringAsFixed(1)} km';
      } catch (e) {
        // Ignora
      }
    }

    // DADOS DE ENTREGA
    final minOrderVal = store.getMinOrderForDelivery();
    final activeDeliveryRule =
        store.deliveryFeeRules
            .where((r) => r.isActive && r.deliveryMethod == 'delivery')
            .firstOrNull;

    String deliveryTimeText;
    if (activeDeliveryRule?.estimatedMinMinutes != null) {
      deliveryTimeText =
          '${activeDeliveryRule?.estimatedMinMinutes ?? 0}-${activeDeliveryRule?.estimatedMaxMinutes ?? 0} min';
    } else {
      deliveryTimeText =
          store.store_operation_config != null
              ? '${store.store_operation_config!.deliveryEstimatedMin}-${store.store_operation_config!.deliveryEstimatedMax} min'
              : '30-45 min';
    }

    // Lógica de Loja Aberta/Fechada
    final statusHelper = StoreStatusHelper(hours: store.hours);
    final isClosed = !statusHelper.isOpen;
    final storeStatusMsg = statusHelper.statusMessage;

    final deliveryFeeState = context.watch<DeliveryFeeCubit>().state;
    final closingSoonInfo = StoreStatusService.getClosingSoonInfo(store);

    // LÓGICA DE FRETE (Dinâmica baseada no estado)
    String shippingText = 'A calcular';
    Color shippingColor = Colors.black;

    if (userAddress == null) {
      // Verifica se a loja é "Sempre Grátis" mesmo sem endereço (Threshold 0)
      if (activeDeliveryRule != null &&
          activeDeliveryRule.freeDeliveryThreshold == 0) {
        shippingText = 'Grátis';
        shippingColor = Colors.green.shade700;
      } else {
        shippingText = 'Frete a calcular';
      }
    } else {
      if (deliveryFeeState is DeliveryFeeLoaded) {
        if (deliveryFeeState.deliveryFee == 0) {
          shippingText = 'Grátis';
          shippingColor = Colors.green.shade700;
        } else {
          shippingText = deliveryFeeState.deliveryFee.toCurrency();
        }
      } else if (deliveryFeeState is DeliveryFeeLoading) {
        shippingText = 'Calculando...';
      } else if (deliveryFeeState is DeliveryFeeError) {
        shippingText = 'Indisponível';
      }
    }

    return Container(
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 1. Imagem de Banner
          ColorFiltered(
            colorFilter:
                isClosed
                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                    : const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    ),
            child: Opacity(
              opacity: isClosed ? 0.5 : 1.0,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                      store.banner?.url ??
                          'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),

          // 2. Botões de Ação no Topo (Voltar, Favoritar, Buscar)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _HeaderActionButton(
                  icon: Icons.search,
                  onTap: () => context.push('/search'),
                ),
              ],
            ),
          ),

          // 3. Card de Informações (Sobreposto)
          Padding(
            padding: const EdgeInsets.only(
              top: 150,
            ), // Aumentado o overlap (Banner 200 - 150 = 50px de overlap)
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 45), // Espaço para a logo
                    // Nome e Info Secundária
                    InkWell(
                      onTap: () => context.push('/store-details', extra: 1),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    store.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isClosed ? Colors.grey : Colors.black,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 24,
                                  color: isClosed ? Colors.grey : Colors.black,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${distanceText ?? "Distância indisponível"}${minOrderVal > 0 ? " • Min ${minOrderVal.toCurrency()}" : ""}',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    isClosed
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(
                      height: 1,
                      thickness: 0.3,
                      color: Colors.grey,
                    ),

                    // Avaliação
                    InkWell(
                      onTap: () => context.push('/store-details', extra: 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 16.0,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 18,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '4,7',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(145 avaliações)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.chevron_right,
                              size: 22,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Entrega e Tempo (Ocultar se fechada)
                    if (!isClosed) ...[
                      const Divider(
                        height: 1,
                        thickness: 0.3,
                        color: Colors.grey,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Padrão • $deliveryTimeText • ',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  shippingText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: shippingColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mais opções disponíveis na sacola',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Aviso de Loja Fechando OU Fechada
                    if (isClosed || closingSoonInfo != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: Text(
                          isClosed
                              ? 'Loja fechada • $storeStatusMsg'
                              : 'Loja fechando • Peça até às ${_formatTime(closingSoonInfo!['closingTime'])}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 4. LOGO FLUTUANTE (Tamanho aumentado para 80)
          Positioned(
            top: 110, // Centralizada na borda (Card em 150 - (Logo 80 / 2))
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: ColorFiltered(
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
                  child: Opacity(
                    opacity: isClosed ? 0.7 : 1.0,
                    child:
                        store.image?.url != null
                            ? Image.network(store.image!.url, fit: BoxFit.cover)
                            : Container(
                              color: Colors.orange.shade100,
                              child: const Icon(
                                Icons.store,
                                color: Colors.orange,
                              ),
                            ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
