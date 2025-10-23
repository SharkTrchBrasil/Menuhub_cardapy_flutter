import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/pages/product/widgets/desktoplayout.dart';
import 'package:totem/pages/product/widgets/mobilelayout.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/models/page_status.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/app_page_status_builder.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import '../../cubit/auth_cubit.dart';
import '../../models/cart.dart';
import '../../models/update_cart_payload.dart';
import '../../widgets/dot_loading.dart';
import '../cart/cart_cubit.dart';
import '../../cubit/store_cubit.dart';
import '../../cubit/store_state.dart';
import '../cart/cart_state.dart' as CartCubitState;
import '../signin/signin_page.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final TextEditingController observationController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 0.0;

  @override
  void initState() {
    super.initState();
     _recordView();

    _scrollController.addListener(_updateAppBarOpacity);
  }

  void _updateAppBarOpacity() {
    const double collapseThreshold = 320 - kToolbarHeight;
    if (_scrollController.hasClients) {
      final double scrollOffset = _scrollController.offset;
      setState(() {
        _appBarOpacity =
            (scrollOffset - collapseThreshold).clamp(0.0, kToolbarHeight) /
            kToolbarHeight;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateAppBarOpacity);
    _scrollController.dispose();
    observationController.dispose();
    super.dispose();
  }


   void _recordView() {
    // Usamos o context.read para não precisar de um BlocBuilder/Consumer
    // A chamada é "dispare e esqueça", não precisamos reagir ao resultado na UI.
 //   context.read<ProductRepository>().recordProductView(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    // ✅ PASSO 1: ENVOLVA SEU WIDGET COM UM BLOCLISTENER
    // Este listener vai "escutar" o StoreCubit em segundo plano.
    return BlocListener<StoreCubit, StoreState>(
        listener: (context, storeState) {
          // Pega o estado atual da página de produto
          final productPageState = context.read<ProductPageCubit>().state;

          // Verifica se o estado da página é de sucesso e se a lista de produtos da loja existe
          if (productPageState.status is PageStatusSuccess && storeState.products != null) {
            try {
              // Encontra a versão mais recente do produto que esta página está exibindo
              final updatedSourceProduct = storeState.products!.firstWhere(
                    (p) => p.id == productPageState.product!.sourceProduct.id,
              );

              // Pede ao ProductPageCubit para se atualizar com os novos dados
              context.read<ProductPageCubit>().updateWithNewSourceProduct(updatedSourceProduct);
              print("🔄 ProductPage reagiu à atualização do produto ${updatedSourceProduct.name}");

            } catch (e) {
              // Se o produto não for encontrado (ex: foi deletado), fecha a página.
              print("❌ Produto não encontrado na lista atualizada, fechando a página.");
              if (context.canPop()) {
                context.pop();
              }
            }
          }
        },
    child:

    Material(
      color: Colors.transparent,
      // Cor transparente para o efeito de dialog no desktop
      child: BlocConsumer<ProductPageCubit, ProductPageState>(
        listener: (context, state) {
          if (state.product != null && observationController.text.isEmpty) {
            observationController.text = state.product!.note;
          }
        },

        builder: (context, productState) {
          return AppPageStatusBuilder<CartProduct>(
            status: productState.status,

            tryAgain: () => context.read<ProductPageCubit>().retryLoad(),
            successBuilder: (productFromState) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  // O Stack e sua lógica interna permanecem os mesmos.
                  // Para mobile, o comportamento não muda.
                  if (ResponsiveBuilder.isMobile(context)) {
                    return Stack(
                      children: [
                        MobileProductPage(
                          product: productFromState,
                          observationController: observationController,
                          theme: theme,
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildMobileActionBar(context, productState, theme),
                        ),
                      ],
                    );
                  }

                  // ✅ LÓGICA MANUAL PARA DESKTOP
                  // Para desktop, criamos um Stack para controlar o clique no fundo.
                  return Stack(
                    children: [
                      // CAMADA 1: O detector de clique no fundo
                      // Este widget cobre a tela inteira por trás do dialog.
                      GestureDetector(
                        // Ao clicar, ele fecha a rota atual.
                        onTap: () => context.pop(),

                        // É importante ter um container, mesmo que transparente,
                        // para que o GestureDetector tenha uma área para detectar o toque.
                        child: Container(color: Colors.transparent),
                      ),

                      // CAMADA 2: O conteúdo do dialog no centro
                      Center(
                        child: DesktopProductCard(
                          product: productFromState,
                          observationController: observationController,
                        ),
                      ),
                    ],
                  );




                },
              );
            },
          );
        },
      ),
    )


    );}








  Widget _buildMobileActionBar(
    BuildContext context,
    ProductPageState productState,
    DsTheme theme,
  ) {
    final product = productState.product!;
    final isEditMode = productState.isEditMode;
    final originalCartItemId = productState.originalCartItemId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botão de remover
          IconButton(
            icon: Icon(Icons.remove, color: theme.productTextColor),
            onPressed: () {
              // Log para ver o que a UI está lendo
              print(
                "UI - Botão Menos: Quantidade atual é ${product.quantity}. Enviando ${product.quantity - 1}.",
              );
              context.read<ProductPageCubit>().updateQuantity(
                product.quantity - 1,
              );
            },
          ),

          Text(product.quantity.toString()),

          // Botão de adicionar
          IconButton(
            icon: Icon(Icons.add, color: theme.productTextColor),
            onPressed: () {
              // Log para ver o que a UI está lendo
              print(
                "UI - Botão Mais: Quantidade atual é ${product.quantity}. Enviando ${product.quantity + 1}.",
              );
              context.read<ProductPageCubit>().updateQuantity(
                product.quantity + 1,
              );
            },
          ),
          Expanded(
            child: BlocBuilder<CartCubit, CartCubitState.CartState>(
              builder: (context, cartState) {
                // O 'product' aqui é o seu CartProduct que vem do estado da página (ex: ProductPageState)

                // Define o texto do botão baseado no modo de edição
                final isEditMode =
                    context.watch<ProductPageCubit>().state.isEditMode;
                final buttonText =
                    isEditMode
                        ? 'Salvar ${product.totalPrice.toCurrency}'
                        : 'Adicionar ${product.totalPrice.toCurrency}';

                return DsPrimaryButton(
                  onPressed:
                      cartState.isUpdating || !product.isValid
                          ? null
                          : () async {
                            // ✅ A função agora é 'async' para poder esperar o login
                            // ✅ 1. VERIFICA A AUTENTICAÇÃO PRIMEIRO
                            final authState = context.read<AuthCubit>().state;
                            final cartCubit =
                                context
                                    .read<
                                      CartCubit
                                    >(); // Pega o CartCubit uma vez

                            // Monta o payload, pois ele será usado em ambos os cenários (logado ou pós-login)
                            final payload = UpdateCartItemPayload(
                              cartItemId:
                                  isEditMode
                                      ? context
                                          .read<ProductPageCubit>()
                                          .state
                                          .originalCartItemId
                                      : null,
                              productId: product.sourceProduct.id,
                              quantity: product.quantity,
                              note: observationController.text.trim(),
                              variants:
                                  product.cartVariants
                                      .map((variant) {
                                        final selectedOptions =
                                            variant.cartOptions
                                                .where(
                                                  (option) =>
                                                      option.quantity > 0,
                                                )
                                                .toList();

                                        if (selectedOptions.isEmpty)
                                          return null;

                                        return CartItemVariant(
                                          // O payload precisa apenas dos IDs
                                          variantId: variant.id,
                                          name: variant.name,
                                          options:
                                              selectedOptions
                                                  .map(
                                                    (
                                                      option,
                                                    ) => CartItemVariantOption(
                                                      name: option.name,
                                                      price: option.price,
                                                      variantOptionId:
                                                          option.id,
                                                      quantity: option.quantity,
                                                      // Não precisamos enviar nome e preço aqui
                                                    ),
                                                  )
                                                  .toList(),
                                        );
                                      })
                                      .whereType<CartItemVariant>()
                                      .toList(),
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
                              final loginSuccess = await context.push<bool>(
                                '/onboarding',
                              );

                              // Se o login foi bem-sucedido, AGORA sim adicionamos o item ao carrinho.
                              if (loginSuccess == true && context.mounted) {
                                cartCubit.updateItem(payload).then((_) {
                                  if (context.mounted) context.go('/');
                                });
                              }
                            }
                          },
                  child:
                      cartState.isUpdating
                          ? const DotLoading()
                          : Text(buttonText),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
