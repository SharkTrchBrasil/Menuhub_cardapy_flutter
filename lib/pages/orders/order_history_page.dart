// lib/pages/orders/order_history_page.dart
// ✅ Página de histórico de pedidos estilo Menuhub

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/order.dart';
import 'package:totem/pages/orders/order_detail_page.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/core/helpers/side_panel.dart';
import 'package:totem/core/services/timezone_service.dart';

import '../../core/di.dart';
import '../../cubit/auth_cubit.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ProfileCubit(
          customerRepository: getIt<CustomerRepository>(),
          orderRepository: getIt<OrderRepository>(),
        );
        // Carrega histórico se tiver cliente
        final customer = context.read<AuthCubit>().state.customer;
        if (customer?.id != null) {
          cubit.loadOrderHistory(customer!.id!);
        }
        return cubit;
      },
      child: const _OrderHistoryContent(),
    );
  }
}

class _OrderHistoryContent extends StatelessWidget {
  const _OrderHistoryContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ProfileStatus.error) {
            return _buildErrorState(context, state);
          }

          final orders = state.filteredOrders;

          if (orders.isEmpty) {
            return _buildEmptyState(context);
          }

          // Agrupa pedidos por status e data
          final inProgressOrders =
              orders
                  .where(
                    (o) =>
                        ![
                          'delivered',
                          'finalized',
                          'concluded',
                          'canceled',
                          'cancelled',
                        ].contains(o.orderStatus.toLowerCase()),
                  )
                  .toList();
          final historyOrders =
              orders
                  .where(
                    (o) => [
                      'delivered',
                      'finalized',
                      'concluded',
                      'canceled',
                      'cancelled',
                    ].contains(o.orderStatus.toLowerCase()),
                  )
                  .toList();

          return CustomScrollView(
            slivers: [
              // ✅ Seção "Em andamento" - Só mostra se houver pedidos
              if (inProgressOrders.isNotEmpty) ...[
                _buildSectionTitle('Em andamento'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children:
                          inProgressOrders
                              .map(
                                (order) => _InProgressOrderCard(order: order),
                              )
                              .toList(),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ✅ Seção "Histórico" agrupado por data
              if (historyOrders.isNotEmpty) ...[
                _buildSectionTitle('Histórico'),
                ..._buildHistoryByDate(context, historyOrders),
              ],

              // Espaço extra no final
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ProfileState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            state.errorMessage ?? 'Erro ao carregar pedidos',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final customer = context.read<ProfileCubit>().state.customer;
              if (customer != null) {
                context.read<ProfileCubit>().loadOrderHistory(customer.id!);
              }
            },
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            'Nenhum pedido ainda',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seus pedidos aparecerão aqui',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF717171),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHistoryByDate(BuildContext context, List<Order> orders) {
    // Agrupa por data
    final Map<String, List<Order>> groupedOrders = {};
    final timezone =
        context.read<StoreCubit>().state.store?.timezone ?? "America/Sao_Paulo";

    for (final order in orders) {
      // Usa a data do pedido para agrupar
      final dateKey = TimezoneService.formatStoreDateTime(
        order.createdAt,
        timezone,
        format: "EEEE, dd/MM/yyyy",
      );
      groupedOrders.putIfAbsent(dateKey, () => []).add(order);
    }

    final widgets = <Widget>[];

    groupedOrders.forEach((date, dateOrders) {
      // Título da data
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              date,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
        ),
      );

      // Pedidos dessa data
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children:
                  dateOrders
                      .map((order) => _HistoryOrderCard(order: order))
                      .toList(),
            ),
          ),
        ),
      );
    });

    return widgets;
  }
}

/// Card para pedido em andamento (estilo Menuhub)
class _InProgressOrderCard extends StatelessWidget {
  final Order order;

  const _InProgressOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    final now = DateTime.now();
    final estimatedMin = now.add(const Duration(minutes: 15));
    final estimatedMax = now.add(const Duration(minutes: 25));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openOrderDetails(context, order),
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
                // Header: Logo + nome + status
                Row(
                  children: [
                    _buildStoreLogo(store?.image?.url),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store?.name ?? 'Loja',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getStatusLabel(order.orderStatus),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(order.orderStatus),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Barra de progresso e previsão
                Row(
                  children: [
                    Text(
                      'Previsão: ',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    Text(
                      '${estimatedMin.hour}:${estimatedMin.minute.toString().padLeft(2, '0')} - ${estimatedMax.hour}:${estimatedMax.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _getProgressValue(order.orderStatus),
                    backgroundColor: Colors.grey[100],
                    valueColor:
                        AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreLogo(String? logoUrl) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child:
          logoUrl != null && logoUrl.isNotEmpty
              ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: logoUrl,
                  fit: BoxFit.cover,
                  errorWidget:
                      (_, __, ___) =>
                          Icon(Icons.store, color: Colors.grey[400]),
                ),
              )
              : Icon(Icons.store, color: Colors.grey[400]),
    );
  }

  void _openOrderDetails(BuildContext context, Order order) {
    showResponsiveSidePanel(
      context,
      OrderDetailPage(order: order),
      useFullScreenOnDesktop: false,
    );
  }
}

/// Card para pedido no histórico (estilo Menuhub)
class _HistoryOrderCard extends StatelessWidget {
  final Order order;

  const _HistoryOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openOrderDetails(context, order),
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
                // Header: Logo + nome + status
                Row(
                  children: [
                    _buildStoreLogo(store?.image?.url),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store?.name ?? 'Loja',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
                                color: _getStatusColor(order.orderStatus),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Itens
                ...order.items
                    .take(2)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Imagem do produto
                            if (item.imageUrl != null)
                              Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: item.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const SizedBox(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                if (order.items.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${order.items.length - 2} itens',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreLogo(String? logoUrl) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child:
          logoUrl != null && logoUrl.isNotEmpty
              ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: logoUrl,
                  fit: BoxFit.cover,
                  errorWidget:
                      (_, __, ___) =>
                          Icon(Icons.store, color: Colors.grey[400]),
                ),
              )
              : Icon(Icons.store, color: Colors.grey[400]),
    );
  }

  void _openOrderDetails(BuildContext context, Order order) {
    showResponsiveSidePanel(
      context,
      OrderDetailPage(order: order),
      useFullScreenOnDesktop: false,
    );
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
    case 'pending':
      return Colors.orange;
    case 'confirmed':
      return Colors.blue;
    case 'preparing':
      return Colors.purple;
    case 'ready':
      return Colors.cyan;
    case 'dispatched':
    case 'out_for_delivery':
      return Colors.indigo;
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return Colors.green;
    case 'canceled':
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
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
    case 'dispatched':
    case 'out_for_delivery':
      return Icons.delivery_dining;
    case 'preparing':
      return Icons.restaurant;
    case 'ready':
      return Icons.check_circle_outline;
    case 'confirmed':
      return Icons.check;
    case 'pending':
      return Icons.access_time;
    default:
      return Icons.info_outline;
  }
}

double _getProgressValue(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 0.15;
    case 'confirmed':
      return 0.30;
    case 'preparing':
      return 0.50;
    case 'ready':
      return 0.75;
    case 'dispatched':
    case 'out_for_delivery':
      return 0.90;
    case 'delivered':
    case 'finalized':
    case 'concluded':
      return 1.0;
    case 'canceled':
    case 'cancelled':
      return 0.0;
    default:
      return 0.15;
  }
}
