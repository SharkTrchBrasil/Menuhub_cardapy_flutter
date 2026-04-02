import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/models/order.dart';
import 'package:totem/cubit/orders_cubit.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/core/services/timezone_service.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/pages/orders/widgets/wave_progress_indicator.dart';

/// Orders Content Widget
/// Layout inspirado no Menuhub com seções "Em andamento" e "Histórico"
class OrdersContent extends StatelessWidget {
  final bool isDesktop;

  const OrdersContent({super.key, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, state) {
        if (state.status == OrdersStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == OrdersStatus.error) {
          return _buildErrorState(context, state);
        }

        final orders = state.orders;

        if (orders.isEmpty) {
          return _buildEmptyState(context);
        }

        // Usar os getters do OrdersState
        final activeOrders = state.activeOrders;
        final historyOrders = state.historyOrders;

        // Agrupar histórico por data
        final groupedHistory = _groupOrdersByDate(context, historyOrders);

        return ListView(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          children: [
            // Seção "Em andamento"
            if (activeOrders.isNotEmpty) ...[
              _buildSectionTitle('Em andamento'),
              const SizedBox(height: 12),
              ...activeOrders.map(
                (order) => _ActiveOrderCard(order: order, isDesktop: isDesktop),
              ),
              const SizedBox(height: 24),
            ],

            // Seção "Histórico"
            if (historyOrders.isNotEmpty) ...[
              _buildSectionTitle('Histórico'),
              const SizedBox(height: 12),
              ...groupedHistory.entries.expand(
                (entry) => [
                  _buildDateHeader(entry.key),
                  ...entry.value.map(
                    (order) =>
                        _HistoryOrderCard(order: order, isDesktop: isDesktop),
                  ),
                ],
              ),
            ],

            // Se não há pedidos em nenhuma categoria
            if (activeOrders.isEmpty && historyOrders.isEmpty)
              _buildEmptyState(context),
          ],
        );
      },
    );
  }

  Map<String, List<Order>> _groupOrdersByDate(
    BuildContext context,
    List<Order> orders,
  ) {
    final Map<String, List<Order>> grouped = {};
    final store = context.read<StoreCubit>().state.store;
    final timezone = store?.timezone ?? 'America/Sao_Paulo';

    for (final order in orders) {
      // ✅ createdAt agora é non-nullable no modelo Menuhub
      final dateKey = TimezoneService.formatStoreDateTime(
        order.createdAt,
        timezone,
        format: 'EEEE, dd/MM/yyyy',
      );
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(order);
    }

    return grouped;
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: isDesktop ? 17 : 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF717171),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        date,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isLoggedIn = authState.customer != null;

        return Stack(
          children: [
            // Conteúdo principal centralizado
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✅ Ilustração de sacola dormindo (estilo Menuhub)
                    _buildSleepingBagIllustration(),

                    SizedBox(height: isDesktop ? 32 : 24),

                    // ✅ Título principal
                    Text(
                      'Seus pedidos vão aparecer aqui',
                      style: TextStyle(
                        fontSize: isDesktop ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // ✅ Subtítulo explicativo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Aqui você pode consultar pedidos em andamento, seu histórico e adicionar um pedido antigo à sacola',
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Espaço extra para o card de login não sobrepor
                    if (!isLoggedIn) const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // ✅ Card flutuante de login (apenas quando não logado)
            if (!isLoggedIn)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildLoginCard(context),
              ),
          ],
        );
      },
    );
  }

  // ✅ Ilustração de sacola dormindo (estilo Menuhub)
  Widget _buildSleepingBagIllustration() {
    return Container(
      width: isDesktop ? 180 : 150,
      height: isDesktop ? 180 : 150,
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sacola principal
          Icon(
            Icons.shopping_bag_outlined,
            size: isDesktop ? 80 : 70,
            color: Colors.pink.shade300,
          ),
          // Zzz's dormindo
          Positioned(
            top: isDesktop ? 25 : 20,
            right: isDesktop ? 25 : 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'z',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade400,
                  ),
                ),
                Text(
                  'z',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade400,
                  ),
                ),
                Text(
                  'Z',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade400,
                  ),
                ),
              ],
            ),
          ),
          // Olhinhos fechados (dormindo)
          Positioned(
            top: isDesktop ? 75 : 65,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.pink.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.pink.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          // Boquinha dormindo
          Positioned(
            top: isDesktop ? 90 : 80,
            child: Container(
              width: 8,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.pink.shade400,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Card de login flutuante (estilo Menuhub)
  Widget _buildLoginCard(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explore mais com sua conta MenuHub',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      context.push('/onboarding');
                    },
                    child: Text(
                      'Entrar ou cadastrar-se',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, OrdersState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            state.errorMessage ?? 'Erro ao carregar pedidos',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final customer = context.read<AuthCubit>().state.customer;
              if (customer != null) {
                context.read<OrdersCubit>().loadOrders(customer.id!);
              }
            },
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

/// Card para pedidos em andamento
class _ActiveOrderCard extends StatelessWidget {
  final Order order;
  final bool isDesktop;

  const _ActiveOrderCard({required this.order, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/order/${order.id}', extra: order),
          splashColor: Colors.black.withOpacity(0.05),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header com avatar e info da loja
                Row(
                  children: [
                    _buildStoreAvatar(order.merchant.logo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.merchant.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.statusLabel,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Previsão de entrega
                _buildDeliveryInfo(),

                const SizedBox(height: 16),

                // Barra de progresso (Verde conforme o print)
                _buildProgressBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    // Usa a previsão real do pedido se disponível
    String deliveryTime = '30 - 45 min';

    if (order.delivery?.estimatedTimeOfArrival != null) {
      final eta = order.delivery!.estimatedTimeOfArrival!;
      final now = DateTime.now();
      final diff = eta.deliversAt.difference(now);

      if (diff.inMinutes > 0) {
        deliveryTime = '${diff.inMinutes} min';
      } else {
        deliveryTime = 'A caminho';
      }
    }

    return Row(
      children: [
        Text(
          'Previsão de entrega: ',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Text(
          deliveryTime,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = _getProgressValue(order.orderStatus);

    return Column(
      children: [
        WaveProgressIndicator(
          value: progress,
          waveColor: Colors.green,
          baseColor: Colors.grey.shade100,
          height: 4,
        ),
      ],
    );
  }
}

/// Card para pedidos no histórico
class _HistoryOrderCard extends StatelessWidget {
  final Order order;
  final bool isDesktop;

  const _HistoryOrderCard({required this.order, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final isCanceled =
        order.orderStatus.toLowerCase() == 'canceled' ||
        order.orderStatus.toLowerCase() == 'cancelled';
    final isDelivered =
        order.orderStatus.toLowerCase() == 'delivered' ||
        order.orderStatus.toLowerCase() == 'finalized' ||
        order.orderStatus.toLowerCase() == 'concluded';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/order/${order.id}', extra: order),
          splashColor: Colors.black.withOpacity(0.05),
          highlightColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Foto da loja + Nome + Status
                Row(
                  children: [
                    _buildStoreAvatar(order.merchant.logo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.merchant.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3F3E3E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _getStatusLabel(order.orderStatus),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _getStatusColor(order.orderStatus),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _getStatusIcon(order.orderStatus),
                                size: 14,
                                color: isCanceled ? Colors.grey : Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Corpo: Itens e fotos empilhadas à direita
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lista de itens
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...order.items
                              .take(3)
                              .map((item) => _buildProductItem(item)),
                          if (order.items.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '+ ${order.items.length - 3} itens',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Fotos empilhadas (estilo iFood)
                    Builder(
                      builder: (context) {
                        // Pega os 3 primeiros itens, independente de terem imagem ou não
                        final itemsToShow = order.items.take(3).toList();
                        if (itemsToShow.isEmpty) return const SizedBox();

                        return SizedBox(
                          width: 80,
                          height: 48,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.centerRight,
                            children:
                                itemsToShow.reversed.toList().asMap().entries.map((
                                  entry,
                                ) {
                                  final item = entry.value;
                                  final imgUrl = _formatImageUrl(item.logoUrl);
                                  final hasImage = imgUrl.isNotEmpty;

                                  return Positioned(
                                    right: entry.key * 15.0,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.12,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child:
                                            hasImage
                                                ? CachedNetworkImage(
                                                  imageUrl: imgUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder:
                                                      (
                                                        context,
                                                        url,
                                                      ) => Container(
                                                        color: Colors.grey[100],
                                                        child: const Center(
                                                          child: SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                  errorWidget:
                                                      (
                                                        context,
                                                        url,
                                                        error,
                                                      ) => Container(
                                                        color: Colors.grey[100],
                                                        child: const Icon(
                                                          Icons.fastfood,
                                                          size: 18,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                )
                                                : Container(
                                                  color: Colors.grey[100],
                                                  child: const Icon(
                                                    Icons.fastfood,
                                                    size: 18,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Avaliação (apenas se concluído)
                if (isDelivered) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final bool isRated =
                          order.details.reviewed || order.storeRating != null;
                      final int ratedStars = order.storeRating?.stars ?? 0;

                      return InkWell(
                        onTap: () {
                          if (!isRated) {
                            context.push(
                              '/order/${order.id}/evaluate',
                              extra: order,
                            );
                          } else {
                            context.push('/order/${order.id}', extra: order);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: List.generate(
                                5,
                                (index) => Icon(
                                  Icons.star,
                                  size: 18,
                                  color:
                                      isRated
                                          ? (index < ratedStars
                                              ? const Color(0xFFFDCB3F)
                                              : Colors.grey.shade300)
                                          : Colors.grey.shade300,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  isRated
                                      ? 'Avaliação enviada'
                                      : 'Avalie seu pedido',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!isRated)
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Funções Auxiliares Compartilhadas ---

Widget _buildStoreAvatar(String? logoUrl) {
  final fullUrl = _formatImageUrl(logoUrl);
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      shape: BoxShape.circle,
    ),
    child:
        fullUrl.isNotEmpty
            ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Icon(
                      Icons.store,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
              ),
            )
            : Icon(Icons.store, color: Colors.grey.shade400, size: 24),
  );
}

String _formatImageUrl(String? url) {
  if (url == null ||
      url.isEmpty ||
      url.toString().toLowerCase().contains('none'))
    return '';
  final trimmed = url.trim();
  if (trimmed.startsWith('http')) return trimmed;

  // Limpa barra inicial se houver
  String path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;

  // Prepend S3 base URL
  return 'https://menuhub-dev.s3.us-east-1.amazonaws.com/$path';
}

String _getStatusText(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Aguardando confirmação';
    case 'confirmed':
      return 'Pedido confirmado';
    case 'preparing':
      return 'Preparando seu pedido';
    case 'ready':
      return 'Pronto para entrega';
    case 'dispatched':
    case 'out_for_delivery':
      return 'Saiu para entrega';
    default:
      return 'Em andamento';
  }
}

String _getStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Pendente';
    case 'confirmed':
      return 'Confirmado';
    case 'preparing':
      return 'Em preparo';
    case 'ready':
      return 'Pronto para entrega';
    case 'dispatched':
    case 'out_for_delivery':
      return 'Em entrega';
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return 'Pedido concluído';
    case 'canceled':
    case 'cancelled':
      return 'Pedido cancelado';
    default:
      return status;
  }
}

Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'canceled':
    case 'cancelled':
      return Colors.grey;
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return Colors.grey.shade600;
    default:
      return const Color(0xFFEA1D2C); // Vermelho iFood
  }
}

IconData _getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'canceled':
    case 'cancelled':
      return Icons.cancel;
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return Icons.check_circle;
    default:
      return Icons.access_time_filled;
  }
}

Widget _buildProductItem(BagItem item) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        // Quantidade em caixa cinza pequena
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${item.quantity}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF3F3E3E),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Nome do produto
        Expanded(
          child: Text(
            item.name,
            style: const TextStyle(fontSize: 15, color: Color(0xFF717171)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

double _getProgressValue(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 0.1;
    case 'confirmed':
      return 0.2;
    case 'preparing':
      return 0.35;
    case 'ready':
      return 0.5;
    case 'driver_on_way':
      return 0.55;
    case 'driver_arrived':
      return 0.6;
    case 'out_for_delivery':
    case 'dispatched':
      return 0.7;
    case 'arriving':
      return 0.8;
    case 'driver_at_customer':
      return 0.9;
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return 1.0;
    case 'canceled':
    case 'cancelled':
    case 'cancellation_requested':
    case 'delivery_failed':
    case 'order_returned':
      return 0.0;
    default:
      return 0.0;
  }
}
