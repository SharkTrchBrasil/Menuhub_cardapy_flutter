// lib/models/cart_product.dart

import 'package:equatable/equatable.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/cart_variant.dart';

class CartProduct extends Equatable {
  // PROPRIEDADES DE ORIGEM (IMUTÁVEIS)
  final Product product;
  final Category category;

  // ESTADO DA SELEÇÃO DO USUÁRIO
  final int quantity;
  final String? note;
  final OptionItem? selectedSize;
  final List<Product> selectedFlavors;
  final List<CartVariant> selectedVariants;

  const CartProduct({
    required this.product,
    required this.category,
    this.quantity = 1,
    this.note,
    this.selectedSize,
    this.selectedFlavors = const [],
    this.selectedVariants = const [],
  });

  // Construtor de fábrica para iniciar a configuração de um produto
  factory CartProduct.fromProduct(Product product, Category category) {
    final variants = product.variantLinks
        .map((link) => CartVariant.fromProductVariantLink(link))
        .toList();

    // ✅ INÍCIO DA CORREÇÃO
    // Se o produto for customizável, pré-seleciona o primeiro tamanho como padrão.
    OptionItem? defaultSize;
    if (category.isCustomizable) {
      defaultSize = category.optionGroups
          .firstWhereOrNull((g) => g.groupType == OptionGroupType.size)
          ?.items
          .firstOrNull;
    }
    // ✅ FIM DA CORREÇÃO

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

  // Preço total (unitário * quantidade)
  int get totalPrice {
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
    String? note,
    OptionItem? selectedSize,
    List<Product>? selectedFlavors,
    List<CartVariant>? selectedVariants,
  }) {
    return CartProduct(
      product: product ?? this.product,
      category: category,
      quantity: quantity ?? this.quantity,
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