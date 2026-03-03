import 'dart:async'; // ✅ Import necessário para StreamSubscription
import 'dart:ui'; // ✅ Necessário para VoidCallback

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/models/page_status.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/cart_variant.dart';
import 'package:totem/models/cart_variant_option.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/pages/product/product_page_state.dart';
import '../../cubit/catalog_cubit.dart';
import '../../cubit/catalog_state.dart';
import '../../cubit/store_cubit.dart';
import '../../models/cart_item.dart';
import '../../models/category.dart';
import '../../models/image_model.dart';
import '../../models/option_group.dart';
import '../../repositories/storee_repository.dart';
import 'package:totem/helpers/pizza_adapter_helper.dart';
import '../../helpers/enums/product_status.dart';

class ProductPageCubit extends Cubit<ProductPageState> {
  final StoreRepository _repository;
  final StoreCubit _storeCubit;
  final CatalogCubit _catalogCubit;
  final int productId;
  StreamSubscription? _catalogSubscription;

  ProductPageCubit({
    required this.productId,
    required StoreRepository repository,
    required StoreCubit storeCubit,
    required CatalogCubit catalogCubit,
  }) : _repository = repository,
       _storeCubit = storeCubit,
       _catalogCubit = catalogCubit,
       super(ProductPageState.initial()) {
    // ✅ Inicia escuta de atualizações do catálogo
    _catalogSubscription = _catalogCubit.stream.listen(_onCatalogStateChanged);
  }

  @override
  Future<void> close() {
    _catalogSubscription?.cancel();
    return super.close();
  }

  // ✅ Reage a mudanças no catálogo (ex: update granular de categoria)
  void _onCatalogStateChanged(CatalogState catalogState) {
    if (state.status is PageStatusLoading)
      return; // Evita recarrregar se já estiver carregando

    // Verifica se temos um produto carregado
    if (state.product != null) {
      final currentCategory = state.product!.category;

      // Busca a versão mais recente da categoria na memória
      final updatedCategory = catalogState.categories?.firstWhereOrNull(
        (c) => c.id == currentCategory.id,
      );

      // Se a categoria foi atualizada (ou se o produto mudou), recarrega
      // Aqui fazemos um reload simples se a categoria existir e for diferente
      if (updatedCategory != null && updatedCategory != currentCategory) {
        print(
          "🔄 [ProductPageCubit] Detectada atualização na categoria ${updatedCategory.name}. Recarregando produto...",
        );

        // Preserva o estado atual (seleções) se possível
        // Mas para garantir consistência visual (novos grupos, preços), recarregamos
        // Idealmente, deveríamos tentar "reidratar" as seleções

        // Vamos chamar loadProduct mantendo o sizeId se for pizza
        final currentSizeId = state.product!.selectedSize?.id;

        // Se estivermos editando um item (cartItemToEdit), talvez seja melhor não mexer,
        // ou avisar o usuário. Mas o requisito é "reagir".
        if (!state.isEditMode) {
          // Tenta buscar a versão mais recente do produto na memória (caso tenha mudado preço/status)
          final currentProduct = state.product!.product;
          final latestProduct =
              catalogState.products?.firstWhereOrNull(
                (p) => p.id == currentProduct.id,
              ) ??
              currentProduct;

          loadProduct(sizeId: currentSizeId, initialProduct: latestProduct);
        } else {
          print(
            "⚠️ [ProductPageCubit] Em modo edição, ignorando update automático para evitar perda de dados complexos.",
          );
        }
      }
    }
  }

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
        if (categoryId == null)
          throw Exception('Produto sem categoria associada.');

        final allCategories = _catalogCubit.state.categories;
        category =
            allCategories?.firstWhere((c) => c.id == categoryId) ??
            (throw Exception(
              'Categoria com ID $categoryId não encontrada na memória.',
            ));
      } else {
        print("🌎 Cubit: Deep Link. Buscando detalhes na API.");

        final storeSlug = _storeCubit.state.store?.urlSlug;
        if (storeSlug == null) {
          throw Exception(
            "Não foi possível determinar a loja para buscar o produto.",
          );
        }

        product = await _repository.fetchProductDetails(
          productId: productId,
          storeSlug: storeSlug,
        );

        final categoryId = product.categoryLinks.firstOrNull?.categoryId;
        if (categoryId == null)
          throw Exception('Produto da API sem categoria associada.');

        category =
            _catalogCubit.state.categories?.firstWhere(
              (c) => c.id == categoryId,
            ) ??
            await _repository.fetchCategoryDetails(
              categoryId: categoryId,
              storeSlug: storeSlug,
            );
      }

      // ✅ Variável para armazenar o tamanho selecionado (usado para pizzas)
      OptionItem? selectedSize;

      // ✅ LÓGICA DE ADAPTAÇÃO PARA PIZZA
      if (PizzaAdapterHelper.isPizza(category)) {
        print("🍕 [Cubit] Produto detectado como PIZZA (Customizable).");
        print("🍕 [Cubit] ProductId: ${product.id}");

        // 1. Tenta pegar o tamanho pelo ID passado na navegação
        if (sizeId != null) {
          print("🍕 [Cubit] sizeId recebido: $sizeId");
          print("🔍 [Cubit] Buscando tamanho na categoria:");
          print(
            "   - category.optionGroups.length: ${category.optionGroups.length}",
          );
          for (var group in category.optionGroups) {
            if (group.groupType == OptionGroupType.size) {
              print(
                "   - Grupo SIZE encontrado: ${group.name} com ${group.items.length} itens",
              );
              for (var item in group.items) {
                print(
                  "      - Item: ${item.name} (id: ${item.id}, linkedProductId: ${item.linkedProductId})",
                );
              }
            }
          }
          selectedSize = PizzaAdapterHelper.getSelectedSize(category, sizeId);
        }
        // 2. Se for edição, tenta pegar do item do carrinho
        else if (cartItemToEdit != null) {
          print(
            "🍕 [Cubit] Editando item. Buscando tamanho: ${cartItemToEdit.sizeName}",
          );
          final sizeGroup = category.optionGroups.firstWhereOrNull(
            (g) => g.groupType == OptionGroupType.size,
          );
          if (sizeGroup != null) {
            selectedSize = sizeGroup.items.firstWhereOrNull(
              (item) => item.name == cartItemToEdit.sizeName,
            );
          }
        }
        // 3. ✅ NOVO: Se não há sizeId, cria um OptionItem virtual do produto (cada tamanho é um produto)
        else {
          print(
            "⚠️ [Cubit] Nenhum sizeId passado. Criando OptionItem virtual do produto...",
          );
          // Para pizzas, cada tamanho é um produto, então criamos um OptionItem virtual
          // baseado nas informações do produto
          final productId = product.id;
          if (productId != null) {
            // Extrai o nome do tamanho do nome do produto (ex: "MÉDIA 2 SABORES (6 PEDAÇOS)" -> "Média")
            final productName = product.name ?? '';
            final sizeNameMatch = RegExp(
              r'^([A-ZÁÉÍÓÚÇ]+)',
            ).firstMatch(productName);
            final sizeName = sizeNameMatch?.group(1) ?? productName;

            // Cria um OptionItem virtual para representar o tamanho
            // Extrai maxFlavors do nome do produto (ex: "MÉDIA 2 SABORES" -> 2)
            final maxFlavorsMatch = RegExp(
              r'(\d+)\s*SABORES?',
              caseSensitive: false,
            ).firstMatch(productName);
            final maxFlavors =
                maxFlavorsMatch != null
                    ? int.tryParse(maxFlavorsMatch.group(1)!)
                    : 1;

            // Verifica se o produto tem imagem
            ImageModel? sizeImage;
            if (product.images.isNotEmpty) {
              sizeImage = product.images.first;
              print("✅ [Cubit] Imagem do produto encontrada: ${sizeImage.url}");
            } else {
              print("⚠️ [Cubit] Produto não tem imagem");
            }

            print("🔍 [Cubit] Criando OptionItem virtual:");
            print("   - product.id: $productId");
            print("   - product.linkedProductId: ${product.linkedProductId}");

            selectedSize = OptionItem(
              id:
                  product.linkedProductId ??
                  productId, // ✅ Usa o ID real (OptionItem ID) se disponível, senão o inflado
              name: sizeName,
              description: product.description,
              price:
                  (product.price ?? 0) ~/
                  100, // Converte de centavos para reais
              isActive: product.status == ProductStatus.ACTIVE,
              image: sizeImage,
              maxFlavors: maxFlavors, // Número de sabores permitidos
              linkedProductId:
                  product.linkedProductId ??
                  productId, // ✅ ID do produto real no banco para o carrinho
            );
            print("✅ [Cubit] Tamanho virtual criado: ${selectedSize.name}");
            print("   - OptionItem.id: ${selectedSize.id}");
            print(
              "   - OptionItem.linkedProductId: ${selectedSize.linkedProductId}",
            );
          } else {
            print(
              "⚠️ [Cubit] ProductId é null, não é possível criar tamanho virtual.",
            );
          }
        }

        if (selectedSize != null) {
          print(
            "✅ [Cubit] Tamanho selecionado: ${selectedSize.name} (ID: ${selectedSize.id})",
          );
          print("🔍 [Cubit] Detalhes do tamanho selecionado:");
          print("   - selectedSize.id: ${selectedSize.id}");
          print(
            "   - selectedSize.linkedProductId: ${selectedSize.linkedProductId}",
          );
          print("   - product.id: ${product.id}");
          print("   - product.linkedProductId: ${product.linkedProductId}");

          // ✅ FIX: Sempre usa o PizzaAdapterHelper para adaptar a pizza.
          // O PizzaAdapter internamente verifica productOptionGroups com a chave correta
          // (size.linkedProductId ?? size.id) e faz fallback se necessário.
          if (category.productOptionGroups != null) {
            print(
              "🍕 [Cubit] Usando productOptionGroups do backend (${category.productOptionGroups!.length} tamanhos)",
            );
          } else {
            print(
              "⚠️ [Cubit] productOptionGroups não disponível. PizzaAdapter usará fallback.",
            );
          }

          final allProducts = _catalogCubit.state.products ?? [];
          final availableFlavors =
              allProducts.where((p) {
                if (p.status != ProductStatus.ACTIVE) {
                  return false;
                }
                return p.categoryLinks.any(
                  (link) => link.categoryId == category.id,
                );
              }).toList();

          print("🍕 [Cubit] Sabores disponíveis: ${availableFlavors.length}");

          // Adapta o produto usando os productOptionGroups específicos deste tamanho
          final adaptation = PizzaAdapterHelper.adaptPizzaProduct(
            originalProduct: product,
            category: category,
            size: selectedSize,
            availableFlavors: availableFlavors,
          );

          product = adaptation.product;
          category = adaptation.category;

          print(
            "✨ [Cubit] Produto adaptado com sucesso usando productOptionGroups! Grupos na categoria: ${category.optionGroups.length}",
          );
        } else {
          print(
            "❌ [Cubit] Falha ao identificar tamanho selecionado. Exibindo produto original.",
          );
        }
      } else {
        print("📦 [Cubit] Produto normal (não é pizza).");
      }

      CartProduct configuredProduct;

      if (cartItemToEdit != null) {
        configuredProduct = _configureForEdit(
          product,
          category,
          cartItemToEdit,
        );
        // ✅ Para pizzas em edição, garantir que o selectedSize seja setado
        if (category.isCustomizable && selectedSize != null) {
          configuredProduct = configuredProduct.copyWith(
            selectedSize: selectedSize,
          );
        }
        emit(
          state.copyWith(
            status: PageStatusSuccess(configuredProduct),
            product: configuredProduct,
            isEditMode: true,
            originalCartItemId: cartItemToEdit.id,
          ),
        );
      } else {
        configuredProduct = CartProduct.fromProduct(product, category);
        // ✅ Para pizzas, garantir que o selectedSize seja setado (já foi escolhido na grid)
        if (category.isCustomizable && selectedSize != null) {
          configuredProduct = configuredProduct.copyWith(
            selectedSize: selectedSize,
          );
        }
        emit(
          state.copyWith(
            status: PageStatusSuccess(configuredProduct),
            product: configuredProduct,
            isEditMode: false,
          ),
        );
      }
    } catch (e) {
      print("❌ Erro no ProductPageCubit: $e");
      emit(state.copyWith(status: PageStatusError(e.toString())));
    }
  }

  CartProduct _configureForEdit(
    Product product,
    Category category,
    CartItem cartItem,
  ) {
    print('🔧 [_configureForEdit] Iniciando configuração para edição');
    var configuredProduct = CartProduct.fromProduct(product, category);
    OptionItem? selectedSize;

    // 1. Identifica o tamanho
    if (category.isCustomizable) {
      final sizeGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.size,
      );
      if (sizeGroup != null) {
        selectedSize = sizeGroup.items.firstWhereOrNull(
          (item) => item.name == cartItem.sizeName,
        );
        print('   - Tamanho encontrado: ${selectedSize?.name}');
      }
    }

    // 2. Extrai o que está salvo no carrinho (IDs e Qtd)
    final savedOptionIds = <int, int>{};
    final savedOptionNames = <String, int>{};
    final savedFlavors = <Product>[];

    // Busca todos os produtos da loja para reidratar sabores (pizzas)
    final allProducts = _catalogCubit.state.products ?? [];

    for (var v in cartItem.variants) {
      for (var o in v.options) {
        final id = o.effectiveId;
        if (id > 0) savedOptionIds[id] = o.quantity;
        if (o.name.isNotEmpty)
          savedOptionNames[o.name.toLowerCase()] = o.quantity;

        // Se for um sabor (Pizza...), adiciona à lista de sabores recuperados
        if (o.name.toLowerCase().contains('pizza') ||
            o.name.toLowerCase().contains('sabor')) {
          final flavorId = o.effectiveId;
          final flavorProduct = allProducts.firstWhereOrNull(
            (p) => p.id == flavorId,
          );

          if (flavorProduct != null) {
            savedFlavors.add(flavorProduct);
            print(
              '      ✅ Sabor Recuperado por ID: "${flavorProduct.name}" (id: ${flavorProduct.id})',
            );
          } else {
            final flavorByName = allProducts.firstWhereOrNull((p) {
              final cleanName =
                  o.name.replaceAll(RegExp(r'1/\d\s*'), '').toLowerCase();
              return p.name.toLowerCase() == cleanName;
            });
            if (flavorByName != null) {
              savedFlavors.add(flavorByName);
              print(
                '      ✅ Sabor Recuperado por Nome: "${flavorByName.name}"',
              );
            }
          }
        }
      }
    }

    print('   - savedOptionIds: $savedOptionIds');

    // 3. Reconstrói a seleção de variantes (incluindo Combos de Pizza)
    final newSelectedVariants =
        configuredProduct.selectedVariants.map((variant) {
          final newOptions =
              variant.cartOptions.map((option) {
                int quantity = 0;

                // ✅ LÓGICA DE COMBO (Massas e Bordas combinadas na UI)
                if (category.isCustomizable &&
                    (option.crustId != null || option.edgeId != null)) {
                  final cid = option.crustId ?? option.id;
                  final eid =
                      option.edgeId ?? option.parentCustomizationOptionId;

                  if (savedOptionIds.containsKey(cid) &&
                      savedOptionIds.containsKey(eid)) {
                    quantity = 1;
                    print(
                      '      ✅ [Reidratação] Combo Match: "${option.name}" (crust: $cid, edge: $eid)',
                    );
                  }
                }
                // LÓGICA NORMAL (Item único)
                else {
                  quantity = savedOptionIds[option.id] ?? 0;
                  if (quantity == 0 && option.name.isNotEmpty) {
                    quantity = savedOptionNames[option.name.toLowerCase()] ?? 0;
                  }
                }

                return option.copyWith(quantity: quantity);
              }).toList();
          return variant.copyWith(options: newOptions);
        }).toList();

    print(
      '🔧 [_configureForEdit] Configuração concluída. Sabores recuperados: ${savedFlavors.length}',
    );

    return configuredProduct.copyWith(
      quantity: cartItem.quantity,
      note: cartItem.note,
      selectedSize: selectedSize,
      selectedVariants: newSelectedVariants,
      selectedFlavors: savedFlavors, // ✅ Restaura sabores selecionados
    );
  }

  void updateQuantity(int newQuantity) {
    if (state.product == null || newQuantity < 1) return;
    final updatedProduct = state.product!.copyWith(quantity: newQuantity);
    emit(
      state.copyWith(
        product: updatedProduct,
        status: PageStatusSuccess(updatedProduct),
      ),
    );
  }

  void updateWeightQuantity(double newWeightQuantity) {
    if (state.product == null || newWeightQuantity <= 0) return;
    final updatedProduct = state.product!.copyWith(
      weightQuantity: newWeightQuantity,
    );
    emit(
      state.copyWith(
        product: updatedProduct,
        status: PageStatusSuccess(updatedProduct),
      ),
    );
  }

  void updateOption(
    CartVariant variant,
    CartVariantOption option,
    int newQuantity, {
    VoidCallback? onUpdateComplete,
  }) {
    if (state.product == null) return;
    final updatedVariant = variant.updateOption(option, newQuantity);
    final newVariantsList =
        state.product!.selectedVariants.map((v) {
          return v.id == updatedVariant.id ? updatedVariant : v;
        }).toList();
    final newProductState = state.product!.copyWith(
      selectedVariants: newVariantsList,
    );
    emit(
      state.copyWith(
        product: newProductState,
        status: PageStatusSuccess(newProductState),
      ),
    );

    if (onUpdateComplete != null) {
      Future.delayed(const Duration(milliseconds: 300), onUpdateComplete);
    }
  }

  void selectSize(OptionItem size) {
    if (state.product == null || !state.product!.category.isCustomizable)
      return;
    final updatedProduct = state.product!.copyWith(selectedSize: size);
    emit(
      state.copyWith(
        product: updatedProduct,
        status: PageStatusSuccess(updatedProduct),
      ),
    );
  }

  void toggleFlavor(Product flavor) {
    if (state.product == null ||
        !state.product!.category.isCustomizable ||
        state.product!.selectedSize == null)
      return;
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
    final updatedProduct = state.product!.copyWith(
      selectedFlavors: currentFlavors,
    );
    emit(
      state.copyWith(
        product: updatedProduct,
        status: PageStatusSuccess(updatedProduct),
      ),
    );
  }

  void updateWithNewSourceProduct(Product newSourceProduct) {
    if (state.status is! PageStatusSuccess || state.product == null) return;
    final updatedCartProduct = state.product!.copyWith(
      product: newSourceProduct,
    );
    emit(
      state.copyWith(
        product: updatedCartProduct,
        status: PageStatusSuccess(updatedCartProduct),
      ),
    );
  }

  Future<void> retryLoad() async {
    await loadProduct();
  }
}
