// lib/pages/orders/order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem/models/order.dart';

/// Página de detalhes do pedido - Formato iFood
/// ✅ OTIMIZADO: Recebe o Order diretamente, sem fazer GET
class OrderDetailPage extends StatelessWidget {
  final Order order;

  const OrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return _OrderDetailContent(order: order);
  }
}

class _OrderDetailContent extends StatelessWidget {
  final Order order;

  const _OrderDetailContent({required this.order});

  @override
  Widget build(BuildContext context) {
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
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildStatusTimeline(),
            const SizedBox(height: 24),
            if (order.pickupCode != null) _buildPickupCode(),
            const SizedBox(height: 24),
            _buildProducts(),
            const SizedBox(height: 24),
            _buildPaymentInfo(),
            const SizedBox(height: 24),
            _buildAddressInfo(),
            const SizedBox(height: 24),
            if (order.orderStatus == 'delivered') _buildReviewButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${order.displayId}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(order.createdAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getSalesChannelIcon(order.salesChannel),
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.salesChannel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: order.orderStatus),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'R\$ ${order.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupCode() {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.key,
                color: Colors.amber.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Código de Retirada',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.pickupCode!,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                      letterSpacing: 4,
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

  Widget _buildProducts() {
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
            ...order.items.map((item) => _buildItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagem do produto
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                  ),
                )
              else
                _buildPlaceholderImage(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.quantity}x ${item.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (item.observations != null && item.observations!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Obs: ${item.observations}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'R\$ ${item.totalPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          // Opções do item
          if (item.options.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 72, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.options.map((option) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            option.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        if (option.price > 0)
                          Text(
                            '+R\$ ${option.price.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.restaurant,
        color: Colors.grey.shade400,
        size: 28,
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo do Pagamento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Subtotal',
              value: 'R\$ ${order.subtotalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
            ),
            if (order.deliveryFeeAmount > 0)
              _InfoRow(
                label: 'Taxa de Entrega',
                value: 'R\$ ${order.deliveryFeeAmount.toStringAsFixed(2).replaceAll('.', ',')}',
              ),
            if (order.discountAmount > 0)
              _InfoRow(
                label: 'Desconto',
                value: '- R\$ ${order.discountAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                valueColor: Colors.green,
              ),
            const Divider(height: 24),
            _InfoRow(
              label: 'Total',
              value: 'R\$ ${order.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
              isBold: true,
            ),
            const SizedBox(height: 16),
            if (order.payments.primaryMethod != null) ...[
              Row(
                children: [
                  Icon(
                    _getPaymentMethodIcon(order.payments.primaryMethod!.method.name),
                    size: 20,
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.payments.primaryMethod!.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: order.paymentStatus == 'paid'
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.paymentStatus == 'paid' ? 'Pago' : 'Pendente',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: order.paymentStatus == 'paid'
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (order.needsChange && order.changeFor != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _InfoRow(
                  label: 'Troco para',
                  value: 'R\$ ${order.changeFor!.toStringAsFixed(2).replaceAll('.', ',')}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInfo() {
    final address = order.delivery.deliveryAddress;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  order.isDelivery ? Icons.delivery_dining : Icons.storefront,
                  color: Colors.indigo,
                ),
                const SizedBox(width: 8),
                Text(
                  order.isDelivery ? 'Entrega' : 'Retirada na Loja',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${address.streetName}, ${address.streetNumber ?? "S/N"}',
              style: const TextStyle(fontSize: 16),
            ),
            if (address.complement != null && address.complement!.isNotEmpty)
              Text(
                address.complement!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            Text(
              '${address.neighborhood} - ${address.city}, ${address.state}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            if (order.delivery.pickupCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Código: ${order.delivery.pickupCode}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
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

  Widget _buildReviewButton(BuildContext context) {
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
                  context.push('/orders/${order.id}/review');
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

  IconData _getSalesChannelIcon(String channel) {
    switch (channel.toUpperCase()) {
      case 'IFOOD':
        return Icons.restaurant;
      case 'TOTEM':
        return Icons.point_of_sale;
      case 'MENUHUB':
      case 'APP':
        return Icons.phone_android;
      default:
        return Icons.shopping_bag;
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toUpperCase()) {
      case 'CREDIT_CARD':
      case 'CREDIT':
        return Icons.credit_card;
      case 'DEBIT_CARD':
      case 'DEBIT':
        return Icons.credit_card;
      case 'PIX':
        return Icons.pix;
      case 'CASH':
      case 'DINHEIRO':
        return Icons.attach_money;
      default:
        return Icons.payment;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? (isBold ? Colors.black : null),
              fontSize: isBold ? 16 : 14,
            ),
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
        color: _statusColor.withValues(alpha: 0.1),
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
        active: order.orderStatus.toLowerCase() == 'pending',
        completed: !['pending', 'canceled'].contains(order.orderStatus.toLowerCase()),
      ),
      _StatusStep(
        status: 'preparing',
        title: 'Preparando',
        icon: Icons.restaurant,
        active: order.orderStatus.toLowerCase() == 'preparing',
        completed: ['ready', 'on_route', 'out_for_delivery', 'delivered'].contains(order.orderStatus.toLowerCase()),
      ),
      _StatusStep(
        status: 'ready',
        title: 'Pronto',
        icon: Icons.check_circle_outline,
        active: order.orderStatus.toLowerCase() == 'ready',
        completed: ['on_route', 'out_for_delivery', 'delivered'].contains(order.orderStatus.toLowerCase()),
      ),
    ];

    if (order.isDelivery) {
      statusSteps.add(_StatusStep(
        status: 'on_route',
        title: 'Em Rota',
        icon: Icons.delivery_dining,
        active: ['on_route', 'out_for_delivery'].contains(order.orderStatus.toLowerCase()),
        completed: order.orderStatus.toLowerCase() == 'delivered',
      ));
    }

    statusSteps.add(_StatusStep(
      status: 'delivered',
      title: 'Entregue',
      icon: Icons.check_circle,
      active: order.orderStatus.toLowerCase() == 'delivered',
      completed: order.orderStatus.toLowerCase() == 'delivered',
    ));

    final currentIndex = statusSteps.indexWhere((step) => 
      step.status == order.orderStatus.toLowerCase() ||
      (step.status == 'on_route' && order.orderStatus.toLowerCase() == 'out_for_delivery')
    );
    final primaryColor = _getStatusColor('on_route');
    final greyLineColor = Colors.grey[300]!;

    return SizedBox(
      height: 85,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(height: 2, color: greyLineColor),
          ),
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
                          ? (step.active ? primaryColor : primaryColor.withValues(alpha: 0.2))
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
