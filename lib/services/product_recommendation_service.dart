// lib/services/product_recommendation_service.dart

import 'dart:math';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/cart_item.dart';

/// ✅ SERVIÇO PROFISSIONAL DE RECOMENDAÇÕES
/// 
/// Implementa múltiplos algoritmos de recomendação com fallbacks inteligentes
/// Funciona mesmo com poucos produtos na loja
/// 
/// ✅ ALINHADO COM iFOOD: Recomenda produtos variados, não apenas da mesma categoria
class ProductRecommendationService {
  /// ✅ ALGORITMO PRINCIPAL: Recomenda produtos usando múltiplos critérios
  /// 
  /// Prioridade das recomendações (igual Menuhub):
  /// 1. Produtos em PROMOÇÃO (com desconto) - mais visíveis
  /// 2. Produtos de categorias COMPLEMENTARES (sobremesas, bebidas)
  /// 3. Produtos POPULARES/em destaque
  /// 4. Produtos com PREÇO SIMILAR
  /// 5. Produtos ALEATÓRIOS (variedade)
  static List<Product> getRecommendedProducts({
    required List<Product> allProducts,
    required List<Category> allCategories,
    required List<CartItem> itemsInCart,
    int maxItems = 10,
  }) {
    if (allProducts.isEmpty) return [];

    final productIdsInCart = itemsInCart.map((item) => item.product.id).toSet();
    
    // ✅ Filtra produtos elegíveis (não estão no carrinho, têm imagem, estão ativos)
    final eligibleProducts = allProducts.where((p) {
      if (p.id == null) return false;
      if (productIdsInCart.contains(p.id)) return false;
      if (p.imageUrl?.isEmpty ?? true) return false;
      if (p.status.name != 'ACTIVE') return false;
      if (p.categoryLinks.isEmpty) return false;
      return true;
    }).toList();

    if (eligibleProducts.isEmpty) return [];

    final recommendations = <Product>[];

    // ✅ ESTRATÉGIA 1: Produtos em PROMOÇÃO (mais atrativo - igual Menuhub)
    final promoProducts = _recommendByPromotion(
      eligibleProducts: eligibleProducts,
      currentRecommendations: recommendations,
      needed: (maxItems * 0.4).ceil(), // 40% das recomendações podem ser promoções
    );
    recommendations.addAll(promoProducts);

    // ✅ ESTRATÉGIA 2: Produtos de CATEGORIAS COMPLEMENTARES (sobremesas, bebidas, etc)
    if (recommendations.length < maxItems) {
      final complementary = _recommendByComplementaryCategories(
        eligibleProducts: eligibleProducts,
        itemsInCart: itemsInCart,
        allCategories: allCategories,
        currentRecommendations: recommendations,
        needed: (maxItems * 0.3).ceil(), // 30% de categorias complementares
      );
      recommendations.addAll(complementary);
    }

    // ✅ ESTRATÉGIA 3: Produtos POPULARES e em destaque
    if (recommendations.length < maxItems) {
      final popular = _recommendByPopularAndFeatured(
        eligibleProducts: eligibleProducts,
        currentRecommendations: recommendations,
        needed: maxItems - recommendations.length,
      );
      recommendations.addAll(popular);
    }

    // ✅ ESTRATÉGIA 4: Produtos com PREÇO SIMILAR aos do carrinho
    if (recommendations.length < maxItems && itemsInCart.isNotEmpty) {
      final similarPrice = _recommendBySimilarPrice(
        eligibleProducts: eligibleProducts,
        itemsInCart: itemsInCart,
        currentRecommendations: recommendations,
        needed: maxItems - recommendations.length,
      );
      recommendations.addAll(similarPrice);
    }

    // ✅ ESTRATÉGIA 5: Produtos ALEATÓRIOS (última opção - garante variedade)
    if (recommendations.length < maxItems) {
      final random = _recommendByRandom(
        eligibleProducts: eligibleProducts,
        currentRecommendations: recommendations,
        needed: maxItems - recommendations.length,
      );
      recommendations.addAll(random);
    }

    // ✅ Retorna limitado ao máximo solicitado e embaralhado para variedade
    final shuffled = List<Product>.from(recommendations)..shuffle(Random());
    return shuffled.take(maxItems).toList();
  }

  /// ✅ ESTRATÉGIA 1: Recomenda produtos em PROMOÇÃO (igual Menuhub destaca descontos)
  static List<Product> _recommendByPromotion({
    required List<Product> eligibleProducts,
    required List<Product> currentRecommendations,
    required int needed,
  }) {
    if (needed <= 0) return [];

    final currentIds = currentRecommendations.map((p) => p.id).toSet();
    
    // Encontra produtos com promoção ativa
    final promoProducts = eligibleProducts.where((p) {
      if (currentIds.contains(p.id)) return false;
      
      // Verifica se tem promoção em algum categoryLink
      return p.categoryLinks.any((link) => 
        link.isOnPromotion && 
        link.promotionalPrice != null && 
        link.promotionalPrice! < link.price
      );
    }).toList();

    // Ordena por maior desconto percentual
    promoProducts.sort((a, b) {
      final aDiscount = _getMaxDiscountPercent(a);
      final bDiscount = _getMaxDiscountPercent(b);
      return bDiscount.compareTo(aDiscount); // Maior desconto primeiro
    });

    return promoProducts.take(needed).toList();
  }

  /// Calcula o maior desconto percentual de um produto
  static int _getMaxDiscountPercent(Product product) {
    int maxDiscount = 0;
    for (final link in product.categoryLinks) {
      if (link.isOnPromotion && link.promotionalPrice != null && link.price > 0) {
        final discount = ((link.price - link.promotionalPrice!) * 100) ~/ link.price;
        if (discount > maxDiscount) maxDiscount = discount;
      }
    }
    return maxDiscount;
  }

  /// ✅ ESTRATÉGIA 2: Recomenda produtos de CATEGORIAS COMPLEMENTARES
  /// Ex: Se tem prato principal no carrinho, recomenda sobremesas, bebidas, acompanhamentos
  static List<Product> _recommendByComplementaryCategories({
    required List<Product> eligibleProducts,
    required List<CartItem> itemsInCart,
    required List<Category> allCategories,
    required List<Product> currentRecommendations,
    required int needed,
  }) {
    if (needed <= 0) return [];

    final currentIds = currentRecommendations.map((p) => p.id).toSet();
    
    // Pega categorias dos itens no carrinho
    final categoriesInCart = itemsInCart
        .expand((item) => item.product.categoryLinks.map((link) => link.categoryId))
        .toSet();

    // Encontra produtos de OUTRAS categorias (complementares)
    final complementaryProducts = eligibleProducts.where((p) {
      if (currentIds.contains(p.id)) return false;
      
      // Deve ser de uma categoria DIFERENTE das que estão no carrinho
      final productCategories = p.categoryLinks.map((link) => link.categoryId).toSet();
      final isFromDifferentCategory = productCategories.intersection(categoriesInCart).isEmpty;
      
      return isFromDifferentCategory;
    }).toList();

    // Ordena: produtos em destaque primeiro, depois por vendas
    complementaryProducts.sort((a, b) {
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      return b.soldCount.compareTo(a.soldCount);
    });

    return complementaryProducts.take(needed).toList();
  }

  /// ✅ ESTRATÉGIA 3: Recomenda produtos POPULARES e em destaque
  static List<Product> _recommendByPopularAndFeatured({
    required List<Product> eligibleProducts,
    required List<Product> currentRecommendations,
    required int needed,
  }) {
    if (needed <= 0) return [];

    final currentIds = currentRecommendations.map((p) => p.id).toSet();
    final popular = eligibleProducts.where((p) => !currentIds.contains(p.id)).toList();

    // Ordena por popularidade
    popular.sort((a, b) {
      // 1. Produtos em destaque primeiro
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      // 2. Produtos com mais vendas
      if (a.soldCount != b.soldCount) return b.soldCount.compareTo(a.soldCount);
      return 0;
    });

    return popular.take(needed).toList();
  }

  /// ✅ ESTRATÉGIA 4: Recomenda produtos com preço similar aos do carrinho
  static List<Product> _recommendBySimilarPrice({
    required List<Product> eligibleProducts,
    required List<CartItem> itemsInCart,
    required List<Product> currentRecommendations,
    required int needed,
  }) {
    if (needed <= 0 || itemsInCart.isEmpty) return [];

    // Calcula o preço médio dos itens no carrinho
    int totalPrice = 0;
    int itemCount = 0;
    for (final item in itemsInCart) {
      final price = item.unitPrice;
      totalPrice += price * item.quantity;
      itemCount += item.quantity;
    }

    if (itemCount == 0) return [];

    final averagePrice = totalPrice ~/ itemCount;
    final priceRange = (averagePrice * 0.5).round(); // ±50% do preço médio

    final currentIds = currentRecommendations.map((p) => p.id).toSet();
    final similarPriceProducts = eligibleProducts.where((p) {
      if (currentIds.contains(p.id)) return false;

      // Calcula o menor preço do produto
      int? minProductPrice;
      if (p.prices.isNotEmpty) {
        minProductPrice = p.prices.map((price) => price.price).reduce((a, b) => a < b ? a : b);
      } else if (p.categoryLinks.isNotEmpty) {
        minProductPrice = p.categoryLinks.map((link) {
          return link.isOnPromotion && link.promotionalPrice != null
              ? link.promotionalPrice!
              : link.price;
        }).reduce((a, b) => a < b ? a : b);
      }

      if (minProductPrice == null) return false;

      // Verifica se está dentro da faixa de preço similar
      return (minProductPrice - averagePrice).abs() <= priceRange;
    }).toList();

    // Ordena por proximidade do preço médio
    similarPriceProducts.sort((a, b) {
      int? aPrice;
      int? bPrice;

      if (a.prices.isNotEmpty) {
        aPrice = a.prices.map((price) => price.price).reduce((a, b) => a < b ? a : b);
      } else if (a.categoryLinks.isNotEmpty) {
        aPrice = a.categoryLinks.map((link) {
          return link.isOnPromotion && link.promotionalPrice != null
              ? link.promotionalPrice!
              : link.price;
        }).reduce((a, b) => a < b ? a : b);
      }

      if (b.prices.isNotEmpty) {
        bPrice = b.prices.map((price) => price.price).reduce((a, b) => a < b ? a : b);
      } else if (b.categoryLinks.isNotEmpty) {
        bPrice = b.categoryLinks.map((link) {
          return link.isOnPromotion && link.promotionalPrice != null
              ? link.promotionalPrice!
              : link.price;
        }).reduce((a, b) => a < b ? a : b);
      }

      if (aPrice == null || bPrice == null) return 0;

      final aDiff = (aPrice - averagePrice).abs();
      final bDiff = (bPrice - averagePrice).abs();
      return aDiff.compareTo(bDiff);
    });

    return similarPriceProducts.take(needed).toList();
  }

  /// ✅ ESTRATÉGIA 5: Completa com produtos aleatórios (último fallback)
  static List<Product> _recommendByRandom({
    required List<Product> eligibleProducts,
    required List<Product> currentRecommendations,
    required int needed,
  }) {
    if (needed <= 0) return [];

    final currentIds = currentRecommendations.map((p) => p.id).toSet();
    final available = eligibleProducts.where((p) => !currentIds.contains(p.id)).toList();

    // Embaralha e pega os necessários
    final shuffled = List<Product>.from(available)..shuffle(Random());
    return shuffled.take(needed).toList();
  }
}

