// lib/models/cart_product.dart

import 'package:equatable/equatable.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/cart_variant.dart';
import 'package:totem/models/cart_variant_option.dart';
import 'package:totem/helpers/enums/displaymode.dart';
import 'package:totem/models/store_operation_config.dart';

class CartProduct extends Equatable {
  // PROPRIEDADES DE ORIGEM (IMUTÁVEIS)
  final Product product;
  final Category category;

  // ESTADO DA SELEÇÃO DO USUÁRIO
  final int quantity; // Quantidade inteira (para unidades)
  final double? weightQuantity; // ✅ NOVO: Quantidade decimal (para kg/litros)
  final String? note;
  final OptionItem? selectedSize;
  final List<Product> selectedFlavors;
  final List<CartVariant> selectedVariants;

  const CartProduct({
    required this.product,
    required this.category,
    this.quantity = 1,
    this.weightQuantity, // ✅ NOVO: Quantidade decimal para kg/litros
    this.note,
    this.selectedSize,
    this.selectedFlavors = const [],
    this.selectedVariants = const [],
    this.pizzaPricingStrategy = PizzaPricingStrategy.highest,
  });

  final PizzaPricingStrategy pizzaPricingStrategy;

  // ✅ NOVO: Getter para quantidade efetiva (usa weightQuantity se disponível)
  double get effectiveQuantity {
    if (product.unit.requiresQuantityInput && weightQuantity != null) {
      return weightQuantity!;
    }
    return quantity.toDouble();
  }

  // ✅ NOVO: Verifica se precisa de entrada de quantidade decimal
  bool get requiresDecimalQuantity {
    return product.unit.requiresQuantityInput;
  }

  // Construtor de fábrica para iniciar a configuração de um produto
  factory CartProduct.fromProduct(Product product, Category category) {
    List<CartVariant> variants = [];
    OptionItem? defaultSize;

    if (category.isCustomizable) {
      final sizeGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.size,
      );
      defaultSize = sizeGroup?.items.firstOrNull;

      // 2. Converte grupos em variants, filtrando opções e grupos inativos
      variants =
          category.optionGroups
              .map((group) {
                final activeItems =
                    group.items.where((item) => item.isActive).toList();
                if (activeItems.isEmpty) return null;

                final isRequired = group.minSelection > 0;
                final hasOnlyOneOption = activeItems.length == 1;

                final cartOptions =
                    activeItems.map((item) {
                      final shouldAutoSelect = isRequired && hasOnlyOneOption;
                      int resolvedPrice = item.price;
                      if (resolvedPrice == 0 &&
                          group.groupType == OptionGroupType.topping &&
                          defaultSize?.id != null &&
                          item.pricesBySize != null &&
                          item.pricesBySize!.isNotEmpty) {
                        resolvedPrice =
                            item.getPriceForSize(defaultSize!.id) ?? 0;
                      }

                      return CartVariantOption(
                        id: item.id ?? 0,
                        name: item.name,
                        price: resolvedPrice,
                        trackInventory: false,
                        stockQuantity: 0,
                        isActuallyAvailable: true,
                        description: item.description,
                        imageUrl: item.image?.url,
                        parentCustomizationOptionId:
                            item.parentCustomizationOptionId,
                        crustId: item.crustId,
                        edgeId: item.edgeId,
                        crustName: item.crustName,
                        edgeName: item.edgeName,
                        crustPrice: item.crustPrice,
                        edgePrice: item.edgePrice,
                        quantity: shouldAutoSelect ? 1 : 0,
                      );
                    }).toList();

                final displayMode =
                    group.maxSelection == 1
                        ? UIDisplayMode.SINGLE
                        : UIDisplayMode.MULTIPLE;

                return CartVariant(
                  id: group.id ?? 0,
                  name: group.name,
                  groupType: group.groupType.toApiString(),
                  uiDisplayMode: displayMode,
                  minSelectedOptions: group.minSelection,
                  maxSelectedOptions: group.maxSelection,
                  maxTotalQuantity: null,
                  cartOptions: cartOptions,
                );
              })
              .whereType<CartVariant>()
              .toList();
    } else {
      // ✅ NOVO: Para produtos normais, combina variantLinks do produto + optionGroups da categoria (ex: Pão na Chapa)
      variants =
          product.variantLinks
              .map((link) => CartVariant.fromProductVariantLink(link))
              .toList();

      if (category.optionGroups.isNotEmpty) {
        final groupVariants =
            category.optionGroups
                .map((group) {
                  final activeItems =
                      group.items.where((item) => item.isActive).toList();
                  if (activeItems.isEmpty) return null;

                  final isRequired = group.minSelection > 0;
                  final hasOnlyOneOption = activeItems.length == 1;

                  final cartOptions =
                      activeItems.map((item) {
                        final shouldAutoSelect = isRequired && hasOnlyOneOption;
                        return CartVariantOption(
                          id: item.id ?? 0,
                          name: item.name,
                          price: item.price,
                          trackInventory: false,
                          stockQuantity: 0,
                          isActuallyAvailable: true,
                          description: item.description,
                          imageUrl: item.image?.url,
                          quantity: shouldAutoSelect ? 1 : 0,
                        );
                      }).toList();

                  final displayMode =
                      group.maxSelection == 1
                          ? UIDisplayMode.SINGLE
                          : UIDisplayMode.MULTIPLE;

                  return CartVariant(
                    id: group.id ?? 0,
                    name: group.name,
                    groupType: group.groupType.toApiString(),
                    uiDisplayMode: displayMode,
                    minSelectedOptions: group.minSelection,
                    maxSelectedOptions: group.maxSelection,
                    maxTotalQuantity: null,
                    cartOptions: cartOptions,
                  );
                })
                .whereType<CartVariant>()
                .toList();

        // Adiciona apenas grupos que não conflitem em IDs com os variants do produto (segurança)
        for (var gv in groupVariants) {
          if (!variants.any((v) => v.id == gv.id)) {
            variants.add(gv);
          }
        }
      }
    }

    return CartProduct(
      product: product,
      category: category,
      selectedVariants: variants,
      selectedSize: defaultSize,
    );
  }

  // GETTERS PARA CÁLCULO DE PREÇO E VALIDAÇÃO

  // Preço base do item
  int get basePrice {
    // Para customizáveis (pizzas), o preço vem dos sabores selecionados
    if (category.isCustomizable) {
      if (selectedSize == null) return 0;

      // ✅ Busca TODOS os grupos FLAVOR (já adaptados pelo PizzaAdapterHelper)
      // O PizzaAdapterHelper converte TOPPING groups em FLAVOR groups com IDs virtuais negativos (-1000-i)
      final flavorGroups =
          category.optionGroups
              .where((g) => g.groupType == OptionGroupType.flavor)
              .toList();

      if (flavorGroups.isNotEmpty) {
        // ✅ CORREÇÃO CRÍTICA: Para cada opção selecionada, busca o preço CHEIO
        // via pricesBySize do OptionItem original.
        // O preço armazenado no CartVariantOption é FRACIONADO (preço/N) para exibição.
        // Usar o fracionado * N causa diferença por arredondamento vs o backend.
        final List<int> fullPrices = [];

        for (final flavorGroup in flavorGroups) {
          final flavorVariant = selectedVariants.firstWhereOrNull(
            (v) => v.id == flavorGroup.id,
          );

          if (flavorVariant != null) {
            for (final option in flavorVariant.cartOptions.where(
              (o) => o.quantity > 0,
            )) {
              // Busca o OptionItem deste grupo para acessar pricesBySize
              final flavorItem = flavorGroup.items.firstWhereOrNull(
                (item) => item.id == option.id,
              );

              if (flavorItem != null) {
                // ✅ PREÇO CHEIO: busca pelo selectedSize.id (mesmo que faz o backend)
                final priceFromSize =
                    flavorItem.getPriceForSize(selectedSize!.id) ??
                    flavorItem.getPriceForSize(selectedSize!.linkedProductId);

                final int fullPrice;
                if (priceFromSize != null && priceFromSize > 0) {
                  // Tem pricesBySize → preço cheio disponível diretamente
                  fullPrice = priceFromSize;
                } else {
                  // Sem pricesBySize (cenário createFlavorGroups/Product IDs):
                  // flavorItem.price é FRACIONADO (dividido por maxFlavors)
                  // Reconstrói o preço cheio multiplicando pelo número de slots
                  fullPrice = flavorItem.price * flavorGroups.length;
                }
                if (fullPrice > 0) fullPrices.add(fullPrice);
              } else {
                // Fallback: item não encontrado no grupo, usa price do CartVariantOption
                // mas como estava fracionado, multiplica pelo número de sabores do grupo
                final maxFlavors = flavorGroups.length;
                final approximateFullPrice = option.price * maxFlavors;
                if (approximateFullPrice > 0)
                  fullPrices.add(approximateFullPrice);
              }
            }
          }
        }

        if (fullPrices.isNotEmpty) {
          // ✅ ESTRATÉGIA DE PREÇO sobre PREÇOS CHEIOS (idêntico ao backend)
          final int combinedPrice;
          if (pizzaPricingStrategy == PizzaPricingStrategy.average) {
            // AVERAGE: média aritmética dos preços cheios
            combinedPrice =
                fullPrices.fold(0, (sum, p) => sum + p) ~/ fullPrices.length;
          } else {
            // HIGHEST: maior preço cheio (sem multiplicar — já é o valor total)
            combinedPrice = fullPrices.reduce((a, b) => a > b ? a : b);
          }

          print(
            '🍕 [CartProduct] basePrice ($pizzaPricingStrategy) — preços CHEIOS:',
          );
          print(
            '   - Sabores: ${fullPrices.map((p) => (p / 100).toStringAsFixed(2)).join(", ")}',
          );
          print(
            '   - basePrice: R\$ ${(combinedPrice / 100).toStringAsFixed(2)}',
          );

          return combinedPrice;
        }
        return 0;
      }

      // ✅ Fallback para TOPPING groups (caso a adaptação não tenha sido feita)
      final toppingGroups =
          category.optionGroups
              .where((g) => g.groupType == OptionGroupType.topping)
              .toList();

      if (toppingGroups.isNotEmpty) {
        final List<int> fullPrices = [];

        for (final toppingGroup in toppingGroups) {
          final flavorVariant = selectedVariants.firstWhereOrNull(
            (v) => v.id == toppingGroup.id,
          );

          if (flavorVariant != null) {
            for (final option in flavorVariant.cartOptions.where(
              (o) => o.quantity > 0,
            )) {
              final toppingItem = toppingGroup.items.firstWhereOrNull(
                (item) => item.id == option.id,
              );
              if (toppingItem != null && selectedSize?.id != null) {
                final fullPrice =
                    toppingItem.getPriceForSize(selectedSize!.id) ??
                    option.price;
                if (fullPrice > 0) fullPrices.add(fullPrice);
              } else if (option.price > 0) {
                fullPrices.add(option.price);
              }
            }
          }
        }

        if (fullPrices.isNotEmpty) {
          final int combinedPrice;
          if (pizzaPricingStrategy == PizzaPricingStrategy.average) {
            combinedPrice =
                fullPrices.fold(0, (sum, p) => sum + p) ~/ fullPrices.length;
          } else {
            combinedPrice = fullPrices.reduce((a, b) => a > b ? a : b);
          }
          print(
            '🍕 [CartProduct] basePrice fallback TOPPING ($pizzaPricingStrategy): R\$ ${(combinedPrice / 100).toStringAsFixed(2)}',
          );
          return combinedPrice;
        }
        return 0;
      }

      // ✅ Se nenhum sabor selecionado ainda, exibe startingPrice para não mostrar R$0,00
      return startingPrice;
    }

    // Para itens normais, o preço vem do vínculo com a categoria.
    final link = product.categoryLinks.firstWhereOrNull(
      (l) => l.categoryId == category.id,
    );
    if (link != null) {
      return link.isOnPromotion && link.promotionalPrice != null
          ? link.promotionalPrice!
          : link.price;
    }
    return 0;
  }

  // Preço total dos complementos selecionados
  int get variantsPrice {
    if (category.isCustomizable) {
      // ✅ NOVO: Para pizzas: soma apenas bordas (EDGE), massas (CRUST) e outros extras (NÃO sabores TOPPING)
      // Sabores já são calculados no basePrice usando a regra do maior preço

      // ✅ CORREÇÃO: Exclui TOPPING e FLAVOR (sabores) do variantsPrice
      // Os sabores (TOPPING) dos grupos originais e FLAVOR dos grupos adaptados
      // já são contabilizados no basePrice — não devem entrar no variantsPrice.
      final excludedGroupIds =
          category.optionGroups
              .where(
                (g) =>
                    g.groupType == OptionGroupType.topping ||
                    g.groupType == OptionGroupType.flavor,
              )
              .map((g) => g.id)
              .toSet();

      return selectedVariants
          .where((v) {
            // Exclui grupos de sabor (TOPPING e FLAVOR)
            if (excludedGroupIds.contains(v.id)) return false;
            // Exclui grupos com nome "sabor" (estrutura legada)
            if (v.name.toLowerCase().contains('sabor')) return false;
            return true;
          })
          .fold(0, (total, variant) => total + variant.totalPrice);
    }
    return selectedVariants.fold(
      0,
      (total, variant) => total + variant.totalPrice,
    );
  }

  /// ✅ NOVO: Preço "a partir de" para exibição
  /// Para pizzas: usa o preço mínimo do tamanho (unitMinPrice)
  /// Para produtos normais: usa o preço base
  int get startingPrice {
    if (category.isCustomizable && selectedSize != null) {
      // ✅ CORREÇÃO: Para pizzas, usa o preço do tamanho (unitMinPrice)
      // Este é o mesmo valor exibido na home
      if (selectedSize!.price > 0) {
        return selectedSize!.price;
      }

      // Fallback: se não tiver preço no tamanho, busca o menor preço dos sabores
      // Tenta encontrar grupo pelo tipo TOPPING
      var toppingGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.topping,
      );

      // Se não achar por tipo, tenta por nome (fallback legado)
      toppingGroup ??= category.optionGroups.firstWhereOrNull(
        (g) => g.name.toLowerCase().contains('sabor'),
      );

      if (toppingGroup != null) {
        final prices =
            toppingGroup.items
                .where((item) => item.isActive)
                .map((item) => item.getPriceForSize(selectedSize?.id))
                .whereType<int>() // Filtra nulos
                .where((p) => p > 0)
                .toList();

        if (prices.isNotEmpty) {
          return prices.reduce((a, b) => a < b ? a : b);
        }
      }

      // Se ainda for 0 e for pizza, tenta pegar o preço do próprio tamanho novamente
      // (caso selectedSize esteja desatualizado ou não populado corretamente)
      final sizeGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.size,
      );
      final sizeItem = sizeGroup?.items.firstWhereOrNull(
        (i) => i.id == selectedSize!.id,
      );
      if (sizeItem != null && sizeItem.price > 0) {
        return sizeItem.price;
      }
    }

    // ✅ NOVO: Para produtos normais com preço base 0 e complementos obrigatórios
    if (basePrice == 0) {
      final Map<int, int> mandatoryGroups = {};

      for (final variant in selectedVariants.where((v) => v.isRequired)) {
        int? minOptionPrice;
        for (final option in variant.cartOptions.where(
          (o) => o.isActuallyAvailable,
        )) {
          if (option.price > 0) {
            if (minOptionPrice == null || option.price < minOptionPrice) {
              minOptionPrice = option.price;
            }
          }
        }

        if (minOptionPrice != null) {
          mandatoryGroups[variant.id] = minOptionPrice;
        }
      }

      if (mandatoryGroups.isNotEmpty) {
        int minTotalMandatory = 0;
        mandatoryGroups.forEach((id, price) => minTotalMandatory += price);
        return minTotalMandatory;
      }
    }

    return basePrice;
  }

  // Preço unitário (base + complementos)
  int get unitPrice {
    final total = basePrice + variantsPrice;
    if (category.isCustomizable) {
      print('🍕 [CartProduct] Cálculo de unitPrice:');
      print('   - basePrice: R\$ ${(basePrice / 100).toStringAsFixed(2)}');
      print(
        '   - variantsPrice: R\$ ${(variantsPrice / 100).toStringAsFixed(2)}',
      );
      print('   - unitPrice: R\$ ${(total / 100).toStringAsFixed(2)}');
    }
    return total;
  }

  // Preço total (unitário * quantidade efetiva)
  int get totalPrice {
    // ✅ NOVO: Para produtos vendidos por peso/volume, multiplica pela quantidade decimal
    if (product.unit.requiresQuantityInput && weightQuantity != null) {
      return (unitPrice * weightQuantity!).round();
    }
    return unitPrice * quantity;
  }

  // Validação para saber se pode adicionar ao carrinho
  bool get isValid {
    if (category.isCustomizable && selectedSize == null) {
      return false;
    }
    return selectedVariants.every((variant) => variant.isValid);
  }

  CartProduct copyWith({
    Product? product,
    int? quantity,
    double? weightQuantity, // ✅ NOVO: Quantidade decimal para kg/litros
    String? note,
    OptionItem? selectedSize,
    List<Product>? selectedFlavors,
    List<CartVariant>? selectedVariants,
    PizzaPricingStrategy? pizzaPricingStrategy,
  }) {
    return CartProduct(
      product: product ?? this.product,
      category: category,
      quantity: quantity ?? this.quantity,
      weightQuantity: weightQuantity ?? this.weightQuantity, // ✅ NOVO
      note: note ?? this.note,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedFlavors: selectedFlavors ?? this.selectedFlavors,
      selectedVariants: selectedVariants ?? this.selectedVariants,
      pizzaPricingStrategy:
          pizzaPricingStrategy ??
          this.pizzaPricingStrategy, // Mantém a estratégia
    );
  }

  @override
  List<Object?> get props => [
    product.id,
    category.id,
    quantity,
    note,
    selectedSize,
    selectedFlavors,
    selectedVariants,
    pizzaPricingStrategy,
  ];
}
