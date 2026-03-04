// lib/pages/order/order_details_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/models/order.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/services/store_status_service.dart';
import 'package:totem/widgets/store_closed_widgets.dart';
import 'package:totem/models/update_cart_payload.dart';
import 'package:totem/models/cart_item.dart';
import 'package:totem/models/product.dart';
import 'package:totem/core/services/timezone_service.dart';
import 'package:totem/pages/order/widgets/order_status_progress_bar.dart';

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
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.lastStatus;
  }

  bool get _isConcluded =>
      _currentStatus.toUpperCase() == 'CONCLUDED' || widget.order.isConcluded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            _buildStatusBanner(),
            if (_currentStatus.toUpperCase() == 'DISPATCHED')
              _buildConfirmArrivalCard(context),
            _buildProductList(),
            _buildValuesSummary(),
            if (_isConcluded) _buildAddToBagButton(context),
            _buildPaymentSection(),
            _buildAddressSection(),
            if (widget.showRating || _isConcluded) _buildReviewSection(context),
            const SizedBox(height: 100),
          ],
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
              _buildStoreAvatar(widget.order.merchant.logo, 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order.merchant.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pedido nº ${widget.order.sequentialId} • ${TimezoneService.formatStoreDateTime(widget.order.createdAt, context.read<StoreCubit>().state.store?.timezone ?? "America/Sao_Paulo", format: 'dd/MM/yyyy • HH:mm')}',
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
    if (widget.order.isSystemCancelled) {
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

    // Para todos os outros casos (em andamento, concluído ou cancelado pelo lojista),
    // usa o widget de progresso replicado do Admin
    return OrderStatusProgressBar(order: widget.order);
  }

  Widget _buildProductList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children:
            widget.order.items.map((item) => _buildProductItem(item)).toList(),
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

    int massaPrice = 0;
    int bordaPrice = 0;

    for (final sub in item.subItems) {
      if (sub.quantity <= 0) continue;

      final groupType = OptionGroupType.fromString(sub.groupType);
      final groupNameLower = sub.groupName?.toLowerCase() ?? '';
      final nameLower = sub.name.toLowerCase();

      final isFlavorGroup = groupType == OptionGroupType.topping;
      final isMassaGroup = groupType == OptionGroupType.crust;
      final isBordaGroup = groupType == OptionGroupType.edge;

      // Detecta Massa
      if (isMassaGroup && massaText == null) {
        massaText = sub.name;
        massaPrice = sub.totalPrice ~/ sub.quantity;
        continue;
      }

      // Detecta Borda
      if (isBordaGroup && bordaText == null) {
        bordaText = sub.name;
        bordaPrice = sub.totalPrice ~/ sub.quantity;
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
            massaPrice = sub.totalPrice ~/ sub.quantity;
            bordaPrice = 0;
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
      int combinedPrice = massaPrice + bordaPrice;

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
        _buildVariantRow(context, '1', combinedText, price: combinedPrice),
      );
    }

    // 2. Sabores
    final flavorCount = flavorOptions.length;
    final fractionText = flavorCount > 1 ? '1/$flavorCount ' : '';
    for (final flavor in flavorOptions) {
      String name = flavor.name;
      name = name.replaceAll(RegExp(r'^1/\d+\s*'), '').trim();
      final flavorPrice = flavor.totalPrice ~/ flavor.quantity;
      lineWidgets.add(
        _buildVariantRow(
          context,
          '1',
          '$fractionText$name',
          price: flavorPrice,
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
          price: other.totalPrice ~/ other.quantity,
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
    String text, {
    int price = 0,
  }) {
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
          if (price > 0) ...[
            const SizedBox(width: 8),
            Text(
              NumberFormat.simpleCurrency(
                locale: 'pt_BR',
              ).format(price / 100.0),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF717171).withOpacity(0.8),
              ),
            ),
          ],
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
          _buildSummaryRow('Subtotal', widget.order.subtotalAmount),
          _buildSummaryRow(
            'Taxa de entrega',
            widget.order.deliveryFeeAmount,
            isFree: widget.order.deliveryFeeAmount == 0,
          ),
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
                ).format(widget.order.totalAmount),
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
      // 2. Itera pelos itens do pedido e reconstrói payloads
      for (final item in widget.order.items) {
        final product = catalogCubit.state.products?.firstWhere(
          (p) => p.id.toString() == item.id,
          orElse: () => Product.empty().copyWith(id: int.tryParse(item.id)),
        );

        final categoryId = product?.primaryCategoryId ?? 0;

        // Reconstrói variantes se existirem
        List<CartItemVariant>? variants;
        if (item.subItems.isNotEmpty) {
          // Nota: BagItem -> SubItem mapeia para CartItemVariant -> CartItemVariantOption
          // No entanto, BagItem não preserva a estrutura exata de Variant/OptionGroup
          // Aqui fazemos uma reconstrução aproximada simplificada ou apenas enviamos o que temos
          // Como o backend iFood simplifica isso, talvez precisemos de mais metadados
          // Para esta implementação inicial, focamos em produtos simples.
          // Se for pizza, o payload requer option_group_id.
        }

        final payload = UpdateCartItemPayload(
          productId: int.tryParse(item.id) ?? 0,
          categoryId: categoryId,
          quantity: item.quantity,
          note: item.notes,
          // sizeName e variants seriam reconstruídos aqui se tivéssemos os IDs originais
        );

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
    final payment = widget.order.payments.primaryMethod;
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
                    if (widget.order.needsChange)
                      Text(
                        'Troco para ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(widget.order.changeFor)}',
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
                  onPressed: () {
                    context.pop();
                    // Simulando conclusão do pedido localmente
                    setState(() {
                      _currentStatus = 'CONCLUDED';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Entrega confirmada!')),
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

  Widget _buildAddressSection() {
    final address = widget.order.delivery.deliveryAddress;
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
              _buildStoreAvatar(widget.order.merchant.logo, 40),
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

  void _startEvaluation(BuildContext context) {
    // Navigate to evaluation flow
    context.push('/order/${widget.order.id}/evaluate', extra: widget.order);
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
}
