// lib/pages/product/product_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/pages/product/product_page_cubit.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/pages/product/widgets/desktop/desktop_product_card.dart';
import 'package:totem/pages/product/widgets/mobilelayout.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/models/page_status.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/app_page_status_builder.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import '../../cubit/auth_cubit.dart';
import '../../models/cart_item.dart';
import '../../models/cart_variant.dart';
import '../../models/cart_variant_option.dart';
import '../../models/update_cart_payload.dart';
import '../../services/pending_cart_service.dart';
import '../../widgets/dot_loading.dart';
import '../cart/cart_cubit.dart';
import '../../cubit/store_cubit.dart';
import '../../cubit/store_state.dart';
import '../cart/cart_state.dart' as CartCubitState;

import '../../core/helpers/side_panel.dart';
import '../../pages/signin/signin_page.dart';
import '../../widgets/clear_cart_confirmation.dart';


class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final TextEditingController observationController = TextEditingController();
  bool _controllerInitialized = false;
  int? _lastProductId; // ✅ NOVO: Rastreia qual produto está sendo editado

  @override
  void dispose() {
    observationController.dispose();
    super.dispose();
  }

  /// ✅ Método helper para inicializar a observação
  /// Chamado tanto no listener quanto no builder para garantir que funcione
  /// independente do timing do carregamento
  void _initializeObservationIfNeeded(ProductPageState state) {
    if (state.product != null) {
      final currentProductId = state.product!.product.id;
      
      // Se o produto mudou, reseta a flag para permitir atualização
      if (_lastProductId != currentProductId) {
        _controllerInitialized = false;
        _lastProductId = currentProductId;
      }
      
      // Atualiza o controller apenas na primeira vez para este produto
      if (!_controllerInitialized) {
        final currentNote = state.product!.note ?? '';
        observationController.text = currentNote;
        _controllerInitialized = true;
        print('📝 [ProductPage] Observação carregada: "$currentNote"');
      }
    }
  }

  // ... (o resto do seu widget build permanece o mesmo)
  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return BlocListener<StoreCubit, StoreState>(
      listener: (context, storeState) {
        final productPageState = context.read<ProductPageCubit>().state;
        if (productPageState.status is PageStatusSuccess && storeState.products != null) {
          try {
            final updatedSourceProduct = storeState.products!.firstWhere(
                  (p) => p.id == productPageState.product!.product.id,
            );
            context.read<ProductPageCubit>().updateWithNewSourceProduct(updatedSourceProduct);
          } catch (e) {
            if (context.canPop()) context.pop();
          }
        }
      },
      child: Material(
        color: Colors.transparent,
        child: BlocConsumer<ProductPageCubit, ProductPageState>(
          listener: (context, state) {
            // Listener também chama o método de inicialização para mudanças de estado
            _initializeObservationIfNeeded(state);
          },
          builder: (context, productState) {
            // ✅ CORREÇÃO: Também verifica no builder para o estado inicial
            // O listener só dispara em MUDANÇAS, não no estado inicial
            _initializeObservationIfNeeded(productState);
            
            return AppPageStatusBuilder<CartProduct>(
              status: productState.status,
              tryAgain: () => context.read<ProductPageCubit>().retryLoad(),
              successBuilder: (productFromState) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (ResponsiveBuilder.isMobile(context)) {
                      return Stack(
                        children: [
                          MobileProductPage(
                            productState: productState,
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
                    return Stack(
                      children: [
                        // ✅ Backdrop escuro
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            color: Colors.black.withOpacity(0.5), // ✅ Backdrop escuro
                          ),
                        ),
                        // ✅ Card centralizado
                        Center(
                          child: DesktopProductCard(
                            productState: productState,
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
      ),
    );
  }

  Widget _buildMobileActionBar(BuildContext context, ProductPageState productState, DsTheme theme) {
    final product = productState.product!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.remove, color: theme.productTextColor),
            onPressed: () => context.read<ProductPageCubit>().updateQuantity(product.quantity - 1),
          ),
          Text(product.quantity.toString()),
          IconButton(
            icon: Icon(Icons.add, color: theme.productTextColor),
            onPressed: () => context.read<ProductPageCubit>().updateQuantity(product.quantity + 1),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: BlocBuilder<CartCubit, CartCubitState.CartState>(
              builder: (context, cartState) {
                final buttonText = productState.isEditMode
                    ? 'Salvar ${product.totalPrice.toCurrency}'
                    : 'Adicionar ${product.totalPrice.toCurrency}';

                // ✅ DEBUG: Verifica por que o botão pode estar desabilitado
                final isButtonDisabled = cartState.isUpdating || !product.isValid;
                
                // ✅ Log detalhado para debug
                if (isButtonDisabled) {
                  print('⚠️ [ProductPage] Botão desabilitado:');
                  print('   - isUpdating: ${cartState.isUpdating}');
                  print('   - isValid: ${product.isValid}');
                  print('   - product: ${product.product.name}');
                  print('   - quantity: ${product.quantity}');
                }
                
                return DsPrimaryButton(
                  onPressed: isButtonDisabled
                      ? null
                      : () {
                          print('🛒 [ProductPage] ✅ Botão "Adicionar" clicado!');
                          print('   - Produto: ${product.product.name}');
                          print('   - Quantidade: ${product.quantity}');
                          _onConfirm(context, productState);
                        },
                  child: cartState.isUpdating ? const DotLoading() : Text(buttonText),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onConfirm(BuildContext context, ProductPageState productState) async {
    print('🛒 [ProductPage] _onConfirm chamado!');
    
    final authState = context.read<AuthCubit>().state;
    final cartCubit = context.read<CartCubit>();
    // ✅ IMPORTANTE: Obtém o produto mais recente do cubit para garantir sincronização
    final cubitState = context.read<ProductPageCubit>().state;
    final product = cubitState.product ?? productState.product!;
    final store = context.read<StoreCubit>().state.store;
    
    print('🔍 [ProductPage] Estado do produto no _onConfirm:');
    print('   - product.id: ${product.product.id}');
    print('   - product.category.isCustomizable: ${product.category.isCustomizable}');
    print('   - product.selectedSize != null: ${product.selectedSize != null}');
    if (product.selectedSize != null) {
      print('   - selectedSize.id: ${product.selectedSize!.id}');
      print('   - selectedSize.linkedProductId: ${product.selectedSize!.linkedProductId}');
    }

    print('🔐 [ProductPage] Estado de autenticação: customer=${authState.customer != null}, status=${authState.status}');

    // ✅ REMOVIDO: Validação de loja fechada movida para o carrinho/checkout
    // Usuários podem adicionar/editar produtos livremente, mesmo com loja fechada
    // A validação acontece apenas ao tentar finalizar o pedido

    // ✅ LÓGICA DE PRODUCT ID PARA PIZZAS (igual ao iFood):
    // Se é uma pizza e tem tamanho selecionado, usa o linkedProductId do tamanho
    // Se não tem linkedProductId (dados antigos), usa o ID do OptionItem como fallback
    int productIdToSend;
    
    print('🔍 [ProductPage] Determinando productId para adicionar ao carrinho:');
    print('   - category.isCustomizable: ${product.category.isCustomizable}');
    print('   - selectedSize != null: ${product.selectedSize != null}');
    print('   - product.id: ${product.product.id}');
    print('   - product.linkedProductId: ${product.product.linkedProductId}');
    
    if (product.category.isCustomizable && product.selectedSize != null) {
      // É uma pizza - usa linkedProductId se disponível
      print('🔍 [ProductPage] Debug tamanho:');
      print('   - selectedSize.id: ${product.selectedSize!.id}');
      print('   - selectedSize.linkedProductId: ${product.selectedSize!.linkedProductId}');
      
      // ✅ PRIORIDADE: linkedProductId do tamanho > linkedProductId do produto > id do tamanho > id do produto
      productIdToSend = product.selectedSize!.linkedProductId ?? 
                       product.product.linkedProductId ?? 
                       product.selectedSize!.id ?? 
                       product.product.id!;
      
      final source = product.selectedSize!.linkedProductId != null 
          ? 'linkedProductId do tamanho'
          : product.product.linkedProductId != null
              ? 'linkedProductId do produto'
              : product.selectedSize!.id != null
                  ? 'ID do tamanho'
                  : 'ID do produto';
      print('🍕 [ProductPage] Pizza: usando $source = $productIdToSend');
    } else {
      // Produto normal - usa product.id
      productIdToSend = product.product.id!;
      print('📦 [ProductPage] Produto normal: usando product.id = $productIdToSend');
    }
    
    print('✅ [ProductPage] productIdToSend final: $productIdToSend');

    // ✅ CORREÇÃO: Para pizzas, usamos optionItemId em vez de variantOptionId
    final isCustomizable = product.category.isCustomizable;
    
    final payload = UpdateCartItemPayload(
      cartItemId: productState.isEditMode ? productState.originalCartItemId : null,
      productId: productIdToSend,  // ✅ Usa o ID correto baseado no tipo de produto
      categoryId: product.category.id!,
      quantity: product.quantity,
      note: observationController.text.trim(),
      sizeName: product.selectedSize?.name,
      variants: product.selectedVariants.map((cartVariant) {
        final selectedOptions = cartVariant.cartOptions.where((option) => option.quantity > 0).toList();
        if (selectedOptions.isEmpty) return null;
        
        // ✅ NOVO: Expande opções combinadas (ex: "Massa Tradicional + Borda Catupiry")
        // Se uma opção tem parentCustomizationOptionId, ela representa uma combinação
        // e precisa ser expandida em duas opções separadas para o backend validar
        final expandedOptions = <CartItemVariantOption>[];
        for (final option in selectedOptions) {
          // ✅ NOVA LÓGICA: Se tem IDs de combo (Massa + Borda) vindos do Backend, usa eles!
          // Isso garante que estamos enviando os IDs REAIS do banco de dados, e não IDs virtuais.
          if (isCustomizable && option.crustId != null && option.edgeId != null) {
              // 1. Adiciona MASSA com ID e Preço real
              expandedOptions.add(CartItemVariantOption(
                 variantOptionId: null,
                 optionItemId: option.crustId, // ID REAL DO BANCO
                 quantity: option.quantity,
                 // Adiciona prefixo se não tiver, para clareza no carrinho
                 name: (option.crustName?.toLowerCase().startsWith('massa') ?? false) 
                      ? (option.crustName ?? 'Massa') 
                      : 'Massa ${option.crustName ?? ''}',
                 price: option.crustPrice ?? 0, // Preço real do componente em centavos
              ));

              // 2. Adiciona BORDA com ID e Preço real
              expandedOptions.add(CartItemVariantOption(
                 variantOptionId: null,
                 optionItemId: option.edgeId, // ID REAL DO BANCO
                 quantity: option.quantity,
                 name: (option.edgeName?.toLowerCase().startsWith('borda') ?? false)
                      ? (option.edgeName ?? 'Borda')
                      : 'Borda ${option.edgeName ?? ''}',
                 price: option.edgePrice ?? 0, // Preço real do componente em centavos
              ));
              
              continue; // ✅ Processado com sucesso, pula fallback
          }

          // ⚠️ FALLBACK (Lógica Antiga): Baseada em split de string e IDs virtuais
          // ✅ Se tem parentCustomizationOptionId, é uma combinação (massa + borda)
          // Precisamos limpar o nome da opção principal (Massa) para enviar apenas "Massa Tradicional"
          String mainOptionName = option.name;
          if (isCustomizable && option.parentCustomizationOptionId != null) {
             final parts = option.name.split(' + ');
             if (parts.isNotEmpty) {
                mainOptionName = parts.first;
             }
          }

          // Adiciona a opção principal (ex: massa)
          expandedOptions.add(CartItemVariantOption(
            variantOptionId: isCustomizable ? null : option.id,
            optionItemId: isCustomizable ? option.id : null,
            quantity: option.quantity,
            name: mainOptionName, // ✅ Usa nome limpo
            price: option.price,
          ));
          
          // ✅ Se tem parentCustomizationOptionId, é uma combinação (massa + borda)
          // Adiciona uma segunda opção para a borda
          if (isCustomizable && option.parentCustomizationOptionId != null) {
            print('🔀 [ProductPage] Expandindo combinação: ${option.name}');
            print('   - ID principal (massa): ${option.id}');
            print('   - ID secundário (borda): ${option.parentCustomizationOptionId}');
            
            // Extrai o nome da borda do nome combinado (ex: "Massa Tradicional + Borda Catupiry" -> "Borda Catupiry")
            final nameParts = option.name.split(' + ');
            final edgeName = nameParts.length > 1 ? nameParts.last : 'Borda';
            
            expandedOptions.add(CartItemVariantOption(
              variantOptionId: null,
              optionItemId: option.parentCustomizationOptionId,
              quantity: option.quantity,
              name: edgeName,
              price: 0, // O preço já está incluído na opção combinada
            ));
          }
        }
        
        return CartItemVariant(
          variantId: isCustomizable ? null : cartVariant.id,  // ✅ null para pizzas
          optionGroupId: isCustomizable ? cartVariant.id : null,  // ✅ ID do OptionGroup para pizzas
          name: cartVariant.name,
          options: expandedOptions,
        );
      }).whereType<CartItemVariant>().toList(),
    );

    Future<void> updateAndPop() async {
      // ✅ SEGURANÇA: Verifica se o carrinho tem itens de outra loja
      final productStoreId = product.product.storeId;
      final canProceed = await canAddToCart(
        context: context,
        productStoreId: productStoreId,
      );
      
      if (!canProceed) {
        return; // Usuário cancelou, não adiciona
      }
      
      await cartCubit.updateItem(payload);
      if (context.mounted) {
        // ✅ Fecha a tela de detalhes do produto
        if (context.canPop()) {
          context.pop(); 
        }

        // ✅ LÓGICA DE REDIRECT INTELIGENTE
        // Verifica se veio do carrinho (via query params)
        final uri = GoRouterState.of(context).uri;
        final fromCart = uri.queryParameters['fromCart'] == 'true';

        if (fromCart || productState.isEditMode) {
          // Se veio do carrinho OU estava editando, volta para o carrinho
          context.go('/cart');
        } else {
          // Caso contrário, vai para a home
          context.go('/');
        }
      }
    }

    // ✅ CORREÇÃO: Verifica se o usuário está logado (customer != null)
    // Isso é mais confiável que verificar apenas o status
    final isLoggedIn = authState.customer != null;
    
    if (isLoggedIn) {
      // ✅ Usuário está logado, adiciona ao carrinho diretamente
      await updateAndPop();
    } else {
      // ✅ Usuário NÃO está logado - abre sidepanel com login
      print('🔐 [ProductPage] Usuário não logado. Abrindo sidepanel de login...');
      
      // ✅ Salva payload pendente antes de pedir login
      await PendingCartService.savePendingCartItem(payload);
      
      // ✅ Usa showResponsiveSidePanel ao invés de navegar
      // No mobile e desktop, abre um modal full screen com o login
      try {
        final loginSuccess = await showResponsiveSidePanel<bool>(
          context,
          const OnboardingPage(),
          useFullScreenOnDesktop: true, // ✅ Força full screen no desktop também
        );
        
        print('🔐 [ProductPage] Resultado do login: $loginSuccess');
        
        // ✅ Após login bem-sucedido, o AuthCubit vai processar o item pendente
        // e depois vamos fechar a tela e navegar para home
        if (loginSuccess == true && context.mounted) {
          print('✅ [ProductPage] Login bem-sucedido. Aguardando processamento do item...');
          // Aguarda um pouco para garantir que o item foi adicionado
          await Future.delayed(const Duration(milliseconds: 500));
          // Fecha a tela de detalhes do produto
          if (context.canPop()) {
            context.pop(); // Fecha tela de detalhes
          }
          // Navega para home
          context.go('/');
        }
      } catch (e) {
        print('❌ [ProductPage] Erro ao abrir sidepanel de login: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao abrir tela de login. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}