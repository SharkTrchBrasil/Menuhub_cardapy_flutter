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
import 'package:totem/models/store_operation_config.dart';

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
        // 3. ✅ NOVO: Se não há sizeId, primeiro tenta resolver o tamanho REAL na categoria
        else {
          final sizeGroup = category.optionGroups.firstWhereOrNull(
            (g) => g.groupType == OptionGroupType.size,
          );

          if (sizeGroup != null) {
            selectedSize = sizeGroup.items.firstWhereOrNull(
              (item) =>
                  item.linkedProductId == product.id ||
                  item.id == product.linkedProductId ||
                  item.linkedProductId == product.linkedProductId ||
                  product.name.toUpperCase().startsWith(
                    item.name.toUpperCase(),
                  ),
            );

            if (selectedSize != null) {
              print(
                "✅ [Cubit] Tamanho real resolvido pela categoria: ${selectedSize.name} (id: ${selectedSize.id}, linkedProductId: ${selectedSize.linkedProductId})",
              );
            }
          }
        }
        // 4. Fallback: cria um OptionItem virtual do produto (cada tamanho é um produto)
        if (selectedSize == null) {
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

      final pricingStrategy =
          _storeCubit
              .state
              .store
              ?.store_operation_config
              ?.pizzaPricingStrategy ??
          PizzaPricingStrategy.highest;

      if (cartItemToEdit != null) {
        configuredProduct = _configureForEdit(
          product,
          category,
          cartItemToEdit,
          pricingStrategy,
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
        // ✅ Para pizzas, garantir que o selectedSize seja setado e a estratégia aplicada
        if (category.isCustomizable) {
          configuredProduct = configuredProduct.copyWith(
            selectedSize: selectedSize,
            pizzaPricingStrategy: pricingStrategy,
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
    PizzaPricingStrategy strategy,
  ) {
    print('🔧 [_configureForEdit] Iniciando configuração para edição');
    var configuredProduct = CartProduct.fromProduct(
      product,
      category,
    ).copyWith(pizzaPricingStrategy: strategy);
    OptionItem? selectedSize;

    // 1. Identifica o tamanho — busca por nome OU por product_id
    if (category.isCustomizable) {
      final sizeGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.size,
      );
      if (sizeGroup != null) {
        // ✅ Tenta primeiro por nome (mais confiável para exibição)
        selectedSize = sizeGroup.items.firstWhereOrNull(
          (item) => item.name == cartItem.sizeName,
        );

        // ✅ Fallback: tenta por linkedProductId (caso o nome tenha mudado)
        if (selectedSize == null && cartItem.product.id != null) {
          selectedSize = sizeGroup.items.firstWhereOrNull(
            (item) => item.linkedProductId == cartItem.product.id,
          );
        }
        print(
          '   - Tamanho encontrado: ${selectedSize?.name} (id: ${selectedSize?.id})',
        );
      }
    }

    // 2. Extrai IDs salvos no carrinho
    final savedOptionIds = <int, int>{}; // {option_item_id: quantity}

    print('   - Variants no carrinho: ${cartItem.variants.length}');
    for (var v in cartItem.variants) {
      print(
        '     variant: groupType=${v.groupType}, optionGroupId=${v.optionGroupId}, name=${v.name}',
      );
      for (var o in v.options) {
        final id = o.effectiveId;
        if (id > 0) {
          savedOptionIds[id] = o.quantity;
          print('       option id=$id, name="${o.name}", qty=${o.quantity}');
        }
      }
    }

    // ✅ Reidrata sabores buscando nos grupos FLAVOR/TOPPING da categoria adaptada
    // (após adaptPizzaProduct, os sabores estão nos grupos 'flavor' ou 'topping')
    final savedFlavors = <Product>[];
    final allProducts = _catalogCubit.state.products ?? [];

    if (category.isCustomizable && selectedSize != null) {
      // Grupos de sabor na categoria adaptada
      final flavorAndToppingGroups =
          category.optionGroups
              .where(
                (g) =>
                    g.groupType == OptionGroupType.flavor ||
                    g.groupType == OptionGroupType.topping,
              )
              .toList();

      for (final group in flavorAndToppingGroups) {
        for (final item in group.items) {
          if (savedOptionIds.containsKey(item.id)) {
            // Busca o Product correspondente pelo ID (optionItemId = product_id do sabor em pizzas)
            final flavorProduct = allProducts.firstWhereOrNull(
              (p) => p.id == item.id || p.id == item.linkedProductId,
            );
            if (flavorProduct != null &&
                !savedFlavors.any((f) => f.id == flavorProduct.id)) {
              savedFlavors.add(flavorProduct);
              print(
                '      ✅ Sabor reidratado por ID: "${flavorProduct.name}" (optionItemId: ${item.id})',
              );
            }
          }
        }
      }
    }

    print('   - savedOptionIds: $savedOptionIds');

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Reconstrói seleções de variantes
    // ─────────────────────────────────────────────────────────────────────────
    //
    // ⚠️ PROBLEMA PIZZA:
    //   • SABORES: Grupos 1000, 1001, 1002 têm os MESMOS itens.
    //     Match "flat" por ID marcaria o mesmo sabor em TODOS os grupos.
    //     → Solução: match por SLOT (cartVariant[i] → flavorGroup[i])
    // ─────────────────────────────────────────────────────────────────────────
    List<CartVariant> newSelectedVariants;

    if (category.isCustomizable) {
      // ✅ PIZZAS EM EDIÇÃO
      // Os sabores salvos no carrinho podem voltar agrupados em um único optionGroupId
      // real do backend, enquanto a UI adaptada cria grupos virtuais 1000, 1001...
      // Portanto, reidratamos por ordem de ocorrência dos sabores salvos e distribuímos
      // um sabor por grupo virtual.
      final Map<int, Set<int>> groupIdToOptionIds = {};
      final List<int> savedFlavorOptionSequence = [];
      for (final v in cartItem.variants) {
        final gid = v.optionGroupId;
        final cartGroupType = OptionGroupType.fromString(v.groupType);

        final isFlavorVariant =
            cartGroupType == OptionGroupType.flavor ||
            cartGroupType == OptionGroupType.topping ||
            (cartGroupType == OptionGroupType.other && gid != 999);

        if (isFlavorVariant) {
          for (final option in v.options) {
            final effectiveId = option.effectiveId;
            if (option.quantity > 0 && effectiveId > 0) {
              savedFlavorOptionSequence.add(effectiveId);
            }
          }
        }

        if (gid == null || gid == 999) {
          continue;
        }

        final optionIds =
            v.options
                .where((o) => o.quantity > 0 && o.effectiveId > 0)
                .map((o) => o.effectiveId)
                .toSet();
        if (optionIds.isNotEmpty) {
          groupIdToOptionIds[gid] = optionIds;
          print('   - GroupId $gid → optionItemIds=$optionIds');
        }
      }
      print(
        '   - groupIdToOptionIds keys: ${groupIdToOptionIds.keys.toList()}',
      );
      print('   - savedFlavorOptionSequence: $savedFlavorOptionSequence');

      final flavorGroups =
          configuredProduct.selectedVariants.where((variant) {
            final og = category.optionGroups.firstWhereOrNull(
              (g) => g.id == variant.id,
            );
            return og != null &&
                (og.groupType == OptionGroupType.flavor ||
                    og.groupType == OptionGroupType.topping);
          }).toList();

      final Map<int, int> flavorVariantIdToSelectedOptionId = {};
      for (
        int i = 0;
        i < flavorGroups.length && i < savedFlavorOptionSequence.length;
        i++
      ) {
        flavorVariantIdToSelectedOptionId[flavorGroups[i].id] =
            savedFlavorOptionSequence[i];
      }
      print(
        '   - flavorVariantIdToSelectedOptionId: $flavorVariantIdToSelectedOptionId',
      );

      newSelectedVariants =
          configuredProduct.selectedVariants.map((variant) {
            final og = category.optionGroups.firstWhereOrNull(
              (g) => g.id == variant.id,
            );
            final isFlavorGroup =
                og != null &&
                (og.groupType == OptionGroupType.flavor ||
                    og.groupType == OptionGroupType.topping);

            if (isFlavorGroup) {
              // 1º: usa a sequência salva para distribuir um sabor por slot virtual
              final selectedOptionId =
                  flavorVariantIdToSelectedOptionId[variant.id];
              // 2º: fallback para casos onde o backend preserva optionGroupId virtual
              final idsForGroup = groupIdToOptionIds[variant.id] ?? {};
              print(
                '   ↪ Flavor group id=${variant.id}: selectedOptionId=$selectedOptionId, ids=$idsForGroup',
              );

              final newOptions =
                  variant.cartOptions.map((option) {
                    final qty =
                        (selectedOptionId != null &&
                                    option.id == selectedOptionId) ||
                                idsForGroup.contains(option.id)
                            ? 1
                            : 0;
                    if (qty > 0)
                      print(
                        '      ✅ Sabor: "${option.name}" (id=${option.id})',
                      );
                    return option.copyWith(quantity: qty);
                  }).toList();

              return variant.copyWith(options: newOptions);
            } else {
              final groupType = og?.groupType ?? OptionGroupType.other;
              final newOptions =
                  variant.cartOptions.map((option) {
                    int quantity = 0;

                    if (groupType == OptionGroupType.crust ||
                        groupType == OptionGroupType.edge) {
                      quantity = savedOptionIds[option.id] ?? 0;
                      if (quantity > 0) {
                        print(
                          '      ✅ ${groupType == OptionGroupType.crust ? 'Massa' : 'Borda'} por tipo: "${option.name}" (id=${option.id})',
                        );
                      }
                    } else if (option.crustId != null ||
                        option.edgeId != null) {
                      final cid = option.crustId;
                      final eid =
                          option.edgeId ?? option.parentCustomizationOptionId;
                      if (cid != null &&
                          eid != null &&
                          savedOptionIds.containsKey(cid) &&
                          savedOptionIds.containsKey(eid)) {
                        quantity = 1;
                        print('      ✅ Combo por ID: "${option.name}"');
                      }
                    } else {
                      quantity = savedOptionIds[option.id] ?? 0;
                    }

                    return option.copyWith(quantity: quantity);
                  }).toList();

              return variant.copyWith(options: newOptions);
            }
          }).toList();
    } else {
      // Produtos normais: match direto por ID
      newSelectedVariants =
          configuredProduct.selectedVariants.map((variant) {
            final newOptions =
                variant.cartOptions.map((option) {
                  final qty = savedOptionIds[option.id] ?? 0;
                  return option.copyWith(quantity: qty);
                }).toList();
            return variant.copyWith(options: newOptions);
          }).toList();
    }

    print('🔧 [_configureForEdit] Concluído. Sabores: ${savedFlavors.length}');

    return configuredProduct.copyWith(
      quantity: cartItem.quantity,
      note: cartItem.note,
      selectedSize: selectedSize,
      selectedVariants: newSelectedVariants,
      selectedFlavors: savedFlavors,
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

    // ✅ FIX PIZZA PREÇO: Ao trocar de tamanho, recalcula os preços dos sabores
    // usando prices_by_size do novo tamanho selecionado.
    // Sem isso, os preços ficam congelados no valor do tamanho anterior (ou 0).
    final category = state.product!.category;
    final toppingGroupIds =
        category.optionGroups
            .where((g) => g.groupType == OptionGroupType.topping)
            .map((g) => g.id)
            .toSet();

    final updatedVariants =
        state.product!.selectedVariants.map((variant) {
          // Só atualiza preços de grupos TOPPING
          if (!toppingGroupIds.contains(variant.id)) return variant;

          // Encontra o OptionGroup original para acessar pricesBySize
          final originalGroup = category.optionGroups.firstWhereOrNull(
            (g) => g.id == variant.id,
          );
          if (originalGroup == null) return variant;

          final updatedOptions =
              variant.cartOptions.map((cartOption) {
                final originalItem = originalGroup.items.firstWhereOrNull(
                  (item) => item.id == cartOption.id,
                );
                if (originalItem == null) return cartOption;

                // Resolve preço via prices_by_size para o novo tamanho
                final newPrice =
                    originalItem.getPriceForSize(size.id) ??
                    originalItem.getPriceForSize(size.linkedProductId) ??
                    originalItem.price;

                return cartOption.copyWith(
                  price: newPrice > 0 ? newPrice : cartOption.price,
                );
              }).toList();

          return CartVariant(
            id: variant.id,
            name: variant.name,
            groupType: variant.groupType,
            uiDisplayMode: variant.uiDisplayMode,
            minSelectedOptions: variant.minSelectedOptions,
            maxSelectedOptions: variant.maxSelectedOptions,
            maxTotalQuantity: variant.maxTotalQuantity,
            cartOptions: updatedOptions,
          );
        }).toList();

    final updatedProduct = state.product!.copyWith(
      selectedSize: size,
      selectedVariants: updatedVariants,
    );
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
