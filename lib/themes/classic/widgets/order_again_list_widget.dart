import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:totem/cubit/orders_cubit.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/product_variant_link.dart';
import 'package:totem/models/order.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/models/update_cart_payload.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/services/store_status_service.dart';

import '../../../models/cart_item.dart';

class OrderAgainListWidget extends StatefulWidget {
  const OrderAgainListWidget({super.key});

  @override
  State<OrderAgainListWidget> createState() => _OrderAgainListWidgetState();
}

class _OrderAgainListWidgetState extends State<OrderAgainListWidget> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, storeState) {
        // ✅ Mantém sincronizado em tempo real com o status da loja
        final canOrder =
            StoreStatusService.validateStoreStatus(
              storeState.store,
            ).canReceiveOrders;
        if (!canOrder) return const SizedBox.shrink();

        return BlocBuilder<OrdersCubit, OrdersState>(
          builder: (context, state) {
            // Filter for orders that are worth showing (e.g. CONCLUDED or recent)
            // For now, take all valid orders that have items.
            // We reverse to show most recent first if not already sorted.
            final pastOrders =
                state.orders
                    .where(
                      (o) =>
                          o.lastStatus == 'CONCLUDED' && o.bag.items.isNotEmpty,
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
                    separatorBuilder:
                        (context, index) => const SizedBox(width: 16),
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
      },
    );
  }
}

class _OrderAgainCard extends StatefulWidget {
  final Order order;

  const _OrderAgainCard({required this.order});

  @override
  State<_OrderAgainCard> createState() => _OrderAgainCardState();
}

class _OrderAgainCardState extends State<_OrderAgainCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.order.bag.items; // List<BagItem>
    final totalItemCount =
        widget.order.bag.itemCount; // Total quantity of items

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
                    widget.order.subtotalAmount.toCurrency(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap:
                        _isProcessing
                            ? null
                            : () => _addOrderToCart(context, widget.order),
                    child:
                        _isProcessing
                            ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            )
                            : Text(
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

  String _normalizeName(String? value) {
    if (value == null) return '';
    return value
        .toLowerCase()
        .replaceAll('massa ', '')
        .replaceAll('borda ', '')
        .replaceAll('+', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  OptionGroup? _findRegularGroup({
    required Category category,
    required Product product,
    required String groupName,
    required List<SubItem> subItems,
  }) {
    final productGroups = category.productOptionGroups?[product.id] ?? const [];
    final allGroups = [...productGroups, ...category.optionGroups];

    final byName = allGroups.firstWhereOrNull(
      (group) => _normalizeName(group.name) == _normalizeName(groupName),
    );
    if (byName != null) {
      return byName;
    }

    return allGroups.firstWhereOrNull((group) {
      return subItems.every((subItem) {
        final subId = int.tryParse(subItem.externalId ?? '');
        final normalizedSubName = _normalizeName(subItem.name);

        return group.items.any(
          (item) =>
              (subId != null && item.id == subId) ||
              _normalizeName(item.name) == normalizedSubName,
        );
      });
    });
  }

  OptionItem? _findRegularOptionItem({
    required OptionGroup group,
    required SubItem subItem,
  }) {
    final subId = int.tryParse(subItem.externalId ?? '');
    final normalizedSubName = _normalizeName(subItem.name);

    return group.items.firstWhereOrNull(
          (item) => subId != null && item.id == subId,
        ) ??
        group.items.firstWhereOrNull(
          (item) => _normalizeName(item.name) == normalizedSubName,
        );
  }

  ProductVariantLink? _findRegularVariantLink({
    required Product product,
    required String groupName,
    required List<SubItem> subItems,
  }) {
    final byName = product.variantLinks.firstWhereOrNull(
      (link) => _normalizeName(link.variant.name) == _normalizeName(groupName),
    );
    if (byName != null) {
      return byName;
    }

    return product.variantLinks.firstWhereOrNull((link) {
      return subItems.every((subItem) {
        final subId = int.tryParse(subItem.externalId ?? '');
        final normalizedSubName = _normalizeName(subItem.name);

        return link.variant.options.any(
          (option) =>
              (subId != null && option.id == subId) ||
              _normalizeName(option.resolvedName) == normalizedSubName,
        );
      });
    });
  }

  int? _findRegularVariantOptionId({
    required ProductVariantLink variantLink,
    required SubItem subItem,
  }) {
    final subId = int.tryParse(subItem.externalId ?? '');
    final normalizedSubName = _normalizeName(subItem.name);

    return variantLink.variant.options
            .firstWhereOrNull((option) => subId != null && option.id == subId)
            ?.id ??
        variantLink.variant.options
            .firstWhereOrNull(
              (option) =>
                  _normalizeName(option.resolvedName) == normalizedSubName,
            )
            ?.id;
  }

  OptionGroup? _findPizzaGroup({
    required Category category,
    required Product product,
    required SubItem subItem,
  }) {
    final parsedType = OptionGroupType.fromString(subItem.groupType);
    final productGroups =
        category.productOptionGroups?[product.id] ??
        category.productOptionGroups?[product.linkedProductId ?? -1] ??
        const [];

    if (parsedType != OptionGroupType.other) {
      final productGroup = productGroups.firstWhereOrNull(
        (g) => g.groupType == parsedType,
      );
      if (productGroup != null) return productGroup;

      final categoryGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == parsedType,
      );
      if (categoryGroup != null) return categoryGroup;
    }

    final normalizedGroupName = _normalizeName(subItem.groupName);
    final normalizedSubName = _normalizeName(subItem.name);

    return productGroups.firstWhereOrNull(
          (g) =>
              _normalizeName(g.name) == normalizedGroupName ||
              _normalizeName(g.name) == normalizedSubName,
        ) ??
        category.optionGroups.firstWhereOrNull(
          (g) =>
              _normalizeName(g.name) == normalizedGroupName ||
              _normalizeName(g.name) == normalizedSubName,
        );
  }

  OptionItem? _findPizzaOptionItem({
    required OptionGroup? group,
    required SubItem subItem,
  }) {
    final externalId = int.tryParse(subItem.externalId ?? '');

    if (externalId != null) {
      final byId = group?.items.firstWhereOrNull(
        (item) => item.id == externalId,
      );
      if (byId != null) return byId;
    }

    final normalizedSubName = _normalizeName(subItem.name);

    var byName = group?.items.firstWhereOrNull(
      (item) => _normalizeName(item.name) == normalizedSubName,
    );
    if (byName != null) return byName;

    final cleanName =
        subItem.name.replaceAll(RegExp(r'^\d+/\d+\s+'), '').trim();
    final normalizedCleanName = _normalizeName(cleanName);

    return group?.items.firstWhereOrNull(
      (item) => _normalizeName(item.name) == normalizedCleanName,
    );
  }

  List<CartItemVariant> _buildPizzaVariants({
    required Category category,
    required Product product,
    required BagItem bagItem,
  }) {
    final groupedOptions = <String, List<CartItemVariantOption>>{};
    final groupedIds = <String, int?>{};
    final groupedTypes = <String, String?>{};
    final groupedNames = <String, String>{};

    for (final sub in bagItem.subItems) {
      final group = _findPizzaGroup(
        category: category,
        product: product,
        subItem: sub,
      );
      final optionItem = _findPizzaOptionItem(group: group, subItem: sub);
      final groupType =
          group?.groupType.toApiString() ??
          OptionGroupType.fromString(sub.groupType).toApiString();
      final groupName = group?.name ?? sub.groupName ?? 'Opções';
      final groupId = group?.id;
      final optionName = switch (group?.groupType ??
          OptionGroupType.fromString(sub.groupType)) {
        OptionGroupType.crust =>
          sub.name.toLowerCase().startsWith('massa ')
              ? sub.name
              : 'Massa ${sub.name}',
        OptionGroupType.edge =>
          sub.name.toLowerCase().startsWith('borda ')
              ? sub.name
              : 'Borda ${sub.name}',
        _ => sub.name,
      };

      final key = '${groupId ?? groupName}::$groupType';
      final option = CartItemVariantOption(
        optionItemId: optionItem?.id ?? int.tryParse(sub.externalId ?? ''),
        variantOptionId: null,
        quantity: sub.quantity,
        name: optionName,
        price: sub.unitPrice,
      );

      groupedOptions
          .putIfAbsent(key, () => <CartItemVariantOption>[])
          .add(option);
      groupedIds[key] = groupId;
      groupedTypes[key] = groupType;
      groupedNames[key] = groupName;
    }

    return groupedOptions.entries
        .map(
          (entry) => CartItemVariant(
            optionGroupId: groupedIds[entry.key],
            variantId: null,
            groupType: groupedTypes[entry.key],
            name: groupedNames[entry.key] ?? 'Opções',
            options: entry.value,
          ),
        )
        .toList();
  }

  List<CartItemVariant> _buildRegularVariants({
    required Category? category,
    required Product product,
    required BagItem bagItem,
  }) {
    final variants = <CartItemVariant>[];

    if (bagItem.subItems.isEmpty) {
      return variants;
    }

    final groupedSubItems = groupBy(
      bagItem.subItems,
      (SubItem s) => s.groupName ?? 'Opções',
    );

    for (final entry in groupedSubItems.entries) {
      final groupName = entry.key;
      final subs = entry.value;

      int? variantId;
      int? optionGroupId;
      String? groupType;
      OptionGroup? optGroup;
      ProductVariantLink? variantLink;

      variantLink = _findRegularVariantLink(
        product: product,
        groupName: groupName,
        subItems: subs,
      );

      if (variantLink?.variant.id != null) {
        variantId = variantLink!.variant.id;
      }

      if (category != null) {
        optGroup = _findRegularGroup(
          category: category,
          product: product,
          groupName: groupName,
          subItems: subs,
        );

        if (optGroup != null) {
          optionGroupId = optGroup.id;
          groupType = optGroup.groupType.toApiString();
        }
      }

      final options = <CartItemVariantOption>[];
      for (final sub in subs) {
        final matchedVariantOptionId =
            variantLink != null
                ? _findRegularVariantOptionId(
                  variantLink: variantLink,
                  subItem: sub,
                )
                : null;
        final matchedOption =
            optGroup != null
                ? _findRegularOptionItem(group: optGroup, subItem: sub)
                : null;
        final id =
            matchedVariantOptionId ??
            matchedOption?.id ??
            int.tryParse(sub.externalId ?? '');

        options.add(
          CartItemVariantOption(
            optionItemId:
                (groupType == 'TOPPING' ||
                        groupType == 'CRUST' ||
                        groupType == 'EDGE' ||
                        groupType == 'SIZE')
                    ? id
                    : null,
            variantOptionId:
                (groupType != 'TOPPING' &&
                        groupType != 'CRUST' &&
                        groupType != 'EDGE' &&
                        groupType != 'SIZE')
                    ? id
                    : null,
            quantity: sub.quantity,
            name: sub.name,
            price: sub.unitPrice,
          ),
        );
      }

      if (options.isNotEmpty) {
        variants.add(
          CartItemVariant(
            variantId: variantId,
            optionGroupId: optionGroupId,
            groupType: groupType,
            name: variantLink?.variant.name ?? groupName,
            options: options,
          ),
        );
      }
    }

    return variants;
  }

  Future<void> _addOrderToCart(BuildContext context, Order order) async {
    // Se já está processando, não faz nada
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final cartCubit = context.read<CartCubit>();

    try {
      final products = context.read<CatalogCubit>().state.products ?? [];

      print(
        '🔄 [ORDER_AGAIN] Iniciando adição de ${order.bag.items.length} itens ao carrinho',
      );

      cartCubit.setOrderAgainProcessing(true);

      // Coleta todos os payloads primeiro antes de adicionar ao carrinho
      final payloads = <UpdateCartItemPayload>[];
      int addedCount = 0;
      int skippedCount = 0;

      for (final bagItem in order.bag.items) {
        print(
          '🔍 [ORDER_AGAIN] Processando: ${bagItem.name} (externalId: ${bagItem.externalId})',
        );

        // Find product by external ID (which maps to Product ID)
        // Fallback: name match covering potential type issues
        final product =
            products.firstWhereOrNull(
              (p) => p.id.toString() == bagItem.externalId,
            ) ??
            products.firstWhereOrNull((p) => p.name == bagItem.name);

        if (product == null) {
          print(
            '❌ [ORDER_AGAIN] Produto não encontrado no catálogo: ${bagItem.name}',
          );
          print('   Tentou buscar por externalId: ${bagItem.externalId}');
          print(
            '   Produtos disponíveis: ${products.map((p) => '${p.id}:${p.name}').take(5).join(", ")}...',
          );
          skippedCount++;
          continue;
        }

        if (product.id == null) {
          print(
            '❌ [ORDER_AGAIN] Produto encontrado mas sem ID: ${bagItem.name}',
          );
          skippedCount++;
          continue;
        }

        if (product != null && product.id != null) {
          print(
            '✅ [ORDER_AGAIN] Produto encontrado: ${product.name} (ID: ${product.id})',
          );
          // Resolve category ID
          final categoryId =
              product.primaryCategoryId ??
              (product.categoryLinks.isNotEmpty
                  ? product.categoryLinks.first.categoryId
                  : 0);

          // Find the category in the catalog to get option groups
          final catalogCubit = context.read<CatalogCubit>();
          final category = catalogCubit.state.categories?.firstWhereOrNull(
            (c) => c.id == categoryId,
          );

          String? sizeName;
          String? sizeImageUrl;

          final variants =
              (category?.isCustomizable ?? false)
                  ? _buildPizzaVariants(
                    category: category!,
                    product: product,
                    bagItem: bagItem,
                  )
                  : _buildRegularVariants(
                    category: category,
                    product: product,
                    bagItem: bagItem,
                  );

          if (category?.isCustomizable ?? false) {
            sizeName = bagItem.name;
            sizeImageUrl =
                (bagItem.logoUrl != null && bagItem.logoUrl!.isNotEmpty)
                    ? bagItem.logoUrl
                    : product.imageUrl;
          }

          final payload = UpdateCartItemPayload(
            productId: product.id!,
            categoryId: categoryId,
            quantity: bagItem.quantity,
            note: bagItem.notes,
            sizeName: sizeName,
            sizeImageUrl: sizeImageUrl,
            variants: variants.isNotEmpty ? variants : null,
          );

          payloads.add(payload);
          addedCount++;
        }
      }

      // Adiciona todos os itens em lote
      print(
        '📤 [ORDER_AGAIN] Adicionando ${payloads.length} itens ao carrinho em lote',
      );

      for (final payload in payloads) {
        try {
          await cartCubit.updateItem(payload);
          print('✅ [ORDER_AGAIN] Item adicionado: ${payload.productId}');
        } catch (e) {
          print(
            '❌ [ORDER_AGAIN] Erro ao adicionar item ${payload.productId}: $e',
          );
          addedCount--;
        }
      }

      print(
        '📊 [ORDER_AGAIN] Resumo: $addedCount adicionados, $skippedCount pulados',
      );

      // Removendo SnackBar para evitar erro de widget desativado
      // A barra flutuante já mostra o status visualmente durante o processamento
    } catch (e) {
      print('❌ [ORDER_AGAIN] Erro durante processamento: $e');
    } finally {
      cartCubit.setOrderAgainProcessing(false);
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
