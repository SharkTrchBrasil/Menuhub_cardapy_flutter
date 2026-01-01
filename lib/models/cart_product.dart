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

class CartProduct extends Equatable {
  // PROPRIEDADES DE ORIGEM (IMUTÁVEIS)
  final Product product;
  final Category category;

  // ESTADO DA SELEÇÃO DO USUÁRIO
  final int quantity;  // Quantidade inteira (para unidades)
  final double? weightQuantity;  // ✅ NOVO: Quantidade decimal (para kg/litros)
  final String? note;
  final OptionItem? selectedSize;
  final List<Product> selectedFlavors;
  final List<CartVariant> selectedVariants;

  const CartProduct({
    required this.product,
    required this.category,
    this.quantity = 1,
    this.weightQuantity,  // ✅ NOVO: Quantidade decimal para kg/litros
    this.note,
    this.selectedSize,
    this.selectedFlavors = const [],
    this.selectedVariants = const [],
  });
  
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
    // ✅ CORREÇÃO: Para categorias customizáveis (pizzas), converte optionGroups em variants
    List<CartVariant> variants;
    OptionItem? defaultSize;
    
    if (category.isCustomizable) {
      // 1. Pré-seleciona o primeiro tamanho como padrão
      final sizeGroup = category.optionGroups
          .firstWhereOrNull((g) => g.groupType == OptionGroupType.size);
      defaultSize = sizeGroup?.items.firstOrNull;
      
      // 2. Converte grupos em variants, filtrando opções e grupos inativos
      variants = category.optionGroups
          .map((group) {
            // ✅ Filtra apenas opções ativas
            final activeItems = group.items.where((item) => item.isActive).toList();
            
            // ✅ Se não há opções ativas, retorna null (será filtrado depois)
            if (activeItems.isEmpty) return null;
            
            // ✅ Verifica se é grupo obrigatório com apenas 1 opção
            final isRequired = group.minSelection > 0;
            final hasOnlyOneOption = activeItems.length == 1;
            
            final cartOptions = activeItems
                .map((item) {
                  // ✅ Auto-seleciona se grupo obrigatório tem apenas 1 opção
                  final shouldAutoSelect = isRequired && hasOnlyOneOption;
                  
                  return CartVariantOption(
                    id: item.id ?? 0,
                    name: item.name,
                    price: item.price,
                    trackInventory: false,
                    stockQuantity: 0,
                    isActuallyAvailable: true, // Já filtrado acima
                    description: item.description,
                    imageUrl: item.image?.url,
                    // ✅ NOVO: Preserva parentCustomizationOptionId para combinações massa + borda
                    parentCustomizationOptionId: item.parentCustomizationOptionId,
                    // ✅ NOVO: IDs reais de combo Pizza
                    crustId: item.crustId,
                    edgeId: item.edgeId,
                    crustName: item.crustName,
                    edgeName: item.edgeName,
                    crustPrice: item.crustPrice,
                    edgePrice: item.edgePrice,
                    quantity: shouldAutoSelect ? 1 : 0, // ✅ Auto-seleciona
                  );
                })
                .toList();
            
            // Determina UIDisplayMode baseado em min/max selection
            final displayMode = group.maxSelection == 1 
                ? UIDisplayMode.SINGLE  // Radio (Massa, Borda)
                : UIDisplayMode.MULTIPLE; // Checkbox (múltipla escolha)
            
            return CartVariant(
              id: group.id ?? 0,
              name: group.name,
              uiDisplayMode: displayMode,
              minSelectedOptions: group.minSelection,
              maxSelectedOptions: group.maxSelection,
              maxTotalQuantity: null,
              cartOptions: cartOptions,
            );
          })
          .whereType<CartVariant>() // ✅ Remove grupos nulos (sem opções ativas)
          .toList();
    } else {
      // Para produtos normais, usa variantLinks do produto
      variants = product.variantLinks
          .map((link) => CartVariant.fromProductVariantLink(link))
          .toList();
    }

    return CartProduct(
      product: product,
      category: category,
      selectedVariants: variants,
      selectedSize: defaultSize, // Define o tamanho padrão
    );
  }

  // GETTERS PARA CÁLCULO DE PREÇO E VALIDAÇÃO

  // Preço base do item
  int get basePrice {
    // Para customizáveis (pizzas), o preço vem dos sabores selecionados
    if (category.isCustomizable) {
      if (selectedSize == null) return 0;
      
      // ✅ NOVO: Busca TODOS os grupos TOPPING (pode haver múltiplos: SABOR, SABOR2, SABOR3, etc.)
      final toppingGroups = category.optionGroups.where(
        (g) => g.groupType == OptionGroupType.topping,
      ).toList();
      
      if (toppingGroups.isNotEmpty) {
        // ✅ Coleta todos os sabores selecionados de TODOS os grupos TOPPING
        final List<int> selectedFlavorPrices = [];
        
        for (final toppingGroup in toppingGroups) {
          final flavorVariant = selectedVariants.firstWhereOrNull(
            (v) => v.id == toppingGroup.id,
          );
          
          if (flavorVariant != null && flavorVariant.cartOptions.isNotEmpty) {
            // Busca preços dos sabores selecionados usando prices_by_size
            final groupFlavorPrices = flavorVariant.cartOptions
                .where((o) => o.quantity > 0)
                .map((o) {
                  // Busca o OptionItem original para acessar prices_by_size
                  final toppingItem = toppingGroup.items.firstWhereOrNull(
                    (item) => item.id == o.id,
                  );
                  
                  if (toppingItem != null && selectedSize?.id != null) {
                    // Usa prices_by_size se disponível
                    final priceForSize = toppingItem.getPriceForSize(selectedSize!.id);
                    return priceForSize ?? o.price;
                  }
                  return o.price;
                })
                .whereType<int>()
                .where((p) => p > 0)
                .toList();
            
            selectedFlavorPrices.addAll(groupFlavorPrices);
          }
        }
        
        if (selectedFlavorPrices.isNotEmpty) {
          // ✅ CORREÇÃO: Os preços já vêm divididos (ex: R$ 17,50 para 1/2)
          // Para obter o preço cheio, precisamos multiplicar pelo número de sabores
          final numberOfFlavors = selectedFlavorPrices.length;
          
          // ✅ ESTRATÉGIA DE PREÇO: HIGHEST ou AVERAGE
          // Por padrão usa HIGHEST (mais caro) se não tiver acesso à configuração
          // O backend recalcula usando a estratégia configurada na loja
          // Aqui apenas calculamos o preço base para exibição
          final maxFractionalPrice = selectedFlavorPrices.reduce((a, b) => a > b ? a : b);
          
          // ✅ Para HIGHEST: pega o maior preço dividido e multiplica pelo número de sabores
          // Exemplo: 2 sabores de R$ 17,50 cada → R$ 17,50 * 2 = R$ 35,00 (preço cheio)
          final fullPrice = maxFractionalPrice * numberOfFlavors;
          
          print('🍕 [CartProduct] Cálculo de basePrice:');
          print('   - Preços divididos: ${selectedFlavorPrices.map((p) => (p / 100).toStringAsFixed(2)).join(", ")}');
          print('   - Número de sabores: $numberOfFlavors');
          print('   - Maior preço dividido: R\$ ${(maxFractionalPrice / 100).toStringAsFixed(2)}');
          print('   - Preço cheio (basePrice): R\$ ${(fullPrice / 100).toStringAsFixed(2)}');
          
          return fullPrice;
        }
        return 0;
      }
      
      // ⚠️ FALLBACK: Estrutura antiga (busca por nome "sabor")
      final flavorGroups = selectedVariants.where((v) => 
        v.name.toLowerCase().contains('sabor')
      ).toList();
      
      // ✅ Verifica se TODOS os grupos de sabores obrigatórios foram selecionados
      final allFlavorsSelected = flavorGroups.every((g) => g.isValid);
      
      if (flavorGroups.isNotEmpty && allFlavorsSelected) {
        // ✅ REGRA DO MAIS CARO (igual iFood):
        // Pizza com múltiplos sabores cobra o PREÇO CHEIO DO SABOR MAIS CARO
        // 
        // Exemplo: Pizza Grande 4 Sabores
        // - Catupiry: R$ 70,00 (preço cheio) → exibe "+ R$ 17,50" (70/4)
        // - Palmito: R$ 38,50 (preço cheio) → exibe "+ R$ 9,62" (38,50/4)
        // - Calabresa: R$ 48,00 (preço cheio) → exibe "+ R$ 12,00" (48/4)
        // 
        // Total = R$ 70,00 (preço cheio do Catupiry, o mais caro)
        // NÃO soma os fracionados!
        
        final selectedFlavorPrices = flavorGroups
            .expand((g) => g.cartOptions.where((o) => o.quantity > 0))
            .map((o) => o.price)
            .toList();
        
        if (selectedFlavorPrices.isNotEmpty) {
          // ✅ O preço exibido já é fracionado (ex: R$ 17,50 = 70/4)
          // Para obter o preço cheio, multiplicamos pelo número de sabores
          final numberOfFlavors = selectedFlavorPrices.length;
          
          // ✅ Pega o MAIOR preço fracionado e reconstrói o preço cheio
          final maxFractionalPrice = selectedFlavorPrices.reduce((a, b) => a > b ? a : b);
          final fullPriceOfMostExpensive = maxFractionalPrice * numberOfFlavors;
          
          return fullPriceOfMostExpensive;
        }
      }
      
      // ✅ Se ainda não selecionou todos os sabores, retorna 0
      return 0;
    }
    
    // Para itens normais, o preço vem do vínculo com a categoria.
    final link = product.categoryLinks.firstWhereOrNull((l) => l.categoryId == category.id);
    if (link != null) {
      return link.isOnPromotion && link.promotionalPrice != null ? link.promotionalPrice! : link.price;
    }
    return 0;
  }

  // Preço total dos complementos selecionados
  int get variantsPrice {
    if (category.isCustomizable) {
      // ✅ NOVO: Para pizzas: soma apenas bordas (EDGE), massas (CRUST) e outros extras (NÃO sabores TOPPING)
      // Sabores já são calculados no basePrice usando a regra do maior preço
      
      // ✅ CORREÇÃO: Busca TODOS os grupos TOPPING para excluir do cálculo
      final toppingGroupIds = category.optionGroups
          .where((g) => g.groupType == OptionGroupType.topping)
          .map((g) => g.id)
          .toSet();
      
      return selectedVariants
          .where((v) {
            // Exclui TODOS os grupos TOPPING (sabores)
            if (toppingGroupIds.contains(v.id)) {
              return false;
            }
            // Exclui grupos com nome "sabor" (estrutura antiga)
            if (v.name.toLowerCase().contains('sabor')) {
              return false;
            }
            return true;
          })
          .fold(0, (total, variant) => total + variant.totalPrice);
    }
    return selectedVariants.fold(0, (total, variant) => total + variant.totalPrice);
  }

  /// ✅ NOVO: Preço "a partir de" para exibição
  /// Para pizzas: usa o preço mínimo do tamanho (unitMinPrice)
  /// Para produtos normais: usa o preço base
  int get startingPrice {
    if (!category.isCustomizable || selectedSize == null) return basePrice;
    
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
      final prices = toppingGroup.items
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
    if (category.isCustomizable && selectedSize != null) {
        final sizeGroup = category.optionGroups.firstWhereOrNull(
            (g) => g.groupType == OptionGroupType.size
        );
        final sizeItem = sizeGroup?.items.firstWhereOrNull((i) => i.id == selectedSize!.id);
        if (sizeItem != null && sizeItem.price > 0) {
            return sizeItem.price;
        }
    }
    
    return 0;
  }

  // Preço unitário (base + complementos)
  int get unitPrice {
    final total = basePrice + variantsPrice;
    if (category.isCustomizable) {
      print('🍕 [CartProduct] Cálculo de unitPrice:');
      print('   - basePrice: R\$ ${(basePrice / 100).toStringAsFixed(2)}');
      print('   - variantsPrice: R\$ ${(variantsPrice / 100).toStringAsFixed(2)}');
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
    double? weightQuantity,  // ✅ NOVO: Quantidade decimal para kg/litros
    String? note,
    OptionItem? selectedSize,
    List<Product>? selectedFlavors,
    List<CartVariant>? selectedVariants,
  }) {
    return CartProduct(
      product: product ?? this.product,
      category: category,
      quantity: quantity ?? this.quantity,
      weightQuantity: weightQuantity ?? this.weightQuantity,  // ✅ NOVO
      note: note ?? this.note,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedFlavors: selectedFlavors ?? this.selectedFlavors,
      selectedVariants: selectedVariants ?? this.selectedVariants,
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
  ];
}