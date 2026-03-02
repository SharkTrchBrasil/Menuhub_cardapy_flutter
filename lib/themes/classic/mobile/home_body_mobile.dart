import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/banners.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/services/store_status_service.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import '../../../helpers/navigation_helper.dart';
import '../widgets/featured_product.dart';
import '../widgets/product_item.dart';
import '../../../cubit/auth_cubit.dart';
import 'package:totem/themes/classic/widgets/order_again_list_widget.dart';
import '../../../widgets/unified_cart_bottom_bar.dart';
import '../../../core/extensions.dart';
import '../../../repositories/realtime_repository.dart';
import '../../../widgets/premium_store_header.dart';

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
              final q = query.toLowerCase();
              final nameMatch = product.name.toLowerCase().contains(q);
              final descMatch =
                  product.description?.toLowerCase().contains(q) ?? false;
              return nameMatch || descMatch;
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
    if (_isManualScrolling) return;

    final currentScrollOffset = _scrollController.offset;
    Category? newSelectedCategory;
    final selectionPoint = currentScrollOffset + 120;

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

    if (newSelectedCategory != null &&
        widget.selectedCategory?.id != newSelectedCategory.id) {
      widget.onCategorySelected(newSelectedCategory);

      final index = categoriesWithProducts.indexWhere(
        (c) => c.id == newSelectedCategory?.id,
      );
      if (index != -1) {
        _scrollToHorizontalCategory(index);
      }
    }

    // Calcula offset da primeira categoria
    double firstCatOffset = 9999.0;
    for (final cat in categoriesWithProducts) {
      if (cat.id != null && _categoryOffsets.containsKey(cat.id)) {
        final off = _categoryOffsets[cat.id]!;
        if (off < firstCatOffset) firstCatOffset = off;
      }
    }

    final shouldShowSticky = currentScrollOffset > (firstCatOffset - 100);
    if (shouldShowSticky != _showStickySearch) {
      setState(() {
        _showStickySearch = shouldShowSticky;
      });
    }
  }

  /// ✅ Lista de categorias úteis para exibição
  List<Category> get categoriesWithProducts =>
      widget.categories.where((category) {
        if (category.isCustomizable) return true;
        final hasProductsWithLinks = _filteredProducts.any(
          (p) => p.categoryLinks.any((link) => link.categoryId == category.id),
        );
        final hasCategoryLinks =
            category.productLinks.isNotEmpty &&
            category.productLinks.any(
              (link) => _filteredProducts.any((p) => p.id == link.productId),
            );
        return hasProductsWithLinks || hasCategoryLinks;
      }).toList();

  /// ✅ Abre o Bottom Sheet com todas as categorias
  void _showCategoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cardápio completo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: categoriesWithProducts.length,
                    itemBuilder: (context, index) {
                      final category = categoriesWithProducts[index];
                      // Conta produtos na categoria
                      final count =
                          _filteredProducts.where((p) {
                            return p.categoryLinks.any(
                                  (l) => l.categoryId == category.id,
                                ) ||
                                p.primaryCategoryId == category.id ||
                                category.productLinks.any(
                                  (l) => l.productId == p.id,
                                );
                          }).length;

                      return ListTile(
                        title: Text(
                          category.name,
                          style: TextStyle(
                            fontWeight:
                                widget.selectedCategory?.id == category.id
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                            color:
                                widget.selectedCategory?.id == category.id
                                    ? Colors.black
                                    : Colors.grey.shade700,
                          ),
                        ),
                        trailing: Text(
                          count.toString(),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onCategorySelected(category);
                          _scrollToCategory(category.id!);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
              const SliverToBoxAdapter(child: PremiumStoreHeader()),

              // const SliverToBoxAdapter(child: SizedBox(height: 80)), // Removed as per request to reduce whitespace
              const SliverToBoxAdapter(
                child: OrderAgainListWidget(),
              ), // ✅ Peça Novamente

              SliverToBoxAdapter(
                child: FeaturedProductGrid(
                  products: _filteredProducts,
                  categories: widget.categories,
                ),
              ),
              // Sticky Header movido para o Stack overlay
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

                  // ✅ Removemos o fallback que ignorava a busca
                  // Se productsInCategory está vazio, a categoria não deve exibir nada extras.

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
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Text(
                                category.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F1F1F),
                                ),
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
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Text(
                                category.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F1F1F),
                                ),
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
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            category.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F1F1F),
                            ),
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
          // ✅ Floating Sticky Header (Search + Categories)
          if (_showStickySearch)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: BlocBuilder<StoreCubit, StoreState>(
                builder: (context, storeState) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: TextField(
                              controller: _stickySearchController,
                              readOnly: true,
                              onTap: () => context.push('/search'),
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar em ${storeState.store?.name ?? ''}',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ),
                          _buildHorizontalCategories(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // ✅ Cart bottom bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BlocBuilder<StoreCubit, StoreState>(
              builder: (context, storeState) {
                final canOrder =
                    StoreStatusService.validateStoreStatus(
                      storeState.store,
                    ).canReceiveOrders;

                if (!canOrder) return const SizedBox.shrink();

                return BlocBuilder<AuthCubit, AuthState>(
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
                );
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
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, size: 20),
            onPressed: _showCategoryBottomSheet,
          ),
          Expanded(
            child: ListView.builder(
              controller: _categoryScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color:
                                isSelected
                                    ? Colors.black
                                    : Colors.grey.shade600,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            height: 2,
                            width: 20,
                            color: Colors.black,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
      ),
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
