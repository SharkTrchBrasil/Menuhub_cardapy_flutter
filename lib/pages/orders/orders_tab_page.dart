import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/models/order.dart';
import 'package:totem/pages/profile/profile_cubit.dart';

import 'order_detail_page.dart';

import '../../core/di.dart';
import '../../cubit/auth_cubit.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';

/// Orders Tab Page - Versão otimizada para funcionar como tab
class OrdersTabPage extends StatelessWidget {
  const OrdersTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    return BlocProvider(
      create: (context) {
        final cubit = ProfileCubit(
          customerRepository: getIt<CustomerRepository>(),
          orderRepository: getIt<OrderRepository>(),
        );
        final customer = context.read<AuthCubit>().state.customer;
        if (customer?.id != null) {
          cubit.loadOrderHistory(customer!.id!);
        }
        return cubit;
      },
      // ✅ CORREÇÃO: Remove Scaffold para evitar conflito com MainTabPage
      child: SafeArea(
        child: Column(
          children: [
            // ✅ Header com título e filtros
            _buildHeader(context),
            
            // ✅ Tabs de status (Novo, Preparo, Pronto)
            _buildStatusTabs(context),
            
            // ✅ Conteúdo principal
            Expanded(
              child: BlocBuilder<ProfileCubit, ProfileState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status ||
                    previous.filteredOrders.length != current.filteredOrders.length,
                builder: (context, state) {
                  if (state.status == ProfileStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.status == ProfileStatus.error) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            state.errorMessage ?? 'Erro ao carregar pedidos',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              final customer =
                                  context.read<ProfileCubit>().state.customer;
                              if (customer != null) {
                                context
                                    .read<ProfileCubit>()
                                    .loadOrderHistory(customer.id!);
                              }
                            },
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    );
                  }

                  final orders = state.filteredOrders;

                  if (orders.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return isDesktop
                      ? _buildDesktopGrid(orders)
                      : _buildMobileList(orders);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Pedidos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // ✅ Informações adicionais (tempo de entrega, pedido mínimo)
          _buildInfoChips(),
        ],
      ),
    );
  }

  Widget _buildInfoChips() {
    return Row(
      children: [
        _buildInfoChip(
          icon: Icons.access_time,
          label: 'Tempo de Entrega',
          value: '30-60min',
          color: Colors.orange,
        ),
        const SizedBox(width: 8),
        _buildInfoChip(
          icon: Icons.shopping_cart,
          label: 'Pedido Mínimo',
          value: 'R\$ 20,00',
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (previous, current) =>
          previous.filteredOrderStatus != current.filteredOrderStatus,
      builder: (context, state) {
        final selectedStatus = state.filteredOrderStatus;

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              _buildStatusTab(
                context,
                label: 'Novo',
                status: 'PENDING',
                isSelected: selectedStatus == 'PENDING',
              ),
              _buildStatusTab(
                context,
                label: 'Preparo',
                status: 'PREPARING',
                isSelected: selectedStatus == 'PREPARING',
              ),
              _buildStatusTab(
                context,
                label: 'Pronto',
                status: 'READY',
                isSelected: selectedStatus == 'READY',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusTab(
    BuildContext context, {
    required String label,
    required String status,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          context.read<ProfileCubit>().filterOrdersByStatus(
                isSelected ? null : status,
              );
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 60,
              color: Colors.orange.shade300,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nenhum pedido',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Não há pedidos Novos Pedidos',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopGrid(List<Order> orders) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _OrderCard(order: orders[index]);
      },
    );
  }

  Widget _buildMobileList(List<Order> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _OrderCard(order: orders[index]);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final total = (order.charge?.amount ?? 0) / 100.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/order/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${order.publicId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  _StatusBadge(status: order.orderStatus),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${order.products.length} ${order.products.length == 1 ? 'item' : 'itens'}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color get _statusColor {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'PREPARING':
        return Colors.purple;
      case 'READY':
        return Colors.cyan;
      case 'OUT_FOR_DELIVERY':
        return Colors.indigo;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pendente';
      case 'CONFIRMED':
        return 'Confirmado';
      case 'PREPARING':
        return 'Preparando';
      case 'READY':
        return 'Pronto';
      case 'OUT_FOR_DELIVERY':
        return 'Saiu para entrega';
      case 'DELIVERED':
        return 'Entregue';
      case 'CANCELED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor, width: 1),
      ),
      child: Text(
        _statusLabel,
        style: TextStyle(
          color: _statusColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

