// lib/pages/orders/order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/models/order.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/helpers/order_reorder_helper.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Página de detalhes do pedido completa - Estilo iFood
/// ✅ Suporta pedidos cancelados, concluídos e avaliações
class OrderDetailPage extends StatelessWidget {
  final Order order;

  const OrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return _OrderDetailContent(order: order);
  }
}

class _OrderDetailContent extends StatefulWidget {
  final Order order;

  const _OrderDetailContent({required this.order});

  @override
  State<_OrderDetailContent> createState() => _OrderDetailContentState();
}

class _OrderDetailContentState extends State<_OrderDetailContent> {
  Order get order => widget.order;

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
            fontSize: 16,
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
            _buildStoreHeader(),
            _buildStatusBanner(),
            _buildProductList(),
            _buildValuesSummary(),
            if (order.isConcluded) _buildAddToBagButton(),
            _buildPaymentSection(),
            _buildAddressSection(),
            if (order.isConcluded) _buildReviewSection(),
            const SizedBox(
              height: 100,
            ), // Espaço para não ficar colado no bottom
          ],
        ),
      ),
    );
  }

  Widget _buildStoreHeader() {
    final dateFormat = DateFormat('dd/MM/yyyy • HH:mm', 'pt_BR');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStoreAvatar(order.merchant.logo, 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.merchant.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pedido nº ${order.sequentialId} • ${dateFormat.format(order.createdAt)}',
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
                // TODO: Ir para cardápio
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
    String message = '';
    IconData icon = Icons.info;
    Color iconColor = Colors.grey;

    if (order.isCancelled) {
      message =
          'A loja não confirmou seu pedido e ele foi cancelado. Nenhuma cobrança será feita. Que tal fazer um novo pedido?';
      icon = Icons.cancel;
      iconColor = Colors.black87;
    } else if (order.isConcluded) {
      final time = DateFormat(
        'HH:mm',
      ).format(order.closedAt ?? order.updatedAt);
      message = 'Pedido concluído às $time';
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else {
      message = 'Pedido em andamento: ${order.statusLabel}';
      icon = Icons.access_time;
      iconColor = Colors.orange;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
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

  Widget _buildProductList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: order.items.map((item) => _buildProductItem(item)).toList(),
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
                bottom: 6,
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
                          fontWeight: FontWeight.w600,
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
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Sub-itens formatados como no carrinho
                if (item.subItems.isNotEmpty) _buildVariantsSection(item),
                // Observações
                if (item.hasNotes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      item.notes!,
                      style: const TextStyle(
                        fontSize: 13,
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

      final isFlavorGroup = groupType == OptionGroupType.topping;
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
        _buildVariantRow('1', combinedText, price: 0),
      );
    }

    // 2. Sabores
    final flavorCount = flavorOptions.length;
    final fractionText = flavorCount > 1 ? '1/$flavorCount ' : '';
    for (final flavor in flavorOptions) {
      String name = flavor.name;
      name = name.replaceAll(RegExp(r'^1/\d+\s*'), '').trim();
      
      lineWidgets.add(
        _buildVariantRow('1', '$fractionText$name', price: 0),
      );
    }

    // 3. Outros
    for (final other in otherOptions) {
      lineWidgets.add(
        _buildVariantRow(
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

  Widget _buildVariantRow(String quantity, String text, {int price = 0}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuantityBox(int.tryParse(quantity) ?? 1),
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

  Widget _buildQuantityBox(int qty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$qty',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF717171),
        ),
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
          _buildSummaryRow('Subtotal', order.subtotalAmount),
          _buildSummaryRow(
            'Taxa de entrega',
            order.deliveryFeeAmount,
            isFree: order.deliveryFeeAmount == 0,
          ),
          _buildSummaryRow('Taxa de serviço', 0.99, hasHelp: true),
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
                ).format(order.totalAmount),
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

  Widget _buildAddToBagButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextButton(
        onPressed: () => _handleReorder(context, order),
        child: const Text(
          'Adicionar à sacola',
          style: TextStyle(
            color: Color(0xFFEA1D2C),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    final payment = order.payments.primaryMethod;
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
                    if (order.needsChange)
                      Text(
                        'Troco para ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(order.changeFor)}',
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

  Widget _buildAddressSection() {
    final address = order.delivery.deliveryAddress;
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

  Widget _buildReviewSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Sua avaliação',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Avaliação da loja',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStoreAvatar(order.merchant.logo, 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.merchant.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.star, color: Colors.black87, size: 16),
                        Icon(Icons.star, color: Colors.black87, size: 16),
                        Icon(Icons.star, color: Colors.black87, size: 16),
                        Icon(Icons.star, color: Colors.black87, size: 16),
                        Icon(Icons.star, color: Colors.black87, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
              const Text(
                'Avaliado',
                style: TextStyle(
                  color: Color(0xFF008E2F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Avaliação da entrega',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3F3E3E),
            ),
          ),
          // Adicione mais se houver avaliação de entrega
        ],
      ),
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

Future<void> _handleReorder(BuildContext context, Order order) async {
  final catalogCubit = context.read<CatalogCubit>();
  final cartCubit = context.read<CartCubit>();

  // Verifica se o catálogo está carregado
  if (catalogCubit.state.products == null ||
      catalogCubit.state.products!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catálogo não disponível. Tente novamente.'),
      ),
    );
    return;
  }

  try {
    final payloads = OrderReorderHelper.buildPayloads(
      order: order,
      products: catalogCubit.state.products!,
      categories: catalogCubit.state.categories!,
    );

    for (final payload in payloads) {
      await cartCubit.updateItem(payload);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Itens adicionados ao carrinho!')),
    );
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Erro ao adicionar itens: $e')));
  }
}
