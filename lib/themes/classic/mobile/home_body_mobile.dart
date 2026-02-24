import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/banners.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/themes/classic/widgets/store_card.dart';
import 'package:totem/services/store_status_service.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import '../../../helpers/navigation_helper.dart';
import '../widgets/featured_product.dart';
import '../widgets/product_item.dart';
import '../../../cubit/auth_cubit.dart';
import '../../../pages/cart/cart_cubit.dart';
import '../../../pages/cart/cart_state.dart';
import '../../../core/extensions.dart';
import '../../../themes/ds_theme_switcher.dart';
import 'package:totem/themes/classic/widgets/coupon_list_widget.dart';
import 'package:totem/themes/classic/widgets/order_again_list_widget.dart'; // ✅ Importante
import '../../../widgets/store_closed_widgets.dart';
import '../../../widgets/unified_cart_bottom_bar.dart';
import '../../../repositories/realtime_repository.dart';

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
  final ScrollController _categoryScrollController =
      ScrollController(); // ✅ Novo
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _stickySearchController = TextEditingController();
  final Map<int, GlobalKey> _categoryKeys = {};
  final Map<int, double> _categoryOffsets = {};
  List<Product> _filteredProducts = [];
  bool _showStickySearch = false;
  bool _isManualScrolling = false; // ✅ Proteção contra loop

  @override
  void initState() {
    super.initState();
    _initializeKeys();
    _initializeFilteredProducts();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _stickySearchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _calculateCategoryOffsets(),
    );

    // ✅ NOVO: Registra visita ao cardápio via Socket.IO
    _recordMenuVisit();
  }

  @override
  void didUpdateWidget(HomeBodyMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories ||
        widget.products != oldWidget.products) {
      _initializeKeys();
      _initializeFilteredProducts();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _calculateCategoryOffsets(),
      );
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
    _categoryScrollController.dispose(); // ✅ Novo
    super.dispose();
  }

  void _initializeFilteredProducts() {
    _filteredProducts = widget.products;
  }

  void _onSearchChanged() {
    final query =
        _searchController.text.isNotEmpty
            ? _searchController.text
            : _stickySearchController.text;
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.products;
      } else {
        _filteredProducts =
            widget.products.where((product) {
              return product.name.toLowerCase().contains(query.toLowerCase());
            }).toList();
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _calculateCategoryOffsets(),
      );
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
        final offset =
            position.dy +
            _scrollController.offset -
            MediaQuery.of(context).padding.top;
        _categoryOffsets[entry.key] = offset;
      }
    }
  }

  void _scrollToCategory(int categoryId) async {
    final key = _categoryKeys[categoryId];
    if (key?.currentContext != null) {
      setState(() => _isManualScrolling = true);

      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        alignment: 0.0,
        curve: Curves.easeInOutCubic,
      );

      // ✅ Pequeno delay para o scroll terminar e evitar que o listener mude a categoria
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) setState(() => _isManualScrolling = false);
    }
  }

  void _scrollToHorizontalCategory(int index) {
    if (!_categoryScrollController.hasClients) return;

    // ✅ Centraliza a categoria selecionada na barra horizontal
    _categoryScrollController
        .animateTo(
          index * 100.0 - (MediaQuery.of(context).size.width / 2) + 50.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .catchError((_) {}); // Ignora se não puder scrollar
  }

  void _onScroll() {
    if (_isManualScrolling) return; // ✅ Evita conflito ao clicar na categoria

    // Recalcula se necessário (raro, mas garante precisão)
    if (_categoryOffsets.isEmpty) _calculateCategoryOffsets();

    final currentScrollOffset = _scrollController.offset;

    // Controla a visibilidade da busca sticky com threshold mais suave
    final shouldShowSticky = currentScrollOffset > 300;
    if (shouldShowSticky != _showStickySearch) {
      setState(() {
        _showStickySearch = shouldShowSticky;
      });
    }

    Category? newSelectedCategory;

    // ✅ Offsets mais precisos considerando o cabeçalho fixo
    final stickyHeaderHeight = _showStickySearch ? 120.0 : 60.0;
    final selectionPoint = currentScrollOffset + stickyHeaderHeight + 20;

    for (var i = 0; i < widget.categories.length; i++) {
      final category = widget.categories[i];
      final categoryId = category.id;
      if (categoryId != null && _categoryOffsets.containsKey(categoryId)) {
        final categoryOffset = _categoryOffsets[categoryId]!;
        if (selectionPoint >= categoryOffset) {
          newSelectedCategory = category;
        }
      }
    }

    // Se chegou no fim, seleciona a última
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      newSelectedCategory = widget.categories.last;
    }

    if (newSelectedCategory != null &&
        widget.selectedCategory?.id != newSelectedCategory.id) {
      widget.onCategorySelected(newSelectedCategory);

      // ✅ Sincroniza o scroll horizontal
      final index = widget.categories.indexWhere(
        (c) => c.id == newSelectedCategory?.id,
      );
      if (index != -1) {
        _scrollToHorizontalCategory(index);
      }
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

              // const SliverToBoxAdapter(child: SizedBox(height: 80)), // Removed as per request to reduce whitespace
              const SliverToBoxAdapter(child: CouponListWidget()), // ✅ Cupons
              const SliverToBoxAdapter(
                child: OrderAgainListWidget(),
              ), // ✅ Peça Novamente

              SliverToBoxAdapter(
                child: FeaturedProductGrid(
                  products: _filteredProducts,
                  categories: widget.categories,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  minHeight: _showStickySearch ? 120 : 60,
                  maxHeight: _showStickySearch ? 120 : 60,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child:
                        _showStickySearch
                            ? Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 16,
                                          ),
                                    ),
                                  ),
                                ),
                                Expanded(child: _buildHorizontalCategories()),
                              ],
                            )
                            : _buildHorizontalCategories(),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final category = widget.categories[index];
                  final key = _categoryKeys[category.id];

                  // ✅ Filtra produtos da categoria considerando múltiplas formas de associação
                  var productsInCategory =
                      _filteredProducts.where((p) {
                        // 1. Verifica se tem categoryLinks apontando para esta categoria
                        final hasCategoryLinks = p.categoryLinks.any(
                          (link) => link.categoryId == category.id,
                        );

                        // 2. Verifica se primaryCategoryId aponta para esta categoria
                        final hasPrimaryCategory =
                            p.primaryCategoryId == category.id;

                        // 3. Verifica se a categoria tem productLinks que apontam para este produto
                        final hasProductLink = category.productLinks.any(
                          (link) => link.productId == p.id,
                        );

                        return hasCategoryLinks ||
                            hasPrimaryCategory ||
                            hasProductLink;
                      }).toList();

                  // ✅ Se não encontrou produtos na lista filtrada, mas a categoria tem productLinks,
                  // busca os produtos correspondentes na lista completa
                  if (productsInCategory.isEmpty &&
                      category.productLinks.isNotEmpty) {
                    productsInCategory =
                        widget.products.where((p) {
                          return category.productLinks.any(
                            (link) => link.productId == p.id,
                          );
                        }).toList();
                  }

                  if (productsInCategory.isEmpty)
                    return const SizedBox.shrink();

                  // ✅ Lógica para categorias customizáveis (Pizzas) - mostra tamanhos primeiro
                  if (category.isCustomizable) {
                    final sizeGroup = category.optionGroups.firstWhereOrNull(
                      (g) => g.groupType == OptionGroupType.size,
                    );

                    // ✅ Se houver OptionGroup de tamanhos, usa ele
                    if (sizeGroup != null && sizeGroup.items.isNotEmpty) {
                      final activeSizes =
                          sizeGroup.items.where((s) => s.isActive).toList();

                      if (activeSizes.isEmpty) return const SizedBox.shrink();

                      // Calcula preço mínimo para cada tamanho
                      final Map<int, int> minPrices = {};
                      for (var size in activeSizes) {
                        int minP = 99999999;
                        bool found = false;

                        for (var product in productsInCategory) {
                          final priceObj = product.prices.firstWhereOrNull(
                            (p) => p.sizeOptionId == size.id,
                          );
                          if (priceObj != null &&
                              priceObj.price > 0 &&
                              priceObj.price < minP) {
                            minP = priceObj.price;
                            found = true;
                          }
                        }

                        if (!found || minP == 0) {
                          if (size.price > 0) {
                            minP = size.price;
                            found = true;
                          }
                        }

                        minPrices[size.id!] = found ? minP : 0;
                      }

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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            // ✅ Lista de tamanhos como cards de produto (igual ProductItem)
                            ...activeSizes.map((size) {
                              final minPrice = minPrices[size.id] ?? 0;
                              // Extrai informações do nome
                              final slicesMatch = RegExp(
                                r'(\d+)\s*PEDAÇOS?',
                                caseSensitive: false,
                              ).firstMatch(size.name);
                              final flavorsMatch = RegExp(
                                r'(\d+)\s*SABORES?',
                                caseSensitive: false,
                              ).firstMatch(size.name);
                              final slices =
                                  size.slices ??
                                  (slicesMatch != null
                                      ? int.tryParse(slicesMatch.group(1)!)
                                      : null);
                              final maxFlavors =
                                  size.maxFlavors ??
                                  (flavorsMatch != null
                                      ? int.tryParse(flavorsMatch.group(1)!)
                                      : null);

                              // Monta descrição
                              final description = [
                                if (slices != null) '$slices Pedaços',
                                if (maxFlavors != null && maxFlavors > 1)
                                  '$maxFlavors Sabores',
                              ].join(' • ');

                              return GestureDetector(
                                onTap: () {
                                  if (productsInCategory.isNotEmpty) {
                                    NavigationHelper.showProductDialog(
                                      context: context,
                                      product: productsInCategory.first,
                                      category: category,
                                      sizeId: size.id,
                                    );
                                  }
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 12.0,
                                  ),
                                  child: Row(
                                    children: [
                                      // Informações do tamanho (igual ProductItem - texto à esquerda)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              size.name.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (description.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                description,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Text(
                                              'A partir de ${minPrice.toCurrency}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Imagem à direita (igual ProductItem)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                        child: SizedBox(
                                          width: 80,
                                          height: 80,
                                          child:
                                              (size.image?.url != null ||
                                                      category.image?.url !=
                                                          null)
                                                  ? Image.network(
                                                    size.image?.url ??
                                                        category.image!.url,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => Container(
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade100,
                                                          child: Icon(
                                                            Icons.local_pizza,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade400,
                                                            size: 32,
                                                          ),
                                                        ),
                                                  )
                                                  : Container(
                                                    color: Colors.grey.shade100,
                                                    child: Icon(
                                                      Icons.local_pizza,
                                                      color:
                                                          Colors.grey.shade400,
                                                      size: 32,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    } else {
                      // ✅ FORMATO ANTIGO: Se não houver OptionGroup de tamanhos, exibe os produtos como tamanhos
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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            // ✅ Exibe cada produto como um tamanho
                            ...productsInCategory.map((product) {
                              final minPrice =
                                  product.price ??
                                  product.categoryLinks
                                      .firstWhereOrNull(
                                        (link) =>
                                            link.categoryId == category.id,
                                      )
                                      ?.price ??
                                  0;

                              return ProductItem(
                                product: product,
                                category: category,
                                onTap: () {
                                  NavigationHelper.showProductDialog(
                                    context: context,
                                    product: product,
                                    category: category,
                                  );
                                },
                              );
                            }),
                          ],
                        ),
                      );
                    }
                  }

                  // ✅ Lógica padrão para produtos normais
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        ...productsInCategory.map(
                          (product) => ProductItem(
                            product: product,
                            onTap: () => goToProductPage(context, product),
                            category: category,
                          ),
                        ),
                      ],
                    ),
                  );
                }, childCount: widget.categories.length),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
          // ✅ Cart bottom bar - colado nas tabs, sem padding lateral
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, authState) {
                if (authState.customer != null) {
                  // ✅ Quando logado, mostra card de carrinho unificado
                  return const UnifiedCartBottomBar(
                    variant: CartBottomBarVariant.home,
                  );
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
    // ✅ Filtra categorias que têm produtos OU são customizáveis (pizzas)
    // Categorias customizáveis aparecem mesmo sem produtos (como no Menuhub)
    final categoriesWithProducts =
        widget.categories.where((category) {
          // Categorias customizáveis (pizzas) sempre aparecem
          if (category.isCustomizable) {
            return true;
          }

          // Verifica se há produtos com categoryLinks apontando para esta categoria
          final hasProductsWithLinks = _filteredProducts.any(
            (p) =>
                p.categoryLinks.any((link) => link.categoryId == category.id),
          );

          // Verifica se a categoria tem productLinks que correspondem a produtos existentes
          final hasCategoryLinks =
              category.productLinks.isNotEmpty &&
              category.productLinks.any(
                (link) => _filteredProducts.any((p) => p.id == link.productId),
              );

          return hasProductsWithLinks || hasCategoryLinks;
        }).toList();

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          if (_showStickySearch)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ListView.builder(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: categoriesWithProducts.length,
        itemBuilder: (context, index) {
          final category = categoriesWithProducts[index];
          final isSelected = widget.selectedCategory?.id == category.id;

          return GestureDetector(
            onTap: () {
              widget.onCategorySelected(category);
              _scrollToCategory(category.id!);
              _scrollToHorizontalCategory(index);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minWidth: 80),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade600,
                      fontFamily: 'Inter',
                    ),
                    child: Text(category.name),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    width: isSelected ? 30 : 0,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ MOVIDO: Registra visita ao cardápio via Socket.IO
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
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
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
  ) {
    return SizedBox.expand(child: child);
  }

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
