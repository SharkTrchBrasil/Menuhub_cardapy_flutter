// lib/pages/order/order_tracking_page.dart
// ✅ Tela de acompanhamento do pedido estilo iFood
// Exibe mapa, status, endereço e detalhes do pedido

import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:totem/models/order.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/cubit/store_cubit.dart';

/// Tela de acompanhamento de pedido estilo iFood
/// Exibe mapa no topo (para delivery), status, endereço e detalhes
class OrderTrackingPage extends StatelessWidget {
  final Order order;
  final PlatformPaymentMethod? paymentMethod;

  const OrderTrackingPage({
    super.key,
    required this.order,
    this.paymentMethod,
  });

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
                  // Implementar chat de ajuda
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ajuda em breve!')),
                  );
                },
                child: Text(
                  'Ajuda',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: isDelivery && store != null
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
                  color: Colors.red,
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
    
    // Estimativa de tempo (mockado - idealmente viria do backend)
    final now = DateTime.now();
    final estimatedMin = now.add(const Duration(minutes: 30));
    final estimatedMax = now.add(const Duration(minutes: 45));
    final timeFormat = '${estimatedMin.hour}:${estimatedMin.minute.toString().padLeft(2, '0')} - ${estimatedMax.hour}:${estimatedMax.minute.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusInfo['color'] as Color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusInfo['text'] as String,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () {
                  // Expandir/colapsar detalhes de status
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.deliveryType == 'delivery'
                ? 'Previsão de entrega: $timeFormat'
                : 'Previsão para retirada: $timeFormat',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          // Barra de progresso
          _buildProgressBar(theme),
        ],
      ),
    );
  }

  /// Barra de progresso do pedido
  Widget _buildProgressBar(ThemeData theme) {
    final statuses = order.deliveryType == 'delivery'
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
            child: isCurrent
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
  Widget _buildAddressSection(BuildContext context, ThemeData theme, dynamic store) {
    final isDelivery = order.deliveryType == 'delivery';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDelivery ? 'Endereço de entrega' : 'Endereço de retirada',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  color: theme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDelivery
                          ? 'Endereço selecionado' // Idealmente viria do pedido
                          : store?.name ?? 'Loja',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDelivery
                          ? '${order.addressState ?? ''} ${order.addressZipCode ?? ''}'
                          : '${store?.street ?? ''}, ${store?.number ?? ''}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isDelivery) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esta entrega é feita pela loja e não pode ser rastreada',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Seção de detalhes do pedido
  Widget _buildOrderDetailsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalhes do pedido',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
            children: [
              // Informações do pedido
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long, color: theme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido Nº ${order.sequentialId}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${order.products.length} ${order.products.length == 1 ? 'item' : 'itens'}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
              const Divider(height: 24),
              // Método de pagamento
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payments, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.deliveryType == 'delivery' 
                              ? 'Pagamento na entrega'
                              : 'Pagamento na retirada',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          paymentMethod?.name ?? 'Dinheiro',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        if (order.needsChange && order.changeAmount != null)
                          Text(
                            'Troco para ${UtilBrasilFields.obterReal(order.changeAmount! / 100.0)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
            children: order.products.map((product) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product.quantity}x',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                      UtilBrasilFields.obterReal(product.totalPrice / 100.0),
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

  /// Bottom bar com ações
  Widget _buildBottomBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text('Início'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Abrir chat/suporte
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Suporte em breve!')),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Ajuda'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Retorna informações do status
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'text': 'Aguardando confirmação da loja',
          'color': Colors.orange,
        };
      case 'preparing':
        return {
          'text': 'Seu pedido está sendo preparado',
          'color': Colors.blue,
        };
      case 'ready':
        return {
          'text': 'Pedido pronto!',
          'color': Colors.green,
        };
      case 'on_route':
        return {
          'text': 'Pedido saiu para entrega',
          'color': Colors.purple,
        };
      case 'delivered':
      case 'finalized':
        return {
          'text': 'Pedido entregue!',
          'color': Colors.green,
        };
      case 'canceled':
        return {
          'text': 'Pedido cancelado',
          'color': Colors.red,
        };
      default:
        return {
          'text': 'Processando...',
          'color': Colors.grey,
        };
    }
  }
}
