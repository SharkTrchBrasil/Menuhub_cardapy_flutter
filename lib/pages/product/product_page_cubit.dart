// Em: lib/pages/product/product_page_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/helpers/enums.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/pages/product/product_page_state.dart';
import 'package:totem/models/page_status.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/cart.dart';
import 'package:totem/models/cart_variant.dart';
import 'package:totem/models/cart_variant_option.dart';
import '../../models/category.dart';

import '../../repositories/storee_repository.dart';

class ProductPageCubit extends Cubit<ProductPageState> {
  final StoreRepository _repository;
  final int productId;

  ProductPageCubit({
    required this.productId,
    required StoreRepository repository,
  })  : _repository = repository,
        super(ProductPageState.initial());

  // ✅ MÉTODO DE ATUALIZAÇÃO UNIFICADO E SIMPLIFICADO
  void updateOption(CartVariant variant, CartVariantOption option, int newQuantity) {
    if (state.product == null) return;

    // 1. Pede para o próprio model 'variant' se atualizar, aplicando suas regras internas.
    final updatedVariant = variant.updateOption(option, newQuantity);

    // 2. Mapeia a lista de variantes do estado, substituindo apenas a que foi alterada.
    final newVariantsList = state.product!.cartVariants.map((v) {
      return v.id == updatedVariant.id ? updatedVariant : v;
    }).toList();

    // 3. Cria o novo estado do produto.
    final newProductState = state.product!.copyWith(cartVariants: newVariantsList);

    // 4. Emite o novo estado completo.
    emit(state.copyWith(product: newProductState, status: PageStatusSuccess(newProductState)));
  }


  void updateWithNewSourceProduct(Product newSourceProduct) {
    if (state.status is! PageStatusSuccess) return;

    // Pega o produto atual (com as escolhas do usuário) do estado
    final currentCartProduct = state.product!;

    final updatedCartProduct = currentCartProduct.copyWith(
      sourceProduct: newSourceProduct,
    );


    emit(state.copyWith(
      product: updatedCartProduct,
      status: PageStatusSuccess(updatedCartProduct),
    ));
  }

  /// O método de carregamento com a lógica final e otimizada.
  Future<void> loadProduct({
    Product? initialProduct,
    CartItem? cartItemToEdit,
  }) async {
    try {
      // --- Cenário 1: MODO EDIÇÃO (com UI Otimista) ---
      if (cartItemToEdit != null) {
        print("🧠 Cubit: Modo Edição Otimista.");

        final temporaryProduct = Product(
          id: cartItemToEdit.product.id,
          name: cartItemToEdit.product.name,
          description:  '',
          basePrice: 0, // O preço será calculado a partir das variantes

          category: Category.empty(), // Placeholder
          variantLinks: [],
          featured: false,
          activatePromotion: false,
          productType: ProductType.INDIVIDUAL,
          components: [],
          defaultOptionIds: [],
          cashbackType: '',
          cashbackValue: 0, // Vazio por enquanto
          status: ProductStatus.active, images: [], galleryImages: [], categoryLinks: [], prices: []
        );

        // Cria o CartProduct com os dados temporários para a UI não ficar vazia
        CartProduct optimisticConfiguredProduct = CartProduct.fromProduct(temporaryProduct)
            .copyWith(quantity: cartItemToEdit.quantity, note: cartItemToEdit.note);

        // EMITE O ESTADO DE SUCESSO IMEDIATAMENTE! A TELA APARECE NA HORA.
        emit(state.copyWith(
          status: PageStatusSuccess(optimisticConfiguredProduct),
          product: optimisticConfiguredProduct,
          isEditMode: true,
          originalCartItemId: cartItemToEdit.id,
        ));

        // --- ETAPA 2: BUSCA E SINCRONIZAÇÃO EM SEGUNDO PLANO ---
        print("🔄 Cubit: Sincronizando dados completos em segundo plano...");
        final productBase = await _repository.fetchProductDetails(productId);
        CartProduct finalConfiguredProduct = CartProduct.fromProduct(productBase);

        // A lógica de mesclagem para pré-selecionar os complementos
        final savedOptions = <int, int>{};
        for (var variant in cartItemToEdit.variants) {
          for (var option in variant.options) {
            savedOptions[option.variantOptionId] = option.quantity;
          }
        }
        final newCartVariants = finalConfiguredProduct.cartVariants.map((variant) {
          final newOptions = variant.cartOptions.map((option) {
            return option.copyWith(quantity: savedOptions[option.id] ?? 0);
          }).toList();
          return variant.copyWith(options: newOptions);
        }).toList();

        finalConfiguredProduct = finalConfiguredProduct.copyWith(
          quantity: cartItemToEdit.quantity,
          note: cartItemToEdit.note,
          cartVariants: newCartVariants,
        );

        // EMITE O ESTADO DE SUCESSO FINAL com os dados 100% corretos e completos.
        // A UI vai se "corrigir" silenciosamente se algo tiver mudado.
        emit(state.copyWith(
          status: PageStatusSuccess(finalConfiguredProduct),
          product: finalConfiguredProduct,
        ));
        return;
      }

      // --- Cenário 2: Navegação Interna (dados já disponíveis) ---
      if (initialProduct != null) {
        print("🧠 Cubit: Navegação interna. Usando produto pré-carregado.");
        final configuredProduct = CartProduct.fromProduct(initialProduct);
        emit(state.copyWith(
          status: PageStatusSuccess(configuredProduct),
          product: configuredProduct,
          isEditMode: false,
        ));
        return;
      }

      // --- Cenário 3: Navegação Externa (Deep Link) ---
      print("🌎 Cubit: Navegação externa. Buscando produto na API.");
      emit(state.copyWith(status: PageStatusLoading()));
      final product = await _repository.fetchProductDetails(productId);
      final configuredProduct = CartProduct.fromProduct(product);

      emit(state.copyWith(
        status: PageStatusSuccess(configuredProduct),
        product: configuredProduct,
        isEditMode: false,
      ));

    } catch (e) {
      emit(state.copyWith(status: PageStatusError(e.toString())));
    }
  }


  Future<void> retryLoad() async {
    // Não precisa mais do estado inicial, apenas chama o load novamente.
    await loadProduct();
  }


  void updateQuantity(int newQuantity) {
    // Adicionamos logs para depuração
    print("--- ⚙️ ProductPageCubit: updateQuantity chamado ---");

    if (state.product == null) {
      print("=> ❗️ Ação ignorada: state.product é nulo.");
      return;
    }

    final currentProduct = state.product!;
    print("=>  QUANTIDADE ATUAL NO ESTADO: ${currentProduct.quantity}");
    print("=> NOVA QUANTIDADE SOLICITADA: $newQuantity");

    // Impede que a quantidade seja menor que 1
    if (newQuantity < 1) {
      print("=> ❗️ Ação ignorada: nova quantidade é menor que 1.");
      return;
    }

    // Garante que estamos criando uma cópia completamente nova e imutável do produto
    final updatedProduct = currentProduct.copyWith(quantity: newQuantity);
    print("=> QUANTIDADE FINAL A SER EMITIDA: ${updatedProduct.quantity}");

    // Emite o novo estado. O `copyWith` do state também é crucial.
    emit(state.copyWith(
      product: updatedProduct,
      // É importante emitir um novo PageStatusSuccess para que o AppPageStatusBuilder receba o novo dado
      status: PageStatusSuccess(updatedProduct),
    ));

    print("--- ✅ ProductPageCubit: Novo estado emitido ---");
  }

}