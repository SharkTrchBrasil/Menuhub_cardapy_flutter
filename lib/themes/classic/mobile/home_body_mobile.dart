// Versão profissional com scroll dinâmico, atualização dos offsets e detecção do fim da lista

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/models/banners.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/themes/classic/widgets/store_card.dart';
import 'package:totem/themes/ds_theme.dart';
import '../../../helpers/dimensions.dart';
import '../../../helpers/navigation_helper.dart';
import '../widgets/featured_product.dart';
import '../widgets/product_item.dart';

class HomeBodyMobile extends StatefulWidget {
  final List<BannerModel> banners;
  final List<Category> categories;
  final List<Product> products;
  final Category? selectedCategory;
  final DsCategoryLayout categoryLayout;
  final DsProductLayout productLayout;
  final Function(Category) onCategorySelected;

  const HomeBodyMobile({
    super.key,
    required this.banners,
    required this.categories,
    required this.products,
    required this.selectedCategory,
    required this.categoryLayout,
    required this.productLayout,
    required this.onCategorySelected,
  });

  @override
  State<HomeBodyMobile> createState() => _HomeBodyMobileState();
}

class _HomeBodyMobileState extends State<HomeBodyMobile> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _categoryKeys = {};
  Category? _localSelectedCategory;
  final Map<int, double> _categoryOffsets = {};

  @override
  void initState() {
    super.initState();
    _localSelectedCategory = widget.selectedCategory;
    for (var category in widget.categories) {
      _categoryKeys[category.id!] = GlobalKey();
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateCategoryOffsets());
  }

  @override
  void didUpdateWidget(HomeBodyMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      setState(() => _localSelectedCategory = widget.selectedCategory);
    }
    if (widget.categories != oldWidget.categories || widget.products != oldWidget.products) {
      _categoryKeys.clear();
      for (var category in widget.categories) {
        _categoryKeys[category.id!] = GlobalKey();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateCategoryOffsets());
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
    for (var category in widget.categories) {
      final key = _categoryKeys[category.id];
      if (key?.currentContext != null) {
        final renderBox = key!.currentContext!.findRenderObject() as RenderBox;
        final offset = renderBox.localToGlobal(Offset.zero).dy +
            _scrollController.offset -
            MediaQuery.of(context).padding.top;
        _categoryOffsets[category.id!] = offset;
      }
    }
  }

  void _scrollToCategory(int categoryId) {
    final key = _categoryKeys[categoryId];
    final context = key?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        alignment: 0.0,
        curve: Curves.easeInOut,
      ).then((_) {
        final category = widget.categories.firstWhere((cat) => cat.id == categoryId);
        if (_localSelectedCategory?.id != category.id) {
          setState(() => _localSelectedCategory = category);
        }
      });
    }
  }

  void _onScroll() {
    _calculateCategoryOffsets();

    final currentScrollOffset = _scrollController.offset;
    Category? newSelectedCategory;
    double minDistance = double.infinity;

    for (var category in widget.categories) {
      final categoryId = category.id!;
      if (_categoryOffsets.containsKey(categoryId)) {
        final categoryOffset = _categoryOffsets[categoryId]!;
        const stickyHeaderHeight = 100.0;
        final adjustedOffset = currentScrollOffset + stickyHeaderHeight;

        if (adjustedOffset >= categoryOffset) {
          final distance = (adjustedOffset - categoryOffset).abs();
          if (distance < minDistance) {
            minDistance = distance;
            newSelectedCategory = category;
          }
        }
      }
    }

    // Detecta se chegou ao final da lista
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      newSelectedCategory = widget.categories.last;
    }

    if (newSelectedCategory != null &&
        _localSelectedCategory?.id != newSelectedCategory.id) {
      setState(() => _localSelectedCategory = newSelectedCategory);
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
          SliverToBoxAdapter(child: FeaturedProductGrid(products: widget.products)),
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
                final productsInCategory = widget.products
                    .where((p) => p.category.id == category.id)
                    .toList();

                if (productsInCategory.isEmpty) return const SizedBox();

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
                        onTap: () => goToProductPage(context, product),
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
        final isSelected = _localSelectedCategory?.id == category.id;

        return GestureDetector(
          onTap: () {
            setState(() => _localSelectedCategory = category);
            widget.onCategorySelected(category);
            _scrollToCategory(category.id!);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name ?? 'Sem nome',
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
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
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
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
