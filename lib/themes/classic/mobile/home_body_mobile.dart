import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/banners.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/themes/classic/widgets/store_card.dart';
import '../../../helpers/navigation_helper.dart';
import '../widgets/featured_product.dart';
import '../widgets/product_item.dart';
import '../../../cubit/auth_cubit.dart';
import '../../../pages/cart/cart_cubit.dart';
import '../../../pages/cart/cart_state.dart';
import '../../../core/extensions.dart';
import '../../../themes/ds_theme_switcher.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _stickySearchController = TextEditingController();
  final Map<int, GlobalKey> _categoryKeys = {};
  final Map<int, double> _categoryOffsets = {};
  List<Product> _filteredProducts = [];
  bool _showStickySearch = false;

  @override
  void initState() {
    super.initState();
    _initializeKeys();
    _initializeFilteredProducts();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _stickySearchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateCategoryOffsets());
  }

  @override
  void didUpdateWidget(HomeBodyMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories || widget.products != oldWidget.products) {
      _initializeKeys();
      _initializeFilteredProducts();
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateCategoryOffsets());
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.removeListener(_onSearchChanged);
    _stickySearchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _stickySearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeFilteredProducts() {
    _filteredProducts = widget.products;
  }

  void _onSearchChanged() {
    final query = _searchController.text.isNotEmpty ? _searchController.text : _stickySearchController.text;
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.products;
      } else {
        _filteredProducts = widget.products.where((product) {
          return product.name.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateCategoryOffsets());
    });
  }

  void _initializeKeys() {
    _categoryKeys.clear();
    for (var category in widget.categories) {
      if (category.id != null) {
        _categoryKeys[category.id!] = GlobalKey();
      }
    }
  }

  void _calculateCategoryOffsets() {
    _categoryOffsets.clear();
    for (var entry in _categoryKeys.entries) {
      final key = entry.value;
      if (key.currentContext != null) {
        final renderBox = key.currentContext!.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final offset = position.dy + _scrollController.offset - MediaQuery.of(context).padding.top;
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
        alignment: 0.0,
        curve: Curves.easeInOut,
      );
    }
  }

  void _onScroll() {
    _calculateCategoryOffsets();
    final currentScrollOffset = _scrollController.offset;
    
    // Controla a visibilidade da busca sticky
    setState(() {
      _showStickySearch = currentScrollOffset > 50;
    });
    
    Category? newSelectedCategory;

    final stickyHeaderHeight = _showStickySearch ? 112.0 : 60.0;
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

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 && widget.categories.isNotEmpty) {
      newSelectedCategory = widget.categories.last;
    }

    if (widget.selectedCategory?.id != newSelectedCategory?.id) {
      widget.onCategorySelected(newSelectedCategory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const StoreCardData(),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
              SliverToBoxAdapter(child: FeaturedProductGrid(products: _filteredProducts, categories: widget.categories)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  minHeight: _showStickySearch ? 120 : 60,
                  maxHeight: _showStickySearch ? 120 : 60,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _showStickySearch
                        ? Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: TextField(
                                  controller: _stickySearchController,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar no cardápio...',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.grey.shade200,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _buildHorizontalCategories(),
                              ),
                            ],
                          )
                        : _buildHorizontalCategories(),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = widget.categories[index];
                    final key = _categoryKeys[category.id];

                    final productsInCategory = _filteredProducts
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
                            onTap: () => goToProductPage(context, product),
                            category: category,
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
          // ✅ CORREÇÃO: Card flutuante - mostra login quando não logado, carrinho quando logado
          Positioned(
            bottom: 15,
            left: 16,
            right: 16,
            child: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, authState) {
                if (authState.customer != null) {
                  // ✅ Quando logado, mostra card de carrinho
                  return const _CartFloatingCard();
                }
                // ✅ Quando não logado, mostra card de login
                return const _LoginPromoCard();
              },
            ),
          ),
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
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 2,
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

class _LoginPromoCard extends StatelessWidget {
  const _LoginPromoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explore mais com sua conta MenuHub',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      context.push('/onboarding');
                    },
                    child: Text(
                      'Entrar ou cadastrar-se',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ NOVO: Card flutuante de carrinho (mostra quando logado)
class _CartFloatingCard extends StatelessWidget {
  const _CartFloatingCard();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        final cart = cartState.cart;
        
        // ✅ Não mostra se o carrinho estiver vazio
        if (cart.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final totalInReais = cart.total / 100.0;
        final itemCount = cart.items.length;
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: EdgeInsets.zero,
          color: theme.cartBackgroundColor,
          child: InkWell(
            onTap: () => context.push('/cart'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Ícone do carrinho
                  Icon(
                    Icons.shopping_bag,
                    color: theme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  // Informações do carrinho
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total sem a entrega',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.cartTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              totalInReais.toCurrency(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.onBackgroundColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '/ $itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.cartTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Botão "Ver sacola"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ver sacola',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
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
