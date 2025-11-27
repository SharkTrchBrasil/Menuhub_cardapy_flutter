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
      
      // ✅ Encontra os grupos de sabores
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
      
      // ✅ Se ainda não selecionou todos os sabores, retorna 0 (igual iFood)
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
      // ✅ Para pizzas: soma apenas bordas, massas e outros extras (NÃO sabores)
      // Sabores já são calculados no basePrice usando a regra do maior preço
      return selectedVariants
          .where((v) => !v.name.toLowerCase().contains('sabor'))
          .fold(0, (total, variant) => total + variant.totalPrice);
    }
    return selectedVariants.fold(0, (total, variant) => total + variant.totalPrice);
  }

  /// ✅ NOVO: Preço "a partir de" para exibição (menor preço dos sabores)
  /// Usado no cabeçalho do dialog de pizza antes de selecionar os sabores
  int get startingPrice {
    if (!category.isCustomizable) return basePrice;
    
    // Pega o menor preço dos sabores disponíveis
    final flavorPrices = selectedVariants
        .where((v) => v.name.toLowerCase().contains('sabor'))
        .expand((v) => v.cartOptions)
        .map((o) => o.price)
        .where((p) => p > 0)
        .toList();
    
    if (flavorPrices.isNotEmpty) {
      return flavorPrices.reduce((a, b) => a < b ? a : b);
    }
    return 0;
  }

  // Preço unitário (base + complementos)
  int get unitPrice {
    return basePrice + variantsPrice;
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