import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/models/cart_variant.dart';
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/pages/product/widgets/variant_header_widget.dart';
import 'package:totem/pages/product/widgets/variant_widget.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/widgets/dot_loading.dart';

class MobileProductPage extends StatefulWidget {
  final CartProduct product;
  final DsTheme theme;
  final TextEditingController observationController;

  const MobileProductPage({
    super.key,
    required this.product,
    required this.theme,
    required this.observationController,
  });

  @override
  State<MobileProductPage> createState() => _MobileProductPageState();
}

class _MobileProductPageState extends State<MobileProductPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _variantKeys = {};
  final Map<int, double> _variantOffsets = {};
  CartVariant? _currentStickyVariant;
  bool _showTitleInAppBar = false;

  @override
  void initState() {
    super.initState();
    // ✅ FIX: The Cubit is initialized outside, so we just need to listen to it.
    // The initial product state is already in the Cubit.

    // Initialize GlobalKeys for each variant to calculate scroll offsets
    final cartVariants = widget.product.cartVariants;
    for (final variant in cartVariants) {
      _variantKeys[variant.id] = GlobalKey();
    }

    // Add scroll listener
    _scrollController.addListener(_onScroll);

    // Calculate initial offsets after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOffsets());
  }

  void _calculateOffsets() {
    if (!mounted) return;
    _variantOffsets.clear();

    final scrollRenderBox = context.findRenderObject() as RenderBox?;
    if (scrollRenderBox == null) return;
    final scrollOrigin = scrollRenderBox.localToGlobal(Offset.zero);

    for (final entry in _variantKeys.entries) {
      final key = entry.value;
      if (key.currentContext != null) {
        final renderBox = key.currentContext!.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final offset = position.dy - scrollOrigin.dy + _scrollController.offset;
        _variantOffsets[entry.key] = offset;
      }
    }
  }

  void _onScroll() {
    final media = MediaQuery.of(context).size;
    final currentOffset = _scrollController.offset;

    // Toggle AppBar title visibility
    final shouldShowAppBar = currentOffset > media.height * 0.3;
    if (shouldShowAppBar != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = shouldShowAppBar);
    }

    // Determine which variant header should be sticky
    // ✅ FIX: Use the product from the Cubit's state for this logic
    final product = context.read<ProductPageCubit>().state.product;
    if (product == null) return;

    final selectionPoint = currentOffset + kToolbarHeight;
    CartVariant? newStickyVariant;

    for (final variant in product.cartVariants) {
      final offset = _variantOffsets[variant.id];
      if (offset != null && selectionPoint >= offset) {
        newStickyVariant = variant;
      }
    }

    if (newStickyVariant?.id != _currentStickyVariant?.id) {
      setState(() => _currentStickyVariant = newStickyVariant);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final imageHeight = media.width * 0.8;
    final contentOverlapPosition = imageHeight - 30;

    // ✅ FIX: Use BlocBuilder to listen to state changes from the Cubit
    return BlocBuilder<ProductPageCubit, ProductPageState>(
      builder: (context, state) {

        // if (state.status == ProductPageStatus.loading) {
        //   return const Scaffold(body: Center(child: DotLoading()));
        // }

        if (state.product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Produto não encontrado")),
            body: const Center(child: Text("Ocorreu um erro ao carregar o produto.")),
          );
        }

        final product = state.product!;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _showTitleInAppBar
              ? AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            shadowColor: Colors.grey.shade200,
            title: Text(
              product.sourceProduct.name,
              style: widget.theme.bodyTextStyle
                  .colored(widget.theme.productTextColor)
                  .weighted(FontWeight.bold),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: widget.theme.primaryColor),
              onPressed: () => context.go('/'),
            ),
          )
              : null,
          body: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Stack(
                  children: [
                    SizedBox(
                      height: imageHeight,
                      width: media.width,
                      child: CachedNetworkImage(
                        imageUrl: product.sourceProduct.coverImageUrl ?? '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey.shade200),
                        errorWidget: (context, url, error) => const Icon(Icons.image_not_supported),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: contentOverlapPosition),
                      child: Container(
                        width: media.width,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        padding: const EdgeInsets.fromLTRB(0, 24, 0, 150), // Increased bottom padding
                        child: _buildContentColumn(product),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_showTitleInAppBar)
                Positioned(
                  top: topPadding + 16,
                  left: 16,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.4),
                    child: IconButton(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.close, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              // Sticky Header for Variants
              if (_showTitleInAppBar && _currentStickyVariant != null)
                Positioned(
                  top: kToolbarHeight,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.white, // Ensure it has a background
                    child:

        // ✅ MUDANÇA PRINCIPAL: Use VariantHeaderWidget aqui!
        VariantHeaderWidget(
        key: ValueKey(_currentStickyVariant!.id),
        variant: _currentStickyVariant!,
        ),
        ),
                )



            ],
          ),
        );
      },
    );
  }

  Widget _buildContentColumn(CartProduct product) {
    // Recalculate offsets every time the content rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOffsets());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            product.sourceProduct.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: widget.theme.displayMediumTextStyle
                .colored(widget.theme.productTextColor)
                .weighted(FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        if (product.sourceProduct.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              product.sourceProduct.description,
              style: widget.theme.bodyTextStyle.colored(Colors.grey.shade600),
            ),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            product.price.toCurrency,
            style: widget.theme.displayLargeTextStyle
                .colored(widget.theme.productTextColor)
                .weighted(FontWeight.bold),
          ),
        ),
        const SizedBox(height: 26),
        if (product.cartVariants.isNotEmpty)
          ListView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: product.cartVariants.length,
            itemBuilder: (_, i) {
              final variant = product.cartVariants[i];
              return VariantWidget(
                key: _variantKeys[variant.id], // Use key from the map
                onOptionUpdated: (v, o, nq) {
                  context.read<ProductPageCubit>().updateOption(v, o, nq);
                },
                variant: variant,
              );
            },
          ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Alguma observação?',
            style: widget.theme.bodyTextStyle.weighted(FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: widget.observationController,
            keyboardType: TextInputType.multiline,
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Ex: tirar a cebola, maionese à parte etc.',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: widget.theme.primaryColor),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }
}