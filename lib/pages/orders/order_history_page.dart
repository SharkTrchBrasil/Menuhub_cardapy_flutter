// lib/pages/orders/order_history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem/models/order.dart';
import 'package:totem/pages/profile/profile_cubit.dart';

import 'package:totem/pages/orders/order_detail_page.dart';

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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Histórico de Pedidos'),
          centerTitle: true,
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
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

          final orders = state.filteredOrders;

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum pedido encontrado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Seus pedidos aparecerão aqui',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildFilters(context, state),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _OrderCard(order: orders[index]);
                  },
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, ProfileState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar pedido...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => context.read<ProfileCubit>().searchOrders(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => context.read<ProfileCubit>().searchOrders(value),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              context.read<ProfileCubit>().filterOrdersByStatus(
                    status == 'Todos' ? null : status,
                  );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Todos', child: Text('Todos')),
              const PopupMenuItem(value: 'PENDING', child: Text('Pendente')),
              const PopupMenuItem(value: 'CONFIRMED', child: Text('Confirmado')),
              const PopupMenuItem(value: 'PREPARING', child: Text('Preparando')),
              const PopupMenuItem(value: 'READY', child: Text('Pronto')),
              const PopupMenuItem(value: 'OUT_FOR_DELIVERY', child: Text('Saiu para entrega')),
              const PopupMenuItem(value: 'DELIVERED', child: Text('Entregue')),
              const PopupMenuItem(value: 'CANCELED', child: Text('Cancelado')),
            ],
          ),
        ],
      ),
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
                        dateFormat.format(DateTime.now()), // TODO: usar order.createdAt
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

