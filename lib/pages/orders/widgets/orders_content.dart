import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem/models/order.dart';
import 'package:totem/cubit/orders_cubit.dart';
import 'package:totem/cubit/auth_cubit.dart';

/// Orders Content Widget
/// Layout inspirado no iFood com seções "Em andamento" e "Histórico"
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
        final groupedHistory = _groupOrdersByDate(historyOrders);

        return RefreshIndicator(
          onRefresh: () async {
            final customer = context.read<AuthCubit>().state.customer;
            if (customer?.id != null) {
              await context.read<OrdersCubit>().refreshOrders(customer!.id!);
            }
          },
          child: ListView(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            children: [
              // Seção "Em andamento"
              if (activeOrders.isNotEmpty) ...[
                _buildSectionTitle('Em andamento'),
                const SizedBox(height: 12),
                ...activeOrders.map((order) => _ActiveOrderCard(
                  order: order,
                  isDesktop: isDesktop,
                )),
                const SizedBox(height: 24),
              ],

              // Seção "Histórico"
              if (historyOrders.isNotEmpty) ...[
                _buildSectionTitle('Histórico'),
                const SizedBox(height: 12),
                ...groupedHistory.entries.expand((entry) => [
                  _buildDateHeader(entry.key),
                  ...entry.value.map((order) => _HistoryOrderCard(
                    order: order,
                    isDesktop: isDesktop,
                  )),
                ]),
              ],
              
              // Se não há pedidos em nenhuma categoria
              if (activeOrders.isEmpty && historyOrders.isEmpty)
                _buildEmptyState(context),
            ],
          ),
        );
      },
    );
  }

  Map<String, List<Order>> _groupOrdersByDate(List<Order> orders) {
    final Map<String, List<Order>> grouped = {};
    final dateFormat = DateFormat('EEE, dd/MM/yyyy', 'pt_BR');
    
    for (final order in orders) {
      // ✅ createdAt agora é non-nullable no modelo iFood
      final dateKey = dateFormat.format(order.createdAt.toLocal());
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(order);
    }
    
    return grouped;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isDesktop ? 24 : 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
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
                    // ✅ Ilustração de sacola dormindo (estilo iFood)
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

  // ✅ Ilustração de sacola dormindo (estilo iFood)
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

  // ✅ Card de login flutuante (estilo iFood)
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
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

  const _ActiveOrderCard({
    required this.order,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com avatar e info da loja
            Row(
              children: [
                _buildStoreAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${order.displayId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getStatusText(order.orderStatus),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
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
            
            // Barra de progresso
            _buildProgressBar(),
            
            const SizedBox(height: 16),
            
            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implementar ajuda
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.pink,
                      side: const BorderSide(color: Colors.pink),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Ajuda'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/order/${order.id}', extra: order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.pink,
                      side: const BorderSide(color: Colors.pink),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Acompanhar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.store,
        color: Colors.orange.shade700,
        size: 28,
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    return Row(
      children: [
        Text(
          'Previsão de entrega: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const Text(
          '30 - 45 min',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = _getProgressValue(order.orderStatus);
    
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.pink),
            minHeight: 6,
          ),
        ),
      ],
    );
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
        return 1.0;
      default:
        return 0.0;
    }
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
      case 'on_route':
      case 'out_for_delivery':
        return 'Saiu para entrega';
      default:
        return 'Em andamento';
    }
  }
}

/// Card para pedidos no histórico
class _HistoryOrderCard extends StatelessWidget {
  final Order order;
  final bool isDesktop;

  const _HistoryOrderCard({
    required this.order,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final isCanceled = order.orderStatus.toLowerCase() == 'canceled';
    final isDelivered = order.orderStatus.toLowerCase() == 'delivered';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com avatar, nome e status
            Row(
              children: [
                _buildStoreAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${order.displayId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _getStatusLabel(order.orderStatus),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isCanceled ? Icons.cancel : Icons.check_circle,
                            size: 16,
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
            
            // Lista de itens (apenas primeiro item para preview)
            ...order.items.take(2).map((item) => _buildProductItem(item)),
            
            if (order.items.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${order.items.length - 2} ${order.items.length - 2 == 1 ? "item" : "itens"}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implementar ajuda
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.pink,
                      side: const BorderSide(color: Colors.pink),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Ajuda'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/order/${order.id}', extra: order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.pink,
                      side: const BorderSide(color: Colors.pink),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Ver detalhes'),
                  ),
                ),
              ],
            ),
            
            // Botão "Adicionar à sacola" para pedidos concluídos
            if (isDelivered) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _addToCart(context);
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Adicionar à sacola'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStoreAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.store,
        color: Colors.orange.shade700,
        size: 28,
      ),
    );
  }

  Widget _buildProductItem(dynamic product) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Quantidade
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${product.quantity}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Nome do produto
          Expanded(
            child: Text(
              product.name,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Imagem do produto (se disponível)
          if (product.logoUrl != null && product.logoUrl!.isNotEmpty && !product.logoUrl!.startsWith('None'))
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product.logoUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildProductPlaceholder(),
              ),
            )
          else
            _buildProductPlaceholder(),
        ],
      ),
    );
  }

  Widget _buildProductPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.fastfood,
        color: Colors.grey.shade400,
        size: 24,
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return 'Pedido concluído';
      case 'canceled':
        return 'Pedido cancelado';
      default:
        return 'Finalizado';
    }
  }

  void _addToCart(BuildContext context) {
    // TODO: Implementar adicionar todos os itens do pedido ao carrinho
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Itens adicionados à sacola!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
