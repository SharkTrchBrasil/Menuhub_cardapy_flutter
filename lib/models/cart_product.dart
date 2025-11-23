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
      
      // 2. Converte TODOS os grupos (incluindo Tamanho) em variants
      // O backend precisa do tamanho como variant para buscar o FlavorPrice
      variants = category.optionGroups
          .map((group) {
            // Converte OptionGroup em CartVariant
            final activeItems = group.items.where((item) => item.isActive).toList();
            final cartOptions = activeItems
                .asMap()
                .entries
                .map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  
                  // ✅ Lógica de pré-seleção:
                  // - Se é grupo de tamanho (SIZE): sempre pré-seleciona o primeiro
                  // - Se é grupo obrigatório (minSelection > 0): pré-seleciona o primeiro
                  final isSizeGroup = group.groupType == OptionGroupType.size;
                  final isRequired = group.minSelection > 0;
                  final initialQuantity = (isSizeGroup || (isRequired && index == 0)) ? 1 : 0;
                  
                  // Converte OptionItem em CartVariantOption
                  return CartVariantOption(
                    id: item.id ?? 0,
                    name: item.name,
                    price: item.price,
                    trackInventory: false,
                    stockQuantity: 0,
                    isActuallyAvailable: item.isActive,
                    description: item.description,
                    imageUrl: item.image?.url,
                    quantity: initialQuantity, // Pré-seleciona tamanho ou obrigatórios
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
    // ✅ CORREÇÃO APLICADA AQUI
    // Para customizáveis, o preço vem do tamanho selecionado.
    if (category.isCustomizable) {
      if (selectedSize == null) return 0; // Segurança: se nenhum tamanho estiver selecionado, o preço é 0.
      // Busca o preço correspondente ao ID do tamanho nos preços do produto.
      final priceEntry = product.prices.firstWhereOrNull((p) => p.sizeOptionId == selectedSize!.id);
      return priceEntry?.price ?? 0;
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
    return selectedVariants.fold(0, (total, variant) => total + variant.totalPrice);
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