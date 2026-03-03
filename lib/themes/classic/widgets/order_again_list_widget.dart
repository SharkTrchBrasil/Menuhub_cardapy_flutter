import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/orders_cubit.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/order.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/models/update_cart_payload.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';

class OrderAgainListWidget extends StatelessWidget {
  const OrderAgainListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, state) {
        // Filter for orders that are worth showing (e.g. CONCLUDED or recent)
        // For now, take all valid orders that have items.
        // We reverse to show most recent first if not already sorted.
        final pastOrders =
            state.orders
                .where(
                  (o) => o.lastStatus == 'CONCLUDED' && o.bag.items.isNotEmpty,
                )
                .take(5)
                .toList();

        if (pastOrders.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Peça novamente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F1F1F),
                ),
              ),
            ),
            SizedBox(
              height: 150, // Height for the card
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: pastOrders.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return _OrderAgainCard(order: pastOrders[index]);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _OrderAgainCard extends StatelessWidget {
  final Order order;

  const _OrderAgainCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final items = order.bag.items; // List<BagItem>
    final totalItemCount = order.bag.itemCount; // Total quantity of items

    // Images: Get unique non-null images.
    final images =
        items
            .map((i) => i.logoUrl)
            .where((url) => url != null && url.isNotEmpty)
            .toSet() // Dedupe images
            .toList();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4), // Inner padding
      child: Row(
        children: [
          // Left: Image Grid (Square aspect ratio approx)
          SizedBox(
            width: 110, // Approx 110xHeight
            height: double.infinity,
            child: _buildImageGrid(images, totalItemCount),
          ),
          const SizedBox(width: 12),
          // Right: Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item List (Top 2 items)
                  ...items
                      .take(2)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${item.quantity} ${item.name}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF4A4A4A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  // +N items
                  if (items.length > 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+ ${totalItemCount - items.take(2).fold(0, (sum, i) => sum + i.quantity)} itens',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // ✅ CORREÇÃO: Mostra subtotal (apenas produtos), não total com frete
                  Text(
                    order.subtotalAmount.toCurrency(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _addOrderToCart(context),
                    child: Text(
                      'Adicionar à sacola',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<String?> images, int totalCount) {
    if (images.isEmpty) {
      return Container(color: Colors.grey.shade100);
    }

    final count = images.length;

    // Layout based on count
    if (count == 1) {
      // Single image covering the whole space
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageTile(images[0]),
      );
    } else if (count == 2) {
      // Split vertically (two tall images)
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(child: _buildImageTile(images[0])),
            const SizedBox(width: 1),
            Expanded(child: _buildImageTile(images[1])),
          ],
        ),
      );
    } else if (count == 3) {
      // 3 images: 1 big on left, 2 small on right (stacked)
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(child: _buildImageTile(images[0])),
            const SizedBox(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildImageTile(images[1])),
                  const SizedBox(height: 1),
                  Expanded(child: _buildImageTile(images[2])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4 or more: 2x2 Grid
    String? getImg(int idx) => (idx < count) ? images[idx] : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildImageTile(getImg(0))),
                const SizedBox(width: 1),
                Expanded(child: _buildImageTile(getImg(1))),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildImageTile(getImg(2))),
                const SizedBox(width: 1),
                Expanded(
                  child: _buildImageTile(
                    getImg(3),
                    // If we have more items than shown (4), display overlay logic
                    overlayText: (totalCount > 4) ? '+${totalCount - 3}' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile(String? url, {String? overlayText}) {
    if (url == null) {
      return Container(color: Colors.grey.shade100);
    }

    // SANITIZATION LOGIC START
    var smoothUrl = url;
    // Fix: Remove 'None/' prefix if present (backend bug artifact)
    if (smoothUrl.startsWith('None/')) {
      smoothUrl = smoothUrl.substring(5);
    }
    // Fix: Prepend domain if relative path
    if (!smoothUrl.startsWith('http')) {
      // Hardcoded base URL based on logs (fallback)
      smoothUrl = 'https://api-pdvix-production.up.railway.app/$smoothUrl';
    }
    // SANITIZATION LOGIC END

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          smoothUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade100),
        ),
        if (overlayText != null)
          Container(
            color: Colors.black.withOpacity(0.5),
            alignment: Alignment.center,
            child: Text(
              overlayText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addOrderToCart(BuildContext context) async {
    final cartCubit = context.read<CartCubit>();
    final products = context.read<CatalogCubit>().state.products ?? [];

    int addedCount = 0;

    for (final bagItem in order.bag.items) {
      // Find product by external ID (which maps to Product ID)
      // Fallback: name match covering potential type issues
      final product =
          products.firstWhereOrNull(
            (p) => p.id.toString() == bagItem.externalId,
          ) ??
          products.firstWhereOrNull((p) => p.name == bagItem.name);

      if (product != null && product.id != null) {
        // Resolve category ID
        final categoryId =
            product.primaryCategoryId ??
            (product.categoryLinks.isNotEmpty
                ? product.categoryLinks.first.categoryId
                : 0);

        final payload = UpdateCartItemPayload(
          productId: product.id!,
          categoryId: categoryId,
          quantity: bagItem.quantity,
          note: bagItem.notes,
          // variants: skipped for now
        );

        try {
          await cartCubit.updateItem(payload);
          addedCount++;
        } catch (e) {
          // Ignore individual failures
        }
      }
    }

    if (context.mounted) {
      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedCount itens adicionados à sacola!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível readicionar os itens (produtos não encontrados).',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
