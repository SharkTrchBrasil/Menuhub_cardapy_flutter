// lib/pages/order/order_details_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/models/order.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/helpers/order_reorder_helper.dart';
import 'package:totem/cubit/orders_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/services/store_status_service.dart';
import 'package:totem/widgets/store_closed_widgets.dart';
import 'package:totem/core/services/timezone_service.dart';
import 'package:totem/pages/order/widgets/order_status_progress_bar.dart';
import 'package:totem/core/helpers/money_amount_helper.dart';

/// Página de detalhes do pedido completa - Estilo iFood
/// ✅ Suporta pedidos cancelados, concluídos e avaliações
class OrderDetailsPage extends StatelessWidget {
  final Order order;
  final PlatformPaymentMethod? paymentMethod;
  final bool showActions;
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
    return _OrderDetailContent(
      order: order,
      paymentMethod: paymentMethod,
      showActions: showActions,
      showRating: showRating,
    );
  }
}

class _OrderDetailContent extends StatefulWidget {
  final Order order;
  final PlatformPaymentMethod? paymentMethod;
  final bool showActions;
  final bool showRating;

  const _OrderDetailContent({
    required this.order,
    this.paymentMethod,
    required this.showActions,
    required this.showRating,
  });

  @override
  State<_OrderDetailContent> createState() => _OrderDetailContentState();
}

class _OrderDetailContentState extends State<_OrderDetailContent> {
  late Order _currentOrder;
  late String _currentStatus;
  bool _hasJustConfirmed = false;

  void _syncOrder(Order order) {
    _currentOrder = order;
    _currentStatus = order.lastStatus;
  }

  @override
  void initState() {
    super.initState();
    _syncOrder(widget.order);
  }

  @override
  void didUpdateWidget(covariant _OrderDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.updatedAt != widget.order.updatedAt ||
        oldWidget.order.lastStatus != widget.order.lastStatus) {
      _syncOrder(widget.order);
    }
  }

  bool get _isConcluded =>
      _currentStatus.toUpperCase() == 'CONCLUDED' || _currentOrder.isConcluded;

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrdersCubit, OrdersState>(
      listenWhen: (previous, current) => previous.orders != current.orders,
      listener: (context, state) {
        final updatedOrder =
            state.orders.where((o) => o.id == _currentOrder.id).firstOrNull;
        if (updatedOrder == null || !mounted) return;
        setState(() {
           _syncOrder(updatedOrder);
           if (_isConcluded && _hasJustConfirmed) {
             // Let it be, keep _hasJustConfirmed true so it doesn't bounce UI
           }
        });
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color(0xFFEA1D2C),
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'DETALHES DO PEDIDO',
            style: TextStyle(
              color: Color(0xFF3F3E3E),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () {
                // TODO: Implementar ajuda
              },
              child: const Text(
                'Ajuda',
                style: TextStyle(
                  color: Color(0xFFEA1D2C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildStoreHeader(context),
              
              if (!_hasJustConfirmed) 
                _buildStatusBanner(),
                
              if (_hasJustConfirmed)
                _buildJustConfirmedWidget(context)
              else if (_currentStatus.toUpperCase() == 'DISPATCHED')
                _buildConfirmArrivalCard(context),
                
              _buildProductList(),
              _buildValuesSummary(),
              if (_isConcluded && !_hasJustConfirmed) _buildAddToBagButton(context),
              _buildPaymentSection(),
              _buildAddressSection(),
              if ((widget.showRating || _isConcluded) && !_hasJustConfirmed)
                _buildReviewSection(context),
              _buildCancelOrderButton(context),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStoreAvatar(_currentOrder.merchant.logo, 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentOrder.merchant.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pedido nº ${_currentOrder.sequentialId} • ${TimezoneService.formatStoreDateTime(_currentOrder.createdAt, context.read<StoreCubit>().state.store?.timezone ?? "America/Sao_Paulo", format: 'dd/MM/yyyy • HH:mm')}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF717171),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 68, top: 4),
            child: TextButton(
              onPressed: () {
                context.go('/');
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Ver cardápio',
                style: TextStyle(
                  color: Color(0xFFEA1D2C),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    // Se cancelado pelo sistema (timeout), mostra mensagem amigável atual
    if (_currentOrder.isSystemCancelled) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cancel, color: Colors.black87, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'A loja não confirmou seu pedido e ele foi cancelado. Nenhuma cobrança será feita. Que tal fazer um novo pedido?',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3F3E3E),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_currentOrder.isConcluded) {
      final timeStr = DateFormat('HH:mm').format(
        (_currentOrder.closedAt ?? _currentOrder.updatedAt).toLocal()
      );
      
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2FAF5), // Pale background almost white/green
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16), // Green check
            const SizedBox(width: 8),
            Text(
              'Pedido concluído às $timeStr',
              style: const TextStyle(
                color: Color(0xFF3F3E3E), // Dark text as in image
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Para todos os outros casos (em andamento, ou cancelado pelo lojista),
    // usa o widget de progresso replicado do Admin
    return OrderStatusProgressBar(order: _currentOrder);
  }

  Widget _buildProductList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children:
            _currentOrder.items.map((item) => _buildProductItem(item)).toList(),
      ),
    );
  }

  Widget _buildProductItem(BagItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem com badge de quantidade
          Stack(
            children: [
              _buildProductImage(item.logoUrl),
              Positioned(
                bottom: 2,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA1D2C),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Informações do produto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3F3E3E),
                        ),
                      ),
                    ),
                    Text(
                      NumberFormat.simpleCurrency(
                        locale: 'pt_BR',
                      ).format(item.priceInReais),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                  ],
                ),
                if (item.description != null &&
                    item.description!.trim().isNotEmpty &&
                    !item.description!.toLowerCase().contains('categoria:') &&
                    !item.description!.toLowerCase().contains('tamanho')) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF717171),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Sub-itens formatados como no carrinho
                if (item.subItems.isNotEmpty) _buildVariantsSection(item),

                // Observações
                if (item.hasNotes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Obs: ${item.notes!.trim()}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF717171),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSection(BagItem item) {
    String? massaText;
    String? bordaText;
    final flavorOptions = <SubItem>[];
    final otherOptions = <SubItem>[];

    for (final sub in item.subItems) {
      if (sub.quantity <= 0) continue;

      final groupType = OptionGroupType.fromString(sub.groupType);
      final groupNameLower = sub.groupName?.toLowerCase() ?? '';
      final nameLower = sub.name.toLowerCase();

      final isFlavorGroup = groupType == OptionGroupType.topping ||
          groupType == OptionGroupType.flavor ||
          groupNameLower.contains('sabor') ||
          RegExp(r'^1/\d+\s+').hasMatch(sub.name);
      final isMassaGroup = groupType == OptionGroupType.crust;
      final isBordaGroup = groupType == OptionGroupType.edge;

      // Detecta Massa
      if (isMassaGroup && massaText == null) {
        massaText = sub.name;
        continue;
      }

      // Detecta Borda
      if (isBordaGroup && bordaText == null) {
        bordaText = sub.name;
        continue;
      }

      // 🍕 Detecta combo "Massa + Borda" pelo nome da opção ou se for do grupo de preferência
      final isPreferenceGroup =
          groupType == OptionGroupType.generic &&
          (groupNameLower.contains('preferência') ||
              groupNameLower.contains('preferencia'));

      if (nameLower.contains(' + ') || isPreferenceGroup) {
        if (nameLower.contains(' + ')) {
          final parts = sub.name.split(' + ');
          if (parts.length >= 2) {
            massaText = parts[0].trim();
            bordaText = parts[1].trim();
            continue;
          }
        }
      }

      // Sabores
      if (isFlavorGroup) {
        flavorOptions.add(sub);
      } else {
        otherOptions.add(sub);
      }
    }

    final lineWidgets = <Widget>[];

    // 1. Massa + Borda
    if (massaText != null || bordaText != null) {
      String cleanMassa = massaText ?? '';
      String cleanBorda = bordaText ?? '';

      while (RegExp(
        r'^[Mm]assa\s+',
        caseSensitive: false,
      ).hasMatch(cleanMassa)) {
        cleanMassa = cleanMassa.replaceFirst(
          RegExp(r'^[Mm]assa\s+', caseSensitive: false),
          '',
        );
      }
      while (RegExp(
        r'^[Bb]orda\s+',
        caseSensitive: false,
      ).hasMatch(cleanBorda)) {
        cleanBorda = cleanBorda.replaceFirst(
          RegExp(r'^[Bb]orda\s+', caseSensitive: false),
          '',
        );
      }

      String combinedText = '';
      if (massaText != null && bordaText != null) {
        combinedText = 'Massa $cleanMassa + Borda $cleanBorda';
      } else if (massaText != null) {
        combinedText = 'Massa $cleanMassa';
      } else {
        combinedText = 'Borda $cleanBorda';
      }
      lineWidgets.add(
        _buildVariantRow(context, '1', combinedText),
      );
    }

    // 2. Sabores
    final flavorCount = flavorOptions.length;
    final fractionText = flavorCount > 1 ? '1/$flavorCount ' : '';
    for (final flavor in flavorOptions) {
      String name = flavor.name;
      name = name.replaceAll(RegExp(r'^1/\d+\s*'), '').trim();
      lineWidgets.add(
        _buildVariantRow(
          context,
          '1',
          '$fractionText$name',
        ),
      );
    }

    // 3. Outros
    for (final other in otherOptions) {
      lineWidgets.add(
        _buildVariantRow(
          context,
          other.quantity.toString(),
          other.name,
        ),
      );
    }

    if (lineWidgets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lineWidgets,
      ),
    );
  }

  Widget _buildVariantRow(
    BuildContext context,
    String quantity,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              quantity,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF717171),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF717171),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValuesSummary() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo de valores',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal', _currentOrder.subtotalAmount),
          _buildSummaryRow(
            'Taxa de entrega',
            _currentOrder.deliveryFeeAmount,
            isFree: _currentOrder.deliveryFeeAmount == 0,
          ),
          ..._currentOrder.bag.benefits.map((benefit) {
            String label = 'Desconto';
            double value = 0;

            if (benefit is Map) {
              label = benefit['name']?.toString() ?? 'Desconto';
              final rawValue = benefit['value'] ?? benefit['amount'];
              value = (parseMoneyAmount(rawValue)?.toDouble() ?? 0.0) / 100.0;
            } else {
              value = (parseMoneyAmount(benefit)?.toDouble() ?? 0.0) / 100.0;
            }

            if (value == 0) return const SizedBox.shrink();

            return _buildSummaryRow(label, -value, isFree: false);
          }),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F3E3E),
                ),
              ),
              Text(
                NumberFormat.simpleCurrency(
                  locale: 'pt_BR',
                ).format(_currentOrder.totalAmount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F3E3E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isFree = false,
    bool hasHelp = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Color(0xFF717171)),
              ),
              if (hasHelp) ...[
                const SizedBox(width: 4),
                const Icon(Icons.help, size: 14, color: Color(0xFF717171)),
              ],
            ],
          ),
          Text(
            isFree
                ? 'Grátis'
                : NumberFormat.simpleCurrency(locale: 'pt_BR').format(value),
            style: TextStyle(
              fontSize: 14,
              color: isFree ? const Color(0xFF008E2F) : const Color(0xFF717171),
              fontWeight: isFree ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddToBagButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TextButton(
          onPressed: () => _handleReorder(context),
          child: const Text(
            'Adicionar à sacola',
            style: TextStyle(
              color: Color(0xFFEA1D2C),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReorder(BuildContext context) async {
    final storeCubit = context.read<StoreCubit>();
    final catalogCubit = context.read<CatalogCubit>();
    final cartCubit = context.read<CartCubit>();
    final store = storeCubit.state.store;

    // 1. Valida status da loja
    final status = StoreStatusService.validateStoreStatus(store);
    if (!status.canReceiveOrders) {
      if (context.mounted) {
        StoreClosedHelper.showModal(context, nextOpenTime: status.message);
      }
      return;
    }

    try {
      final payloads = OrderReorderHelper.buildPayloads(
        order: _currentOrder,
        products: catalogCubit.state.products ?? const [],
        categories: catalogCubit.state.categories ?? const [],
      );

      for (final payload in payloads) {
        await cartCubit.updateItem(payload);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Itens adicionados à sacola!'),
            backgroundColor: Colors.green,
          ),
        );
        // Opcional: navegar para o carrinho
        // context.push('/cart');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar itens: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPaymentSection() {
    final payment = _currentOrder.payments.primaryMethod;
    if (payment == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pagamento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPaymentIcon(payment.method.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${payment.type.isOnline ? '' : 'Pagamento na entrega • '}${payment.displayName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                    if (_currentOrder.needsChange)
                      Text(
                        'Troco para ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(_currentOrder.changeFor)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF717171),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentIcon(String method) {
    IconData icon;
    switch (method.toUpperCase()) {
      case 'CASH':
      case 'DINHEIRO':
        icon = Icons.payments;
        break;
      case 'PIX':
        icon = Icons.pix;
        break;
      case 'CREDIT_CARD':
      case 'DEBIT_CARD':
        icon = Icons.credit_card;
        break;
      default:
        icon = Icons.payment;
    }
    return Icon(icon, color: Colors.green, size: 28);
  }

  Widget _buildConfirmArrivalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seu pedido chegou?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Confirme quando receber pra gente saber se deu tudo certo',
            style: TextStyle(fontSize: 13, color: Color(0xFF717171)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showConfirmDeliveryModal(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEA1D2C)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirmar entrega',
                style: TextStyle(
                  color: Color(0xFFEA1D2C),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDeliveryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Placeholder para a imagem do ícone do iFood/Entregador
              const Icon(
                Icons.delivery_dining,
                size: 80,
                color: Color(0xFFEA1D2C),
              ),
              const SizedBox(height: 24),
              const Text(
                'Você pode confirmar que recebeu seu pedido?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F3E3E),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    context.pop();

                    // TODO: Implementar integração com backend
                    // Por enquanto, apenas atualiza localmente
                    // Futuramente: await context.read<OrdersCubit>().confirmDelivery(widget.order.id);

                    setState(() {
                      _hasJustConfirmed = true;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pedido recebido com sucesso', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Color(0xFF2E7D32),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.all(16),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA1D2C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sim, recebi meu pedido',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  'Voltar',
                  style: TextStyle(
                    color: Color(0xFFEA1D2C),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJustConfirmedWidget(BuildContext context) {
    return Column(
      children: [
        // Green success widget
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Color(0xFF2E7D32), size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Seu pedido foi entregue', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3F3E3E))
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pedido entregue às: ${DateFormat('HH:mm').format(DateTime.now())}', 
                    style: const TextStyle(fontSize: 14, color: Color(0xFF717171))
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF717171)),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Ajuda com o pedido', 
                style: TextStyle(color: Color(0xFFEA1D2C), fontWeight: FontWeight.bold, fontSize: 14)
              ),
            ]
          )
        ),
        // Stars implementation
        _buildReviewSection(context),
      ],
    );
  }

  Widget _buildAddressSection() {
    final address = _currentOrder.delivery.deliveryAddress;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Endereço de entrega',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.black87, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${address.streetName}, ${address.streetNumber ?? "S/N"}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                    Text(
                      '${address.neighborhood}, ${address.city} - ${address.state} - Casa',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF717171),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(BuildContext context) {
    if (_currentOrder.details.reviewed || _currentOrder.storeRating != null) {
      return _buildRatedReviewSection(context);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Quantas estrelas a loja merece?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStoreAvatar(_currentOrder.merchant.logo, 40),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: List.generate(
                    5,
                    (index) => GestureDetector(
                      onTap: () => _startEvaluation(context),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.star_outline,
                          color: Colors.grey,
                          size: 36,
                        ),
                      ),
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

  Widget _buildRatedReviewSection(BuildContext context) {
    final customerName = _currentOrder.customer?.name ?? 'Cliente';
    final storeRating = _currentOrder.storeRating;
    final deliveryRating = _currentOrder.deliveryRating;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'Sua avaliação',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 16),

          // Avaliação da Loja
          const Text(
            'Avaliação da loja',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 12),
          _buildRatingItem(
            name: customerName,
            stars: storeRating?.stars ?? 0,
            comment: storeRating?.comment,
            logoUrl: _currentOrder.merchant.logo,
          ),

          if (deliveryRating != null) ...[
            const SizedBox(height: 24),
            // Avaliação da Entrega
            const Text(
              'Avaliação da entrega',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F3E3E),
              ),
            ),
            const SizedBox(height: 12),
            _buildRatingItem(
              name: customerName,
              stars: deliveryRating.likedDelivery ? 5 : 1,
              logoUrl:
                  widget
                      .order
                      .merchant
                      .logo, // Pode ser o avatar do entregador se disponível
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingItem({
    required String name,
    required int stars,
    String? comment,
    String? logoUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStoreAvatar(logoUrl, 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3F3E3E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < stars ? Icons.star : Icons.star_border,
                        color:
                            index < stars ? Colors.black : Colors.grey.shade300,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Avaliado',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (comment != null && comment.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Text(
              comment,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF717171),
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _startEvaluation(BuildContext context) async {
    // Navigate to evaluation flow
    await context.push(
      '/order/${_currentOrder.id}/evaluate',
      extra: _currentOrder,
    );
  }

  Widget _buildStoreAvatar(String? logoUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F2),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child:
            logoUrl != null && logoUrl.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: _formatImageUrl(logoUrl),
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorWidget:
                      (_, __, ___) =>
                          const Icon(Icons.store, color: Colors.grey),
                )
                : const Icon(Icons.store, color: Colors.grey),
      ),
    );
  }

  Widget _buildProductImage(String? url) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            url != null && url.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: _formatImageUrl(url),
                  fit: BoxFit.cover,
                  width: 64,
                  height: 64,
                  errorWidget:
                      (_, __, ___) =>
                          const Icon(Icons.restaurant, color: Colors.grey),
                )
                : const Icon(Icons.restaurant, color: Colors.grey),
      ),
    );
  }

  String _formatImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://menuhub-dev.s3.us-east-1.amazonaws.com/$url';
  }

  Widget _buildCancelOrderButton(BuildContext context) {
    if (_currentStatus.toUpperCase() != 'PENDING') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          const Divider(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmCancel(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF717171)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'CANCELAR PEDIDO',
                style: TextStyle(
                  color: Color(0xFF717171),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Você pode cancelar enquanto o pedido não for aceito.',
            style: TextStyle(fontSize: 11, color: Color(0xFF717171)),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancelar Pedido?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Tem certeza que deseja cancelar este pedido? Esta ação não pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'MANTER PEDIDO',
                style: TextStyle(color: Colors.black87),
              ),
            ),
            TextButton(
              onPressed: () {
                // ✅ Captura referências ANTES de fechar o dialog
                final messenger = ScaffoldMessenger.of(context);
                final cubit = context.read<OrdersCubit>();
                final orderId = int.tryParse(_currentOrder.id.toString()) ?? 0;

                Navigator.pop(dialogContext);

                cubit.cancelOrder(
                  orderId,
                  reason: 'Cancelado pelo cliente',
                );

                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Cancelando pedido...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'SIM, CANCELAR',
                style: TextStyle(
                  color: Color(0xFFEA1D2C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
