import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/banners.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/themes/classic/widgets/store_card.dart';
import '../../../helpers/navigation_helper.dart';
import '../widgets/featured_product.dart';
import '../widgets/product_item.dart';

class HomeBodyMobile extends StatefulWidget {
  final List<BannerModel> banners;
  final List<Category> categories;
  final List<Product> products;
  final Category? selectedCategory;
  final Function(Category?) onCategorySelected;

  const HomeBodyMobile({
    super.key,
    required this.banners,
    required this.categories,
    required this.products,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<HomeBodyMobile> createState() => _HomeBodyMobileState();
}

class _HomeBodyMobileState extends State<HomeBodyMobile> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _categoryKeys = {};
  final Map<int, double> _categoryOffsets = {};

  @override
  void initState() {
    super.initState();
    _initializeKeys();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateCategoryOffsets());
  }

  @override
  void didUpdateWidget(HomeBodyMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories) {
      _initializeKeys();
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateCategoryOffsets());
    }
  }

  void _initializeKeys() {
    _categoryKeys.clear();
    for (var category in widget.categories) {
      if (category.id != null) {
        _categoryKeys[category.id!] = GlobalKey();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _calculateCategoryOffsets() {
    _categoryOffsets.clear();
    for (var entry in _categoryKeys.entries) {
      final key = entry.value;
      if (key.currentContext != null) {
        final renderBox = key.currentContext!.findRenderObject() as RenderBox;
        // Pega a posição do widget em relação ao topo da tela
        final position = renderBox.localToGlobal(Offset.zero);
        // Ajusta pela posição atual do scroll e pela altura da appbar/statusbar
        final offset = position.dy + _scrollController.offset - kToolbarHeight - MediaQuery.of(context).padding.top;
        _categoryOffsets[entry.key] = offset;
      }
    }
  }

  void _scrollToCategory(int categoryId) {
    final key = _categoryKeys[categoryId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.0, // Alinha ao topo
        curve: Curves.easeInOut,
      );
    }
  }

  void _onScroll() {
    _calculateCategoryOffsets(); // Recalcula em cada scroll para precisão
    final currentScrollOffset = _scrollController.offset;
    Category? newSelectedCategory;

    // Altura da barra de categorias + um pequeno buffer
    const stickyHeaderHeight = 70.0;
    final selectionPoint = currentScrollOffset + stickyHeaderHeight;

    for (var category in widget.categories) {
      final categoryId = category.id;
      if (categoryId != null && _categoryOffsets.containsKey(categoryId)) {
        final categoryOffset = _categoryOffsets[categoryId]!;
        if (selectionPoint >= categoryOffset) {
          newSelectedCategory = category;
        }
      }
    }

    // Lógica para o final do scroll
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      newSelectedCategory = widget.categories.last;
    }

    // Dispara o callback apenas se a categoria mudou
    if (widget.selectedCategory?.id != newSelectedCategory?.id) {
      widget.onCategorySelected(newSelectedCategory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const StoreCardData(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
          SliverToBoxAdapter(child: FeaturedProductGrid(products: widget.products, categories:widget.categories)),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              minHeight: 60,
              maxHeight: 60,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: _buildHorizontalCategories(),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final category = widget.categories[index];
                final key = _categoryKeys[category.id];

                // ✅ CORREÇÃO APLICADA AQUI
                // Filtra os produtos usando a nova estrutura 'categoryLinks'.
                final productsInCategory = widget.products
                    .where((p) => p.categoryLinks.any((link) => link.categoryId == category.id))
                    .toList();

                if (productsInCategory.isEmpty) return const SizedBox.shrink();

                return Container(
                  key: key,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(
                          category.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      ...productsInCategory.map((product) => ProductItem(
                        product: product,
                        onTap: () => goToProductPage(context, product), category: category,
                      )),
                    ],
                  ),
                );
              },
              childCount: widget.categories.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _buildHorizontalCategories() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: widget.categories.length,
      itemBuilder: (context, index) {
        final category = widget.categories[index];
        final isSelected = widget.selectedCategory?.id == category.id;

        return GestureDetector(
          onTap: () {
            widget.onCategorySelected(category);
            _scrollToCategory(category.id!);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 3,
                  width: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => minHeight;
  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) =>
      maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
}