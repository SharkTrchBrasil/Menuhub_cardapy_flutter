// lib/pages/orders/order_history_page.dart
// ✅ Página de histórico de pedidos estilo iFood

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:totem/core/helpers/side_panel.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/models/order.dart';
import 'package:totem/pages/order/order_details_page.dart';
import 'package:totem/pages/profile/profile_cubit.dart';

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
          final inProgressOrders = orders.where((o) => 
              !['delivered', 'finalized', 'canceled'].contains(o.orderStatus.toLowerCase())).toList();
          final historyOrders = orders.where((o) => 
              ['delivered', 'finalized', 'canceled'].contains(o.orderStatus.toLowerCase())).toList();

          return CustomScrollView(
            slivers: [
              // ✅ Seção "Em andamento"
              if (inProgressOrders.isNotEmpty) ...[
                _buildSectionTitle('Em andamento'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: inProgressOrders.map((order) => 
                        _InProgressOrderCard(order: order)).toList(),
                    ),
                  ),
                ),
              ],
              
              // ✅ Banner de cupons
              SliverToBoxAdapter(
                child: _buildCouponBanner(context),
              ),
              
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCouponBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.pink[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Você ganhou cupons grátis aqui',
            style: TextStyle(
              color: Colors.pink[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: Colors.pink[400], size: 20),
        ],
      ),
    );
  }

  List<Widget> _buildHistoryByDate(BuildContext context, List<Order> orders) {
    // Agrupa por data
    final Map<String, List<Order>> groupedOrders = {};
    final dateFormat = DateFormat("EEEE, dd/MM/yyyy", 'pt_BR');
    
    for (final order in orders) {
      // Usa a data do pedido para agrupar
      final dateKey = dateFormat.format(order.createdAt.toLocal());
      groupedOrders.putIfAbsent(dateKey, () => []).add(order);
    }

    final widgets = <Widget>[];
    
    groupedOrders.forEach((date, dateOrders) {
      // Título da data
      widgets.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            date,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      ));
      
      // Pedidos dessa data
      widgets.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: dateOrders.map((order) => 
              _HistoryOrderCard(order: order)).toList(),
          ),
        ),
      ));
    });

    return widgets;
  }
}

/// Card para pedido em andamento (estilo iFood)
class _InProgressOrderCard extends StatelessWidget {
  final Order order;

  const _InProgressOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    final now = DateTime.now();
    final estimatedMin = now.add(const Duration(minutes: 15));
    final estimatedMax = now.add(const Duration(minutes: 25));
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                      'Entrega não rastreável',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Barra de progresso
          Row(
            children: [
              Text(
                'Previsão de entrega: ',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
          LinearProgressIndicator(
            value: 0.4, // TODO: Calcular progresso real
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
            borderRadius: BorderRadius.circular(4),
          ),
          
          const SizedBox(height: 16),
          
          // Botões
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ajuda em breve!')),
                    );
                  },
                  child: Text(
                    'Ajuda',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _openOrderDetails(context, order),
                  child: Text(
                    'Acompanhar',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(Icons.store, color: Colors.grey[400]),
              ),
            )
          : Icon(Icons.store, color: Colors.grey[400]),
    );
  }

  void _openOrderDetails(BuildContext context, Order order) {
    showResponsiveSidePanel(
      context,
      OrderDetailsPage(
        order: order,
        showActions: false,
        showRating: false,
      ),
      useFullScreenOnDesktop: false,
    );
  }
}

/// Card para pedido no histórico (estilo iFood)
class _HistoryOrderCard extends StatelessWidget {
  final Order order;

  const _HistoryOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    final isCanceled = order.orderStatus.toLowerCase() == 'canceled';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
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
                          isCanceled ? 'Pedido cancelado' : 'Pedido concluído',
                          style: TextStyle(
                            fontSize: 13,
                            color: isCanceled ? Colors.red : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isCanceled ? Icons.cancel : Icons.check_circle,
                          size: 14,
                          color: isCanceled ? Colors.red : Colors.green,
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
          ...order.items.take(2).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
          )),
          
          if (order.items.length > 2) 
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${order.items.length - 2} itens',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Botões
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ajuda em breve!')),
                    );
                  },
                  child: Text(
                    'Ajuda',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _openOrderDetails(context, order),
                  child: Text(
                    'Ver detalhes',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(Icons.store, color: Colors.grey[400]),
              ),
            )
          : Icon(Icons.store, color: Colors.grey[400]),
    );
  }

  void _openOrderDetails(BuildContext context, Order order) {
    showResponsiveSidePanel(
      context,
      OrderDetailsPage(
        order: order,
        showActions: false,
        showRating: true, // Permite avaliar no histórico
      ),
      useFullScreenOnDesktop: false,
    );
  }
}
