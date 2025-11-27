// lib/pages/product/product_page_cubit.dart

import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/models/page_status.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/cart_variant.dart';
import 'package:totem/models/cart_variant_option.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/pages/product/product_page_state.dart';
import '../../cubit/store_cubit.dart';
import '../../models/cart_item.dart';
import '../../models/category.dart';
import '../../models/option_group.dart';
import '../../repositories/storee_repository.dart';
import 'package:totem/helpers/pizza_adapter_helper.dart'; // ✅ Import do helper

class ProductPageCubit extends Cubit<ProductPageState> {
  final StoreRepository _repository;
  final StoreCubit _storeCubit;
  final int productId;

  ProductPageCubit({
    required this.productId,
    required StoreRepository repository,
    required StoreCubit storeCubit,
  })  : _repository = repository,
        _storeCubit = storeCubit,
        super(ProductPageState.initial());

  Future<void> loadProduct({
    Product? initialProduct,
    CartItem? cartItemToEdit,
    int? sizeId, // ✅ Novo parâmetro opcional
  }) async {
    emit(state.copyWith(status: PageStatusLoading()));
    try {
      Product product;
      Category category;

      if (initialProduct != null || cartItemToEdit != null) {
        print("🧠 Cubit: Usando produto pré-carregado.");
        product = initialProduct ?? cartItemToEdit!.product;

        final categoryId = product.categoryLinks.firstOrNull?.categoryId;
        if (categoryId == null) throw Exception('Produto sem categoria associada.');

        final allCategories = _storeCubit.state.categories;
        category = allCategories?.firstWhere((c) => c.id == categoryId)
            ?? (throw Exception('Categoria com ID $categoryId não encontrada na memória.'));
      }
      else {
        print("🌎 Cubit: Deep Link. Buscando detalhes na API.");

        final storeSlug = _storeCubit.state.store?.urlSlug;
        if (storeSlug == null) {
          throw Exception("Não foi possível determinar a loja para buscar o produto.");
        }

        product = await _repository.fetchProductDetails(
          productId: productId,
          storeSlug: storeSlug,
        );

        final categoryId = product.categoryLinks.firstOrNull?.categoryId;
        if (categoryId == null) throw Exception('Produto da API sem categoria associada.');

        category = _storeCubit.state.categories?.firstWhere((c) => c.id == categoryId)
            ?? await _repository.fetchCategoryDetails(
              categoryId: categoryId,
              storeSlug: storeSlug,
            );
      }

      // ✅ Variável para armazenar o tamanho selecionado (usado para pizzas)
      OptionItem? selectedSize;
      
      // ✅ LÓGICA DE ADAPTAÇÃO PARA PIZZA
      if (PizzaAdapterHelper.isPizza(category)) {
        print("🍕 [Cubit] Produto detectado como PIZZA (Customizable).");
        
        // 1. Tenta pegar o tamanho pelo ID passado na navegação
        if (sizeId != null) {
          print("🍕 [Cubit] sizeId recebido: $sizeId");
          selectedSize = PizzaAdapterHelper.getSelectedSize(category, sizeId);
        } 
        // 2. Se for edição, tenta pegar do item do carrinho
        else if (cartItemToEdit != null) {
           print("🍕 [Cubit] Editando item. Buscando tamanho: ${cartItemToEdit.sizeName}");
           final sizeGroup = category.optionGroups.firstWhereOrNull((g) => g.groupType == OptionGroupType.size);
           if (sizeGroup != null) {
             selectedSize = sizeGroup.items.firstWhereOrNull((item) => item.name == cartItemToEdit.sizeName);
           }
        } else {
          print("⚠️ [Cubit] Nenhum sizeId passado e não é edição.");
        }

        if (selectedSize != null) {
          print("✅ [Cubit] Tamanho selecionado: ${selectedSize.name} (ID: ${selectedSize.id})");
          
          // Busca todos os produtos da categoria para usar como sabores
          final allProducts = _storeCubit.state.products ?? [];
          final availableFlavors = allProducts.where((p) {
             return p.categoryLinks.any((link) => link.categoryId == category.id);
          }).toList();
          
          print("🍕 [Cubit] Sabores disponíveis encontrados: ${availableFlavors.length}");

          // Adapta o produto para estrutura virtual (grupos de sabores e preferências)
          final adaptation = PizzaAdapterHelper.adaptPizzaProduct(
            originalProduct: product,
            category: category,
            size: selectedSize,
            availableFlavors: availableFlavors,
          );
          
          product = adaptation.product;
          category = adaptation.category;
          
          print("✨ [Cubit] Produto adaptado com sucesso! Grupos na categoria: ${category.optionGroups.length}");
        } else {
          print("❌ [Cubit] Falha ao identificar tamanho selecionado. Exibindo produto original.");
        }
      } else {
        print("📦 [Cubit] Produto normal (não é pizza).");
      }

      CartProduct configuredProduct;

      if (cartItemToEdit != null) {
        configuredProduct = _configureForEdit(product, category, cartItemToEdit);
        // ✅ Para pizzas em edição, garantir que o selectedSize seja setado
        if (category.isCustomizable && selectedSize != null) {
          configuredProduct = configuredProduct.copyWith(selectedSize: selectedSize);
        }
        emit(state.copyWith(
          status: PageStatusSuccess(configuredProduct),
          product: configuredProduct,
          isEditMode: true,
          originalCartItemId: cartItemToEdit.id,
        ));
      } else {
        configuredProduct = CartProduct.fromProduct(product, category);
        // ✅ Para pizzas, garantir que o selectedSize seja setado (já foi escolhido na grid)
        if (category.isCustomizable && selectedSize != null) {
          configuredProduct = configuredProduct.copyWith(selectedSize: selectedSize);
        }
        emit(state.copyWith(
          status: PageStatusSuccess(configuredProduct),
          product: configuredProduct,
          isEditMode: false,
        ));
      }
    } catch (e) {
      print("❌ Erro no ProductPageCubit: $e");
      emit(state.copyWith(status: PageStatusError(e.toString())));
    }
  }

  CartProduct _configureForEdit(Product product, Category category, CartItem cartItem) {
    var configuredProduct = CartProduct.fromProduct(product, category);
    OptionItem? selectedSize;
    if (category.isCustomizable) {
      final sizeGroup = category.optionGroups.firstWhereOrNull((g) => g.groupType == OptionGroupType.size);
      if (sizeGroup != null) {
        selectedSize = sizeGroup.items.firstWhereOrNull((item) => item.name == cartItem.sizeName);
      }
    }
    final savedVariantOptions = {
      for (var v in cartItem.variants)
        for (var o in v.options) o.variantOptionId: o.quantity
    };
    final newSelectedVariants = configuredProduct.selectedVariants.map((variant) {
      final newOptions = variant.cartOptions.map((option) {
        return option.copyWith(quantity: savedVariantOptions[option.id] ?? 0);
      }).toList();
      return variant.copyWith(options: newOptions);
    }).toList();
    return configuredProduct.copyWith(
      quantity: cartItem.quantity,
      note: cartItem.note,
      selectedSize: selectedSize,
      selectedVariants: newSelectedVariants,
    );
  }

  void updateQuantity(int newQuantity) {
    if (state.product == null || newQuantity < 1) return;
    final updatedProduct = state.product!.copyWith(quantity: newQuantity);
    emit(state.copyWith(product: updatedProduct, status: PageStatusSuccess(updatedProduct)));
  }
  
  void updateWeightQuantity(double newWeightQuantity) {
    if (state.product == null || newWeightQuantity <= 0) return;
    final updatedProduct = state.product!.copyWith(weightQuantity: newWeightQuantity);
    emit(state.copyWith(product: updatedProduct, status: PageStatusSuccess(updatedProduct)));
  }

  void updateOption(CartVariant variant, CartVariantOption option, int newQuantity, {VoidCallback? onUpdateComplete}) {
    if (state.product == null) return;
    final updatedVariant = variant.updateOption(option, newQuantity);
    final newVariantsList = state.product!.selectedVariants.map((v) {
      return v.id == updatedVariant.id ? updatedVariant : v;
    }).toList();
    final newProductState = state.product!.copyWith(selectedVariants: newVariantsList);
    emit(state.copyWith(product: newProductState, status: PageStatusSuccess(newProductState)));
    
    if (onUpdateComplete != null) {
      Future.delayed(const Duration(milliseconds: 300), onUpdateComplete);
    }
  }

  void selectSize(OptionItem size) {
    if (state.product == null || !state.product!.category.isCustomizable) return;
    final updatedProduct = state.product!.copyWith(selectedSize: size);
    emit(state.copyWith(product: updatedProduct, status: PageStatusSuccess(updatedProduct)));
  }

  void toggleFlavor(Product flavor) {
    if (state.product == null || !state.product!.category.isCustomizable || state.product!.selectedSize == null) return;
    final currentFlavors = List<Product>.from(state.product!.selectedFlavors);
    final maxFlavors = state.product!.selectedSize!.maxFlavors ?? 1;
    final isAlreadySelected = currentFlavors.any((f) => f.id == flavor.id);
    if (isAlreadySelected) {
      currentFlavors.removeWhere((f) => f.id == flavor.id);
    } else {
      if (currentFlavors.length < maxFlavors) {
        currentFlavors.add(flavor);
      } else {
        print("Atingiu o número máximo de sabores.");
        return;
      }
    }
    final updatedProduct = state.product!.copyWith(selectedFlavors: currentFlavors);
    emit(state.copyWith(product: updatedProduct, status: PageStatusSuccess(updatedProduct)));
  }

  void updateWithNewSourceProduct(Product newSourceProduct) {
    if (state.status is! PageStatusSuccess || state.product == null) return;
    final updatedCartProduct = state.product!.copyWith(
      product: newSourceProduct,
    );
    emit(state.copyWith(product: updatedCartProduct, status: PageStatusSuccess(updatedCartProduct)));
  }

  Future<void> retryLoad() async {
    await loadProduct();
  }
}