// lib/services/product_recommendation_service.dart

import 'dart:math';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/cart_item.dart';

/// ✅ SERVIÇO PROFISSIONAL DE RECOMENDAÇÕES
/// 
/// Implementa múltiplos algoritmos de recomendação com fallbacks inteligentes
/// Funciona mesmo com poucos produtos na loja
class ProductRecommendationService {
  /// ✅ ALGORITMO PRINCIPAL: Recomenda produtos usando múltiplos critérios
  static List<Product> getRecommendedProducts({
    required List<Product> allProducts,
    required List<Category> allCategories,
    required List<CartItem> itemsInCart,
    int maxItems = 10,
  }) {
    if (allProducts.isEmpty) return [];

    final productIdsInCart = itemsInCart.map((item) => item.product.id).toSet();
    
    // ✅ Filtra produtos elegíveis (não estão no carrinho, têm imagem, estão ativos)
    // ✅ CORREÇÃO: Filtra produtos arquivados e produtos que são apenas linked_products (sabores de pizza)
    final eligibleProducts = allProducts.where((p) {
      // Verifica se é um produto válido
      if (p.id == null) return false;
      
      // Não está no carrinho
      if (productIdsInCart.contains(p.id)) return false;
      
      // Tem imagem
      if (p.imageUrl?.isEmpty ?? true) return false;
      
      // Está ativo (não arquivado, não pausado)
      if (p.status.name != 'ACTIVE') return false;
      
      // ✅ CORREÇÃO: Filtra produtos que são apenas linked_products (sabores de pizza)
      // Um produto deve ter categoryLinks para aparecer como recomendação
      // Se não tem categoryLinks, é provavelmente apenas um sabor de pizza
      if (p.categoryLinks.isEmpty) return false;
      
      return true;
    }).toList();

    if (eligibleProducts.isEmpty) return [];

    // ✅ ESTRATÉGIA 1: Produtos da mesma categoria do carrinho (mais relevante)
    final recommendations = _recommendByCategory(
      eligibleProducts: eligibleProducts,
      itemsInCart: itemsInCart,
      allCategories: allCategories,
    );

    // ✅ ESTRATÉGIA 2: Se não tem produtos suficientes, adiciona produtos em destaque
    if (recommendations.length < maxItems) {
      final featured = _recommendByFeatured(
        eligibleProducts: eligibleProducts,
        currentRecommendations: recommendations,
        needed: maxItems - recommendations.length,
      );
      recommendations.addAll(featured);
    }

    // ✅ ESTRATÉGIA 3: Se ainda não tem produtos suficientes, adiciona produtos mais vendidos
    if (recommendations.length < maxItems) {
      final bestSellers = _recommendByBestSellers(
        eligibleProducts: eligibleProducts,
        currentRecommendations: recommendations,
        needed: maxItems - recommendations.length,
      );
      recommendations.addAll(bestSellers);
    }

    // ✅ ESTRATÉGIA 4: Se ainda não tem produtos suficientes, adiciona produtos por preço similar
    if (recommendations.length < maxItems && itemsInCart.isNotEmpty) {
      final similarPrice = _recommendBySimilarPrice(
        eligibleProducts: eligibleProducts,
        itemsInCart: itemsInCart,
        currentRecommendations: recommendations,
        needed: maxItems - recommendations.length,
      );
      recommendations.addAll(similarPrice);
    }

    // ✅ ESTRATÉGIA 5: Se ainda não tem produtos suficientes, completa com produtos aleatórios
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

  /// ✅ ESTRATÉGIA 1: Recomenda produtos da mesma categoria dos itens no carrinho
  static List<Product> _recommendByCategory({
    required List<Product> eligibleProducts,
    required List<CartItem> itemsInCart,
    required List<Category> allCategories,
  }) {
    if (itemsInCart.isEmpty) return [];

    // Pega todas as categorias dos produtos no carrinho
    final categoriesInCart = itemsInCart
        .expand((item) => item.product.categoryLinks.map((link) => link.categoryId))
        .toSet();

    if (categoriesInCart.isEmpty) return [];

    // Encontra produtos das mesmas categorias
    final sameCategoryProducts = eligibleProducts.where((p) {
      return p.categoryLinks.any((link) => categoriesInCart.contains(link.categoryId));
    }).toList();

    // Ordena por relevância (produtos em destaque primeiro, depois por ordem de criação)
    sameCategoryProducts.sort((a, b) {
      // Produtos em destaque primeiro
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      return 0;
    });

    return sameCategoryProducts;
  }

  /// ✅ ESTRATÉGIA 2: Recomenda produtos em destaque (featured)
  static List<Product> _recommendByFeatured({
    required List<Product> eligibleProducts,
    required List<Product> currentRecommendations,
    required int needed,
  }) {
    if (needed <= 0) return [];

    final currentIds = currentRecommendations.map((p) => p.id).toSet();
    final featured = eligibleProducts.where((p) {
      return p.featured && !currentIds.contains(p.id);
    }).toList();

    return featured.take(needed).toList();
  }

  /// ✅ ESTRATÉGIA 3: Recomenda produtos mais populares (baseado em rating e featured)
  static List<Product> _recommendByBestSellers({
    required List<Product> eligibleProducts,
    required List<Product> currentRecommendations,
    required int needed,
  }) {
    if (needed <= 0) return [];

    final currentIds = currentRecommendations.map((p) => p.id).toSet();
    final popular = eligibleProducts.where((p) {
      return !currentIds.contains(p.id);
    }).toList();

    // ✅ Ordena por popularidade: produtos em destaque primeiro
    popular.sort((a, b) {
      // 1. Produtos em destaque primeiro
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      
      // 2. Ordena por vendas (soldCount) como fallback
      if (a.soldCount != b.soldCount) return b.soldCount.compareTo(a.soldCount);
      
      return 0; // Mantém ordem original se tudo for igual
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

