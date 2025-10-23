import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/pages/product/widgets/variant_widget.dart';
import 'package:totem/widgets/ds_primary_button.dart';

import '../../../cubit/auth_cubit.dart';
import '../../../models/cart.dart';
import '../../../models/cart_variant.dart';
import '../../../models/cart_variant_option.dart';
import '../../../models/update_cart_payload.dart';
import '../../../widgets/dot_loading.dart';
import '../../cart/cart_state.dart';
import 'dart:math';

class DesktopProductCard extends StatefulWidget {
  final CartProduct product;
  final TextEditingController observationController;

  const DesktopProductCard({
    super.key,
    required this.product,
    required this.observationController,
  });

  @override
  State<DesktopProductCard> createState() => _DesktopProductCardState();
}

class _DesktopProductCardState extends State<DesktopProductCard> {

  late CartProduct configuredProduct;


  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _variantKeys = {};
  final Map<int, double> _variantOffsets = {};
  CartVariant? _currentStickyVariant;
  final GlobalKey _scrollAreaKey = GlobalKey();

  @override
  void initState() {
  super.initState();

  configuredProduct = widget.product;

  final cartVariants = widget.product.cartVariants;
  for (final variant in cartVariants) {
  _variantKeys[variant.id] = GlobalKey();
  }

  _scrollController.addListener(_onScroll);
  WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOffsets());
  }

  @override
  void dispose() {
  _scrollController.removeListener(_onScroll);
  _scrollController.dispose();
  super.dispose();
  }

  void _calculateOffsets() {
    _variantOffsets.clear();
    // Busca o RenderBox da própria área de rolagem usando a nova chave.
    final scrollRenderBox = _scrollAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollRenderBox == null) return;

    for (final entry in _variantKeys.entries) {
      final key = entry.value;
      if (key.currentContext != null) {
        final variantRenderBox = key.currentContext!.findRenderObject() as RenderBox;

        // ESTA É A MÁGICA:
        // 1. Pega a posição global (na tela) do título da variante.
        // 2. Converte essa posição global para uma posição local DENTRO da área de rolagem.
        // O resultado é a posição Y exata do título em relação ao topo do conteúdo rolável.
        final offset = scrollRenderBox.globalToLocal(
            variantRenderBox.localToGlobal(Offset.zero)
        );

        _variantOffsets[entry.key] = offset.dy;
      }
    }
    // Para depuração, você pode ver os offsets precisos no console:
    // print("Offsets Corrigidos: $_variantOffsets");
  }


  void _onScroll() {
  CartVariant? newStickyVariant;
  final currentOffset = _scrollController.offset;

  // Acha a última variante cujo topo já passou do início da área de scroll
  for (final variant in widget.product.cartVariants) {
  final variantOffset = _variantOffsets[variant.id];
  if (variantOffset != null && currentOffset >= variantOffset - 1) { // -1 para garantir a detecção
  newStickyVariant = variant;
  }
  }

  if (newStickyVariant?.id != _currentStickyVariant?.id) {
  setState(() {
  _currentStickyVariant = newStickyVariant;
  });
  }
  }


  @override
  Widget build(BuildContext context) {

    // ✅ 4. REMOVEMOS O BLOCBUILDER DAQUI
    final theme = context.watch<DsThemeSwitcher>().theme;

    // Acessamos o produto diretamente do widget. É garantido que não é nulo.
    final currentProduct = widget.product;
    final cartVariants = currentProduct.cartVariants;
    final screenSize = MediaQuery.of(context).size;

    return ConstrainedBox(
      // Aqui definimos as "regras" de tamanho
      constraints: BoxConstraints(
        // LARGURA: Tente ter 90% da tela, mas NUNCA passe de 600px.
        maxWidth: min(screenSize.width * 0.90, 800),

        // ALTURA: Tente ter 90% da tela, mas NUNCA passe de 750px.
        maxHeight: min(screenSize.height * 0.90, 600),

        // Você também pode definir limites mínimos se precisar:
        // minWidth: 400,
        // minHeight: 500,
      ),
      child: Material(
        color: Colors.white,
        child: Row(
          children: [
            // COLUNA 1: IMAGEM
            Expanded(
              flex: 5,
              child: CachedNetworkImage(
                imageUrl: currentProduct.sourceProduct.coverImageUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                const Icon(
                    Icons.image_not_supported, size: 50, color: Colors.grey),
              ),
            ),

            // COLUNA 2: CONTEÚDO
            Expanded(
              flex: 5,
              // Usamos uma Column para empilhar: Header, Conteúdo Rolável e Barra de Ação
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =======================================================
                  // ✅ 1. NOVO HEADER: TÍTULO E BOTÃO DE FECHAR NA MESMA LINHA
                  // =======================================================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              currentProduct.sourceProduct.name.toUpperCase(),
                              maxLines: 2, // ✅ Limita o título a 2 linhas
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,

                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => context.go('/'),
                            tooltip: 'Fechar',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =======================================================
                  // ✅ ÁREA DE CONTEÚDO ROLÁVEL
                  // =======================================================
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          key: _scrollAreaKey,
                          controller: _scrollController, // ✅ CONECTE O CONTROLLER AQUI
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentProduct.sourceProduct.description,
                                style: TextStyle(fontSize: 16,
                                    color: Colors.grey.shade700,
                                    height: 1.5),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                currentProduct.totalPrice.toCurrency,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 32),

                              if (cartVariants.isNotEmpty) ...[
                                ListView.separated(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: cartVariants.length,
                                  itemBuilder: (_, i) {
                                    final variant = cartVariants[i];
                                    // ✅ CORREÇÃO 2: PASSANDO A KEY PARA O WIDGET
                                    return VariantWidget(
                                      onOptionUpdated: (variant, option, newQuantity) {
                                        // ✅ Ação do usuário é DELEGADA para o Cubit central.
                                        context.read<ProductPageCubit>().updateOption(variant, option, newQuantity);
                                      },
                                      variant: variant,
                                   //   itemKey: _variantKeys[variant.id],
                                      //  isSticky: _currentStickyVariant?.id == variant.id,
                                    );
                                  },
                                  separatorBuilder: (_, __) => const SizedBox(height: 40),
                                ),
                              ],
                              const SizedBox(height: 32),

                              // =======================================================
                              // ✅ 3. TEXTAREA PARA OBSERVAÇÕES
                              // =======================================================
                              const Text(
                                'Alguma observação no produto?',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: widget.observationController,
                                keyboardType: TextInputType.multiline,
                                maxLines: 4,
                                // Permite expandir até 4 linhas
                                minLines: 3,
                                // Começa com a altura de 3 linhas
                                decoration: InputDecoration(
                                  hintText: 'Ex: tirar a cebola, maionese à parte etc.',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: theme.primaryColor),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 24),


                              // Espaço extra no final do scroll
                            ],
                          ),
                        ),

                        // // --- CAMADA 2: O HEADER STICKY (SOBREPOSTO) ---
                        // if (_currentStickyVariant != null)
                        //   Positioned(
                        //     top: 0,
                        //     left: 0,
                        //     right: 0,
                        //     child: AnimatedContainer(
                        //       duration: const Duration(milliseconds: 200),
                        //       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        //       color: Colors.white.withOpacity(0.95),
                        //       child: Text(
                        //         _currentStickyVariant!.name,
                        //         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        //       ),
                        //     ),
                        //   ),
                      ],
                    ),
                  ),

                  // =======================================================
                  // ✅ BARRA DE AÇÃO FIXA NO RODAPÉ DA COLUNA
                  // =======================================================
                  _buildActionBar(context, configuredProduct, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );


  }



  Widget _buildActionBar(BuildContext context, CartProduct product, DsTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // BOTÕES DE QUANTIDADE (agora chamam nosso método de estado local)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [


                // ✅ Botão de remover
                IconButton(
                  icon: Icon(Icons.remove, color: theme.primaryColor),
                  // ✅ Chama o método do Cubit, que é a fonte da verdade
                  onPressed: () => context.read<ProductPageCubit>().updateQuantity(product.quantity - 1),
                  color: product.quantity > 1 ? theme.primaryColor : Colors.grey,
                ),


                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(product.quantity.toString()),
                ),

// ✅ Botão de adicionar
                IconButton(
                  icon: Icon(Icons.add, color: theme.primaryColor),
                  // ✅ Chama o método do Cubit
                  onPressed: () => context.read<ProductPageCubit>().updateQuantity(product.quantity + 1),
                ),



              ],
            ),
          ),
          const SizedBox(width: 16),

          // BOTÃO PRINCIPAL (CORREÇÃO FINAL)

          Expanded(
            child: BlocBuilder<CartCubit, CartState>(
              builder: (context, cartState) {
                // O 'product' aqui é o seu CartProduct que vem do estado da página (ex: ProductPageState)

                // Define o texto do botão baseado no modo de edição
                final isEditMode = context.watch<ProductPageCubit>().state.isEditMode;
                final buttonText = isEditMode
                    ? 'Salvar ${product.totalPrice.toCurrency}'
                    : 'Adicionar ${product.totalPrice.toCurrency}';


                return DsPrimaryButton (
                onPressed: cartState.isUpdating || !product.isValid
                ? null
                : () async {

                    final authState = context.read<AuthCubit>().state;
                    final cartCubit = context.read<CartCubit>(); // Pega o CartCubit uma vez


                    final payload = UpdateCartItemPayload(
                      cartItemId: isEditMode ? context.read<ProductPageCubit>().state.originalCartItemId : null,
                      productId: product.sourceProduct.id,
                      quantity: product.quantity,
                      note: widget.observationController.text.trim(),

                      variants: product.cartVariants.map((cartVariant) {
                        final selectedOptions = cartVariant.cartOptions
                            .where((option) => option.quantity > 0).toList();
                        if (selectedOptions.isEmpty) return null;
                        return CartItemVariant(
                          variantId: cartVariant.id,
                          name: cartVariant.name,
                          options: selectedOptions.map((option) =>
                              CartItemVariantOption(
                                  variantOptionId: option.id,
                                  quantity: option.quantity,
                                  name: option.name,
                                  price: option.price
                              )).toList(),
                        );
                      }).whereType<CartItemVariant>().toList(),

                    );

                    // --- CAMINHO 1: USUÁRIO JÁ ESTÁ LOGADO ---
                    if (authState.status == AuthStatus.success) {
                      // Ação direta: simplesmente atualiza o carrinho.
                      cartCubit.updateItem(payload).then((_) {
                        if (context.mounted) context.go('/');
                      });
                    }
                    // --- CAMINHO 2: USUÁRIO NÃO ESTÁ LOGADO ---
                    else {
                      // Navega para a tela de login e ESPERA o resultado.
                      // A tela de onboarding/login deve retornar `true` em caso de sucesso.
                      final loginSuccess = await context.push<bool>('/onboarding');

                      // Se o login foi bem-sucedido, AGORA sim adicionamos o item ao carrinho.
                      if (loginSuccess == true && context.mounted) {
                        cartCubit.updateItem(payload).then((_) {
                          if (context.mounted) context.go('/');
                        });
                      }
                    }

                  },

                  child: cartState.isUpdating ? const DotLoading() : Text(buttonText),
                );
              },
            ),
          )













        ],
      ),
    );
  }
}