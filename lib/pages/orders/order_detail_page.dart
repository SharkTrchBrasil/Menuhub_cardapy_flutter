// lib/pages/orders/order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem/models/order.dart';
import 'package:totem/repositories/order_repository.dart';
import 'package:totem/core/di.dart';

class OrderDetailPage extends StatelessWidget {
  final int orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getIt<OrderRepository>().getOrderById(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalhes do Pedido')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalhes do Pedido')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erro ao carregar pedido: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          );
        }

        final orderResult = snapshot.data!;
        if (orderResult.isLeft) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalhes do Pedido')),
            body: Center(
              child: Text('Erro: ${orderResult.left}'),
            ),
          );
        }

        final order = orderResult.right;
        return _OrderDetailContent(order: order);
      },
    );
  }
}

class _OrderDetailContent extends StatelessWidget {
  final Order order;

  const _OrderDetailContent({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final total = ((order.charge?.amount ?? 0) / 100.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Pedido'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(order, total),
            const SizedBox(height: 24),
            _buildStatusTimeline(order),
            const SizedBox(height: 24),
            if (order.orderStatus == 'delivered') _buildReviewButton(context, order),
            const SizedBox(height: 24),
            _buildProducts(order),
            const SizedBox(height: 24),
            _buildPaymentInfo(order, total),
            const SizedBox(height: 24),
            _buildAddressInfo(order),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Order order, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedido #${order.publicId}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _StatusBadge(status: order.orderStatus),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Total: R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProducts(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Itens do Pedido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...order.products.map((product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    '${product.quantity}x',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (product.variants.isNotEmpty)
                          Text(
                            product.variants.map((v) => v.name).join(', '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'R\$ ${(product.discountedPrice / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfo(Order order, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informações de Pagamento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Status', value: order.paymentStatus),
            _InfoRow(label: 'Tipo', value: order.orderType),
            if (order.needsChange && order.changeAmount != null)
              _InfoRow(
                label: 'Troco para',
                value: 'R\$ ${(order.changeAmount!.toDouble() / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInfo(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Endereço de Entrega',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(order.deliveryType),
            // Aqui você pode adicionar mais detalhes do endereço quando disponíveis
          ],
        ),
      ),
    );
  }

  Widget _buildReviewButton(BuildContext context, Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Como foi seu pedido?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Avalie sua experiência e nos ajude a melhorar!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/orders/${order.publicId}/review');
                },
                icon: const Icon(Icons.star_outline),
                label: const Text('Avaliar Pedido'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
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
      case 'ON_ROUTE':
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
      case 'ON_ROUTE':
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

Widget _buildStatusTimeline(Order order) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status do Pedido',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _StatusTimeline(order: order),
        ],
      ),
    ),
  );
}

class _StatusTimeline extends StatelessWidget {
  final Order order;

  const _StatusTimeline({required this.order});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.purple;
      case 'ready':
        return Colors.cyan;
      case 'on_route':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusSteps = [
      _StatusStep(
        status: 'pending',
        title: 'Recebido',
        icon: Icons.access_time,
        active: order.orderStatus == 'pending',
        completed: !['pending', 'canceled'].contains(order.orderStatus),
      ),
      _StatusStep(
        status: 'preparing',
        title: 'Preparando',
        icon: Icons.restaurant,
        active: order.orderStatus == 'preparing',
        completed: ['ready', 'on_route', 'delivered'].contains(order.orderStatus),
      ),
      _StatusStep(
        status: 'ready',
        title: 'Pronto',
        icon: Icons.check_circle_outline,
        active: order.orderStatus == 'ready',
        completed: ['on_route', 'delivered'].contains(order.orderStatus),
      ),
    ];

    // Se for delivery, adiciona a etapa "Em Rota"
    if (order.deliveryType == 'delivery') {
      statusSteps.add(_StatusStep(
        status: 'on_route',
        title: 'Em Rota',
        icon: Icons.delivery_dining,
        active: order.orderStatus == 'on_route',
        completed: order.orderStatus == 'delivered',
      ));
    }

    // Etapa final: Entregue
    statusSteps.add(_StatusStep(
      status: 'delivered',
      title: 'Entregue',
      icon: Icons.check_circle,
      active: order.orderStatus == 'delivered',
      completed: order.orderStatus == 'delivered',
    ));

    final currentIndex = statusSteps.indexWhere((step) => step.status == order.orderStatus);
    final primaryColor = _getStatusColor('on_route');
    final greyLineColor = Colors.grey[300]!;

    return SizedBox(
      height: 85,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Linha cinza completa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(height: 2, color: greyLineColor),
          ),

          // Linha colorida de progresso
          if (currentIndex >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final progressWidth = statusSteps.length > 1
                      ? (totalWidth / (statusSteps.length - 1)) * currentIndex
                      : 0;

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 2,
                      width: progressWidth.clamp(0.0, totalWidth).toDouble(),
                      color: primaryColor,
                    ),
                  );
                },
              ),
            ),

          // Ícones de status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: statusSteps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isActive = index <= currentIndex;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (step.active ? primaryColor : primaryColor.withOpacity(0.2))
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? primaryColor : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      step.icon,
                      color: isActive
                          ? (step.active ? Colors.white : primaryColor)
                          : Colors.grey[400],
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: step.active ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? primaryColor : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatusStep {
  final String status;
  final String title;
  final IconData icon;
  final bool active;
  final bool completed;

  _StatusStep({
    required this.status,
    required this.title,
    required this.icon,
    required this.active,
    required this.completed,
  });
}

