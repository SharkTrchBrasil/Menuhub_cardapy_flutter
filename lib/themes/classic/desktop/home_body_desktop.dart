// Versão profissional com scroll dinâmico, atualização dos offsets e detecção do fim da lista

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/banners.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/themes/classic/desktop/widgets/featured_list.dart';
import 'package:totem/themes/classic/desktop/widgets/product_grid_list.dart';
import 'package:totem/themes/classic/desktop/widgets/size_grid_list.dart';
import 'package:totem/themes/classic/desktop/widgets/store_details_sidepanel.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/delivery_info_widget.dart';
import '../../../helpers/navigation_helper.dart';
import 'package:totem/helpers/store_hours_helper.dart';
import 'package:totem/services/store_status_service.dart';
import '../../../models/store.dart';
import '../../../repositories/realtime_repository.dart';

class HomeBodyDesktop extends StatefulWidget {
  final Store? store;
  final List<BannerModel> banners;
  final List<Category> categories;
  final List<Product> products;
  final Category? selectedCategory;
  final Function(Category?) onCategorySelected;

  const HomeBodyDesktop({
    super.key,
    required this.store,
    required this.banners,
    required this.categories,
    required this.products,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<HomeBodyDesktop> createState() => _HomeBodyDesktopState();
}

class _HomeBodyDesktopState extends State<HomeBodyDesktop> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Map<int, GlobalKey> _categoryKeys = {};
  final Map<int, double> _categoryOffsets = {};
  List<Product> _filteredProducts = [];
  bool _showCategoryFilterInBar = false;
  final double _scrollThreshold = 300.0;

  @override
  void initState() {
    super.initState();
    _initializeState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);

    // ✅ NOVO: Registra visita ao cardápio via Socket.IO
    _recordMenuVisit();
  }

  @override
  void didUpdateWidget(HomeBodyDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories ||
        widget.products != oldWidget.products) {
      _initializeState();
    }
  }

  void _initializeState() {
    _filteredProducts = widget.products;
    _categoryKeys.clear();
    for (var category in widget.categories) {
      if (category.id != null) {
        _categoryKeys[category.id!] = GlobalKey();
      }
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _calculateCategoryOffsets(),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.products;
      } else {
        _filteredProducts =
            widget.products.where((product) {
              return product.name.toLowerCase().contains(query);
            }).toList();
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _calculateCategoryOffsets(),
      );
    });
  }

  void _calculateCategoryOffsets() {
    _categoryOffsets.clear();
    for (var entry in _categoryKeys.entries) {
      final key = entry.value;
      if (key.currentContext != null) {
        final renderObject = key.currentContext!.findRenderObject();
        if (renderObject is RenderSliver) {
          final offset = renderObject.constraints.precedingScrollExtent;
          _categoryOffsets[entry.key] = offset;
        }
      }
    }
  }

  void _scrollToCategory(int categoryId) {
    final key = _categoryKeys[categoryId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        alignment: 0.1,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onScroll() {
    final currentScrollOffset = _scrollController.offset;
    Category? newSelectedCategory;
    const stickyHeaderHeight = 80.0;
    final selectionThreshold = currentScrollOffset + stickyHeaderHeight;

    for (var category in widget.categories) {
      final categoryId = category.id;
      if (categoryId != null && _categoryOffsets.containsKey(categoryId)) {
        final categoryOffset = _categoryOffsets[categoryId]!;
        if (selectionThreshold >= categoryOffset) {
          newSelectedCategory = category;
        }
      }
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      final lastCategoryWithProducts = widget.categories.lastWhereOrNull((cat) {
        // Categorias customizáveis (pizzas) sempre aparecem
        if (cat.isCustomizable) {
          return true;
        }

        // Verifica se há produtos com categoryLinks apontando para esta categoria
        final hasProductsWithLinks = _filteredProducts.any(
          (p) => p.categoryLinks.any((link) => link.categoryId == cat.id),
        );

        // Verifica se a categoria tem productLinks que correspondem a produtos existentes
        final hasCategoryLinks =
            cat.productLinks.isNotEmpty &&
            cat.productLinks.any(
              (link) => _filteredProducts.any((p) => p.id == link.productId),
            );

        return hasProductsWithLinks || hasCategoryLinks;
      });
      if (lastCategoryWithProducts != null) {
        newSelectedCategory = lastCategoryWithProducts;
      }
    }

    if (widget.selectedCategory?.id != newSelectedCategory?.id) {
      widget.onCategorySelected(newSelectedCategory);
    }

    final shouldShow = _scrollController.offset > _scrollThreshold;
    if (shouldShow != _showCategoryFilterInBar) {
      setState(() => _showCategoryFilterInBar = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    // Quando usado como tab, não mostra AppBar - retorna apenas o conteúdo
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildMerchantHeader(widget.store)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            minHeight: 80,
            maxHeight: 80,
            child: _buildStickyFilterBar(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: FeaturedProductList(
            products: widget.products,
            categories: widget.categories,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        for (final category in widget.categories)
          ..._buildCategoryGridSection(context, category),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// ✅ Constrói as seções de grid de produtos por categoria
  List<Widget> _buildCategoryGridSection(
    BuildContext context,
    Category category,
  ) {
    // ✅ Filtra produtos da categoria considerando múltiplas formas de associação
    var categoryProducts =
        _filteredProducts.where((product) {
          // 1. Verifica se tem categoryLinks apontando para esta categoria
          final hasCategoryLinks = product.categoryLinks.any(
            (link) => link.categoryId == category.id,
          );

          // 2. Verifica se primaryCategoryId aponta para esta categoria
          final hasPrimaryCategory = product.primaryCategoryId == category.id;

          // 3. Verifica se a categoria tem productLinks que apontam para este produto
          final hasProductLink = category.productLinks.any(
            (link) => link.productId == product.id,
          );

          return hasCategoryLinks || hasPrimaryCategory || hasProductLink;
        }).toList();

    // ✅ Se não encontrou produtos na lista filtrada, mas a categoria tem productLinks,
    // busca os produtos correspondentes na lista completa
    if (categoryProducts.isEmpty && category.productLinks.isNotEmpty) {
      categoryProducts =
          widget.products.where((product) {
            return category.productLinks.any(
              (link) => link.productId == product.id,
            );
          }).toList();
    }

    if (categoryProducts.isEmpty) return [];

    // ✅ Ordena os produtos de acordo com o displayOrder da categoria
    categoryProducts.sort((a, b) {
      final linkA = category.productLinks.firstWhereOrNull((l) => l.productId == a.id);
      final linkB = category.productLinks.firstWhereOrNull((l) => l.productId == b.id);
      final orderA = linkA?.displayOrder ?? 9999;
      final orderB = linkB?.displayOrder ?? 9999;
      return orderA.compareTo(orderB);
    });

    // Lógica para categorias customizáveis (Pizzas)
    if (category.isCustomizable) {
      final sizeGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.size,
      );

      // ✅ Se houver OptionGroup de tamanhos, usa ele
      if (sizeGroup != null && sizeGroup.items.isNotEmpty) {
        final activeSizes = sizeGroup.items.where((s) => s.isActive).toList();

        if (activeSizes.isEmpty) return [];

        // Calcula o preço mínimo para cada tamanho
        final Map<int, int> minPrices = {};
        for (var size in activeSizes) {
          int minP = 99999999; // Valor alto inicial
          bool found = false;

          for (var product in categoryProducts) {
            final priceObj = product.prices.firstWhereOrNull(
              (p) => p.sizeOptionId == size.id,
            );
            if (priceObj != null) {
              // Ignore isAvailable for "Starting from" display to avoid showing 0.00
              // if (priceObj.isAvailable) {
              if (priceObj.price > 0 && priceObj.price < minP) {
                minP = priceObj.price;
                found = true;
              }
              // }
            }
          }

          // Fallback: Se não encontrou preço nos sabores (ou é 0), usa o preço do tamanho
          if (!found || (found && minP == 0)) {
            if (size.price > 0) {
              minP = size.price;
              found = true;
            }
          }

          minPrices[size.id!] = found ? minP : 0;
        }

        return [
          SliverToBoxAdapter(
            key: _categoryKeys[category.id],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
              child: Text(
                category.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            sliver: SizeGridList(
              sizes: activeSizes,
              minPrices: minPrices,
              onSizeTap: (size) {
                // Usa o dialog de produtos GENERAL ao invés do específico de pizza
                // Passa o primeiro produto (sabor) como referência
                if (categoryProducts.isNotEmpty) {
                  NavigationHelper.showProductDialog(
                    context: context,
                    product: categoryProducts.first,
                    category: category,
                    sizeId: size.id, // ✅ Passa o ID do tamanho selecionado
                  );
                }
              },
            ),
          ),
        ];
      } else {
        // ✅ FORMATO ANTIGO: Se não houver OptionGroup de tamanhos, exibe os produtos como tamanhos
        return [
          SliverToBoxAdapter(
            key: _categoryKeys[category.id],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
              child: Text(
                category.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            sliver: ProductGridList(
              products: categoryProducts,
              category: category,
              onProductTap:
                  (product) => NavigationHelper.showProductDialog(
                    context: context,
                    product: product,
                    category: category,
                  ),
            ),
          ),
        ];
      }
    }

    // Lógica padrão para produtos normais
    return [
      SliverToBoxAdapter(
        key: _categoryKeys[category.id],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
          child: Text(
            category.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        sliver: ProductGridList(
          products: categoryProducts,
          category: category,
          onProductTap:
              (product) => NavigationHelper.showProductDialog(
                context: context,
                product: product,
                category: category,
              ),
        ),
      ),
    ];
  }

  /// ✅ Constrói o header do merchant (loja)
  Widget _buildMerchantHeader(Store? store) {
    if (store == null) {
      return const SizedBox(height: 300);
    }

    // ✅ FIX: Usa StoreStatusService completo ao invés de só checar horários
    final storeStatus = StoreStatusService.validateStoreStatus(store);
    final isStoreOpen = storeStatus.canReceiveOrders;
    
    // Mensagem contextual
    String nextOpeningMessage;
    if (!isStoreOpen) {
      switch (storeStatus.reason) {
        case 'admin_offline':
          nextOpeningMessage = 'Aguardando o estabelecimento ficar online';
          break;
        case 'outside_hours':
          nextOpeningMessage = StoreStatusHelper(hours: store.hours ?? []).statusMessage;
          break;
        case 'store_closed':
        case 'scheduled_quick_pause':
        case 'scheduled_pause':
          nextOpeningMessage = storeStatus.message ?? 'Fechada temporariamente';
          break;
        default:
          nextOpeningMessage = storeStatus.message ?? 'Fechada';
      }
    } else {
      nextOpeningMessage = '';
    }
    final storeName = store.name;
    final rating = store.ratingsSummary?.averageRating ?? 0.0;
    final minOrder = store.getMinOrderForDelivery() ?? 0;
    final bannerUrl =
        store.banner?.url ??
        'https://placehold.co/1200x220/e0e0e0/a0a0a0?text=Banner';
    final logoUrl =
        store.image?.url ?? 'https://placehold.co/128/e0e0e0/a0a0a0?text=Logo';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 60),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    bannerUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          height: 220,
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 50,
                          ),
                        ),
                  ),
                ),
                if (!isStoreOpen)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'LOJA FECHADA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nextOpeningMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(logoUrl),
                    backgroundColor: Colors.grey.shade200,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 18,
                              ),
                              Text(
                                rating.toStringAsFixed(1),
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (store != null) {
                        StoreDetailsSidePanel.show(context, store);
                      }
                    },
                    child: const Text('Ver mais'),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monetization_on_outlined,
                        color: Colors.grey.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pedido mínimo R\$ ${minOrder.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder:
              (Widget child, Animation<double> animation) =>
                  FadeTransition(opacity: animation, child: child),
          child:
              !_showCategoryFilterInBar
                  ? Row(
                    key: const ValueKey('search_only'),
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar no cardápio...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey.shade200,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // ✅ Widget de entrega (tempo + taxa)
                      const DeliveryInfoWidget(),
                    ],
                  )
                  : Row(
                    key: const ValueKey('search_and_categories'),
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Category>(
                              value: widget.selectedCategory,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down),
                              items:
                                  widget.categories
                                      .where((cat) {
                                        // Categorias customizáveis (pizzas) sempre aparecem
                                        if (cat.isCustomizable) {
                                          return true;
                                        }

                                        // Verifica se há produtos com categoryLinks apontando para esta categoria
                                        final hasProductsWithLinks =
                                            _filteredProducts.any(
                                              (p) => p.categoryLinks.any(
                                                (link) =>
                                                    link.categoryId == cat.id,
                                              ),
                                            );

                                        // Verifica se a categoria tem productLinks que correspondem a produtos existentes
                                        final hasCategoryLinks =
                                            cat.productLinks.isNotEmpty &&
                                            cat.productLinks.any(
                                              (link) => _filteredProducts.any(
                                                (p) => p.id == link.productId,
                                              ),
                                            );

                                        return hasProductsWithLinks ||
                                            hasCategoryLinks;
                                      })
                                      .map((Category category) {
                                        return DropdownMenuItem<Category>(
                                          value: category,
                                          child: Text(
                                            category.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      })
                                      .toList(),
                              onChanged: (Category? newCategory) {
                                if (newCategory != null) {
                                  widget.onCategorySelected(newCategory);
                                  _scrollToCategory(newCategory.id!);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar no cardápio...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey.shade200,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ✅ Widget de entrega (tempo + taxa)
                      const DeliveryInfoWidget(),
                    ],
                  ),
        ),
      ),
    );
  }

  // ✅ NOVO: Registra visita ao cardápio via Socket.IO
  void _recordMenuVisit() {
    // Registra visita via RealtimeRepository
    Future.microtask(() async {
      if (!mounted) return;

      try {
        // Obtém referrer da URL se disponível
        String? referrer;
        final route = ModalRoute.of(context);
        if (route?.settings.arguments is Map) {
          final args = route!.settings.arguments as Map;
          referrer = args['referrer'] as String?;
        }

        final realtimeRepo = context.read<RealtimeRepository>();
        await realtimeRepo.recordMenuVisit(
          customSource: 'direct', // Pode ser sobrescrito por UTM parameters
          referrer: referrer,
        );
      } catch (e) {
        // Silenciosamente ignora erros para não quebrar o carregamento do menu
        debugPrint('⚠️ [MenuVisit] Erro ao registrar visita: $e');
      }
    });
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  const _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) =>
      maxHeight != oldDelegate.maxHeight ||
      minHeight != oldDelegate.minHeight ||
      child != oldDelegate.child;
}

extension on List<Category> {
  Category? lastWhereOrNull(bool Function(Category) test) {
    final list = where(test).toList();
    return list.isEmpty ? null : list.last;
  }
}
