// lib/pages/order/order_tracking_page.dart
// ✅ Tela de acompanhamento do pedido estilo Menuhub
// Exibe mapa, status, endereço e detalhes do pedido

import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/models/order.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/pages/orders/widgets/wave_progress_indicator.dart';
import 'package:intl/intl.dart';

/// Tela de acompanhamento de pedido estilo Menuhub
/// Exibe mapa no topo (para delivery), status, endereço e detalhes
class OrderTrackingPage extends StatelessWidget {
  final Order order;
  final PlatformPaymentMethod? paymentMethod;

  const OrderTrackingPage({super.key, required this.order, this.paymentMethod});

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    final isDelivery = order.deliveryType == 'delivery';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // ✅ AppBar com mapa para delivery
          SliverAppBar(
            expandedHeight: isDelivery ? 250 : 150,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
              onPressed: () => context.go('/'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Lógica de ajuda
                },
                child: const Text(
                  'Ajuda',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  // Lógica de chat
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background:
                  isDelivery && store != null
                      ? _buildMap(store)
                      : _buildPickupHeader(store, theme),
            ),
          ),

          // ✅ Card de Status sobreposto ao mapa
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: _buildStatusCard(context, theme),
            ),
          ),

          // ✅ Conteúdo principal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Endereço de entrega/retirada
                  _buildAddressSection(context, theme, store),

                  const SizedBox(height: 24),

                  // Detalhes do pedido
                  _buildOrderDetailsSection(context, theme),

                  const SizedBox(height: 24),

                  // Itens do pedido
                  _buildItemsSection(context, theme),

                  const SizedBox(height: 100), // Espaço para bottom bar
                ],
              ),
            ),
          ),
        ],
      ),

      // ✅ Bottom bar com botões de ação
      bottomNavigationBar: _buildBottomBar(context, theme),
    );
  }

  /// Mapa com localização da loja/entrega
  Widget _buildMap(dynamic store) {
    final lat = store?.latitude ?? -23.5505;
    final lng = store?.longitude ?? -46.6333;

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(lat, lng),
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.menuhub.totem',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(lat, lng),
              width: 50,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Header para retirada (sem mapa)
  Widget _buildPickupHeader(dynamic store, ThemeData theme) {
    return Container(
      color: theme.primaryColor.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 60, color: theme.primaryColor),
            const SizedBox(height: 8),
            Text(
              store?.name ?? 'Loja',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card de status do pedido
  Widget _buildStatusCard(BuildContext context, ThemeData theme) {
    final statusInfo = _getStatusInfo(order.orderStatus);

    // Estimativa de entrega
    final eta = order.delivery.expectedDeliveryTime;
    final etaEnd = order.delivery.expectedDeliveryTimeEnd;
    String timeRange = 'Pendente';
    if (eta != null) {
      final start = DateFormat('HH:mm').format(eta);
      final end =
          etaEnd != null
              ? DateFormat('HH:mm').format(etaEnd)
              : DateFormat(
                'HH:mm',
              ).format(eta.add(const Duration(minutes: 15)));
      timeRange = '$start - $end';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  statusInfo['text'] as String,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F3E3E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Wave Progress
          WaveProgressIndicator(
            value: _getProgressValue(order.orderStatus),
            waveColor: Colors.green,
            baseColor: const Color(0xFFF2F2F2),
            height: 4,
          ),
          const SizedBox(height: 16),
          // Previsão
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Previsão de entrega: $timeRange',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF717171),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Color(0xFF717171)),
            ],
          ),
          const Divider(height: 32),
          // Código de entrega
          Row(
            children: [
              const Text(
                'Código de entrega',
                style: TextStyle(fontSize: 14, color: Color(0xFF717171)),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.help_outline,
                size: 16,
                color: Color(0xFF717171),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.keyboard,
                      size: 16,
                      color: Color(0xFF3F3E3E),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.deliveryCode ?? '7201',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Barra de progresso do pedido
  Widget _buildProgressBar(ThemeData theme) {
    final statuses =
        order.deliveryType == 'delivery'
            ? ['pending', 'preparing', 'ready', 'on_route', 'delivered']
            : ['pending', 'preparing', 'ready', 'delivered'];

    final currentIndex = statuses.indexOf(order.orderStatus);
    final progress = currentIndex < 0 ? 0 : currentIndex;

    return Row(
      children: List.generate(statuses.length, (index) {
        final isActive = index <= progress;
        final isCurrent = index == progress;

        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < statuses.length - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: isActive ? theme.primaryColor : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
            child:
                isCurrent
                    ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(seconds: 2),
                      builder: (context, value, child) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      },
                    )
                    : null,
          ),
        );
      }),
    );
  }

  /// Seção de endereço
  Widget _buildAddressSection(
    BuildContext context,
    ThemeData theme,
    dynamic store,
  ) {
    final isDelivery = order.deliveryType == 'delivery';
    final address = order.delivery.deliveryAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Endereço de entrega',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3F3E3E),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: Color(0xFF3F3E3E), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${address.streetName}, ${address.streetNumber ?? 'S/N'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${address.neighborhood} - ${address.city}, ${address.state}',
                    style: const TextStyle(
                      color: Color(0xFF717171),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isDelivery) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Esta entrega é feita pela loja e não pode ser rastreada',
                    style: TextStyle(fontSize: 14, color: Color(0xFF717171)),
                  ),
                ),
                Icon(Icons.help_outline, size: 18, color: Color(0xFF717171)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Seção de detalhes do pedido
  Widget _buildOrderDetailsSection(BuildContext context, ThemeData theme) {
    final totalFormatted = UtilBrasilFields.obterReal(
      order.bag.total.value / 100.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalhes do pedido',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3F3E3E),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => context.push('/order/${order.id}/summary', extra: order),
          child: Row(
            children: [
              // Logo da Loja
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: order.merchant.logo ?? '',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.store),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.merchant.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Pedido Nº ${order.sequentialId} • ${order.items.length} ${order.items.length == 1 ? 'item' : 'itens'}',
                      style: const TextStyle(
                        color: Color(0xFF717171),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Pagamento
        Row(
          children: [
            if (order.payments.primaryMethod != null)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getPaymentIcon(order.payments.primaryMethod!.method),
                  size: 20,
                  color: const Color(0xFF3F3E3E),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pagamento na entrega • ${order.payments.primaryMethod?.method.name.toUpperCase() == 'CREDIT_CARD' ? 'Crédito' : 'Dinheiro'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    order.payments.primaryMethod?.displayName ?? 'Mastercard',
                    style: const TextStyle(
                      color: Color(0xFF717171),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total com entrega',
              style: TextStyle(fontSize: 16, color: Color(0xFF3F3E3E)),
            ),
            Text(
              totalFormatted,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF3F3E3E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Chat Button
        Center(
          child: TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            label: const Text(
              'Chat com a loja',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
          ),
        ),
      ],
    );
  }

  IconData _getPaymentIcon(dynamic type) {
    final typeStr = type.toString().toLowerCase();
    if (typeStr.contains('credit')) return Icons.credit_card;
    if (typeStr.contains('cash') || typeStr.contains('dinheiro'))
      return Icons.payments;
    return Icons.payment;
  }

  /// Seção de itens do pedido
  Widget _buildItemsSection(BuildContext context, ThemeData theme) {
    final totalCents = order.charge?.grandTotal ?? 0;
    final totalFormatted = UtilBrasilFields.obterReal(totalCents / 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Resumo do pedido',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              totalFormatted,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children:
                order.products.map((product) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${product.quantity}x',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          UtilBrasilFields.obterReal(
                            product.totalPrice / 100.0,
                          ),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  /// Bottom bar com promo
  Widget _buildBottomBar(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.percent, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vai uma bebida enquanto espera?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Entrega grátis - 35 min',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '23:15',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_up, color: Colors.white),
          ],
        ),
      ),
    );
  }

  /// Retorna informações do status
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return {
          'text': 'Aguardando confirmação da loja',
          'color': Colors.orange,
        };
      case 'confirmed':
        return {'text': 'Seu pedido foi confirmado', 'color': Colors.blue};
      case 'preparing':
        return {
          'text': 'Seu pedido está sendo preparado',
          'color': Colors.blue,
        };
      case 'ready':
        return {'text': 'Pedido pronto!', 'color': Colors.green};
      case 'on_route':
      case 'out_for_delivery':
        return {'text': 'Pedido saiu para entrega', 'color': Colors.purple};
      case 'delivered':
      case 'finalized':
      case 'concluded':
        return {'text': 'Pedido entregue!', 'color': Colors.green};
      case 'canceled':
      case 'cancelled':
        return {'text': 'Pedido cancelado', 'color': Colors.red};
      default:
        return {'text': 'Processando...', 'color': Colors.grey};
    }
  }

  double _getProgressValue(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0.15;
      case 'confirmed':
        return 0.3;
      case 'preparing':
        return 0.5;
      case 'ready':
        return 0.7;
      case 'on_route':
      case 'out_for_delivery':
        return 0.85;
      case 'delivered':
      case 'finalized':
      case 'concluded':
        return 1.0;
      default:
        return 0.0;
    }
  }
}
