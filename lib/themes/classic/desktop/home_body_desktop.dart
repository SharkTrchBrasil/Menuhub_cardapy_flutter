// Versão profissional com scroll dinâmico, atualização dos offsets e detecção do fim da lista

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/banners.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/themes/classic/desktop/widgets/fetrured_list.dart';
import 'package:totem/themes/classic/desktop/widgets/product_grid_list.dart';
import 'package:totem/themes/classic/widgets/store_card.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/footer.dart';
import '../../../helpers/navigation_helper.dart';
import '../../../helpers/store_hours_helper.dart';
import '../../../models/store.dart';
import '../widgets/featured_product.dart';

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
  }

  @override
  void didUpdateWidget(HomeBodyDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories || widget.products != oldWidget.products) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateCategoryOffsets());
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
        _filteredProducts = widget.products.where((product) {
          return product.name.toLowerCase().contains(query);
        }).toList();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateCategoryOffsets());
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

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      final lastCategoryWithProducts = widget.categories.lastWhereOrNull(
            (cat) => _filteredProducts.any((p) => p.categoryLinks.any((link) => link.categoryId == cat.id)),
      );
      if(lastCategoryWithProducts != null) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store?.name ?? 'Cardápio'),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: () {}),
          const SizedBox(width: 16),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildMerchantHeader(widget.store)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(minHeight: 80, maxHeight: 80, child: _buildStickyFilterBar()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(child: FeaturedProductList(products: widget.products, categories: widget.categories,)),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          for (final category in widget.categories) ..._buildCategoryGridSection(context, category),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
          SliverToBoxAdapter(child: FooterWidget(store: widget.store, theme: theme)),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryGridSection(BuildContext context, Category category) {
    if (category.id == null) return [];
    final key = _categoryKeys[category.id!];

    // ✅ CORREÇÃO APLICADA AQUI
    final productsInCategory = _filteredProducts
        .where((p) => p.categoryLinks.any((link) => link.categoryId == category.id))
        .toList();

    if (productsInCategory.isEmpty) return [];

    return [
      SliverToBoxAdapter(
        key: key,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(71, 24, 71, 8),
          child: Text(
            category.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, mainAxisExtent: 140,
          ),
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final product = productsInCategory[index];
              return ProductItemGrid(
                product: product,
                onTap: () => goToProductPage(context, product), category: category,
              );
            },
            childCount: productsInCategory.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildMerchantHeader(Store? store) {
    if (store == null) return const Center(child: CircularProgressIndicator());
    final statusHelper = StoreStatusHelper(hours: store.hours);
    final isStoreOpen = statusHelper.isOpen;
    final nextOpeningMessage = statusHelper.statusMessage;
    final storeName = store.name;
    final rating = store.ratingsSummary?.averageRating ?? 0.0;
    final minOrder = store.store_operation_config?.deliveryMinOrder ?? 0;
    final bannerUrl = store.banner?.url ?? 'https://placehold.co/1200x220/e0e0e0/a0a0a0?text=Banner';
    final logoUrl = store.image?.url ?? 'https://placehold.co/128/e0e0e0/a0a0a0?text=Logo';

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
                  child: Image.network(bannerUrl, height: 220, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 220, color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
                    ),
                  ),
                ),
                if (!isStoreOpen)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('LOJA FECHADA', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            const SizedBox(height: 8),
                            Text(nextOpeningMessage, style: const TextStyle(color: Colors.white, fontSize: 16)),
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
                  CircleAvatar(radius: 32, backgroundImage: NetworkImage(logoUrl), backgroundColor: Colors.grey.shade200),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              Text(rating.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () {}, child: const Text('Ver mais')),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on_outlined, color: Colors.grey.shade600, size: 18),
                      const SizedBox(width: 4),
                      Text('Pedido mínimo R\$ ${minOrder.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
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
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child),
          child: !_showCategoryFilterInBar
              ? Row(
            key: const ValueKey('search_only'),
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar no cardápio...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const Spacer(),
            ],
          )
              : Row(
            key: const ValueKey('search_and_categories'),
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Category>(
                      value: widget.selectedCategory,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: widget.categories.map((Category category) {
                        return DropdownMenuItem<Category>(
                          value: category,
                          child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
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
                flex: 1,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar no cardápio...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  const _StickyHeaderDelegate({required this.minHeight, required this.maxHeight, required this.child});
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => minHeight;
  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) =>
      maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
}

extension on List<Category> {
  Category? lastWhereOrNull(bool Function(Category) test) {
    final list = where(test).toList();
    return list.isEmpty ? null : list.last;
  }
}