// lib/pages/order/order_details_page.dart
// ✅ Página de detalhes do pedido - Estilo iFood
// Reutiliza widgets para ser usada tanto após sucesso quanto no histórico

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/models/order.dart';
import 'package:totem/models/payment_method.dart';

// Widgets reutilizáveis
import 'widgets/order_header_widget.dart';
import 'widgets/order_status_badge.dart';
import 'widgets/order_items_list.dart';
import 'widgets/order_summary_widget.dart';
import 'widgets/order_payment_widget.dart';
import 'widgets/order_address_widget.dart';
import 'widgets/order_rating_widget.dart';

/// Página de detalhes do pedido estilo iFood
/// Pode ser usada após confirmação de pedido ou no histórico
class OrderDetailsPage extends StatelessWidget {
  final Order order;
  final PlatformPaymentMethod? paymentMethod;
  
  /// Se true, mostra botões de ação (ajuda, etc)
  /// Se false, mostra apenas os detalhes (modo histórico)
  final bool showActions;
  
  /// Se true, mostra seção de avaliação
  final bool showRating;

  const OrderDetailsPage({
    super.key,
    required this.order,
    this.paymentMethod,
    this.showActions = true,
    this.showRating = false,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    final theme = Theme.of(context);
    final isDelivery = order.deliveryType == 'delivery';
    final isCanceled = ['canceled', 'cancelled'].contains(order.orderStatus.toLowerCase());
    final isFinalized = ['delivered', 'finalized', 'concluded'].contains(order.orderStatus.toLowerCase());
    
    // Verifica se pode avaliar (concluído e dentro do prazo - 7 dias)
    final canRate = isFinalized && 
        !isCanceled && 
        DateTime.now().difference(order.createdAt).inDays <= 7;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'DETALHES DO PEDIDO',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Implementar chat de ajuda
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ajuda em breve!')),
              );
            },
            child: Text(
              'Ajuda',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header: Logo, nome do cliente, número do pedido
            OrderHeaderWidget(
              storeLogo: store?.image?.url ?? order.merchant.logo,
              storeName: store?.name ?? order.merchant.name,
              customerName: order.merchant.name, // Nome da loja para exibição
              orderNumber: order.displayId,
              orderDate: order.createdAt,
              onViewMenu: () => context.go('/'),
            ),
            
            // ✅ Status do pedido (badge com mensagem)
            OrderStatusBadge(
              status: order.orderStatus,
              completedAt: isFinalized ? order.updatedAt : null,
            ),
            
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // ✅ Itens do pedido (imagem, quantidade, opções)
            OrderItemsList(items: order.bag.items),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // ✅ Resumo de valores
            OrderSummaryWidget(
              subtotalCents: order.bag.subTotal.value,
              deliveryFeeCents: order.bag.deliveryFee.value,
              serviceFeeCents: 0, // Taxa de serviço se houver
              discountCents: 0, // Descontos estão em order.bag.benefits
              totalCents: order.bag.total.value,
              onAddToCart: isFinalized ? () {
                // TODO: Adicionar itens de volta ao carrinho
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Em breve: pedir novamente!')),
                );
              } : null,
            ),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // ✅ Pagamento
            OrderPaymentWidget(
              paymentMethod: _getPaymentMethodName(),
              paymentBrand: paymentMethod?.name,
              paymentType: isDelivery ? 'delivery' : 'pickup',
              changeAmountCents: order.payments.primary?.cash?.changeFor.value,
              isPaid: order.paymentStatus == 'paid',
            ),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // ✅ Endereço completo
            OrderAddressWidget(
              address: order.delivery.address,
              isPickup: !isDelivery,
            ),
            
            // ✅ Avaliação (apenas para pedidos concluídos dentro do prazo)
            // Não mostra para pedidos cancelados
            if (showRating && canRate) ...[
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),
              
              OrderRatingWidget(
                storeLogo: store?.image?.url ?? order.merchant.logo,
                storeName: store?.name ?? order.merchant.name,
                isExpired: false,
                onRatingChanged: (rating) {
                  // TODO: Enviar avaliação para o backend
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Avaliação: $rating estrelas')),
                  );
                },
              ),
            ],
            
            const SizedBox(height: 100), // Espaço para footer
          ],
        ),
      ),
      
      // ✅ Bottom bar (apenas se showActions = true)
      bottomNavigationBar: showActions ? _buildBottomBar(context, theme) : null,
    );
  }

  String _getPaymentMethodName() {
    if (paymentMethod != null) {
      return paymentMethod!.method_type ?? 'CASH';
    }
    // Tenta pegar do pedido
    final primaryMethod = order.payments.primary;
    if (primaryMethod != null) {
      return primaryMethod.method.name;
    }
    return 'CASH';
  }

  Widget _buildBottomBar(BuildContext context, ThemeData theme) {
    final store = context.read<StoreCubit>().state.store;
    final totalText = 'R\$ ${(order.bag.total.value / 100.0).toStringAsFixed(2).replaceAll('.', ',')}';
    final deliveryText = order.bag.deliveryFee.value == 0
        ? 'entrega grátis'
        : 'com entrega';
    final itemCount = order.bag.itemCount;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Logo da loja
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: store?.image?.url != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        store!.image!.url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.store,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                  : Icon(Icons.store, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),
            // Resumo
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total com $deliveryText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        totalText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' / $itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Botão Novo Pedido
            ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Novo pedido',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
