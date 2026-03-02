// Script de depuração para testar preços promocionais no totem
// Adicione este código em um widget para depurar

import 'package:totem/models/product.dart';
import 'package:totem/models/product_category_link.dart';

void debugPromotionalPrices(Product product, Category category) {
  print('=== DEBUG PROMOTIONAL PRICES ===');
  print('Produto: ${product.name}');
  print('Categoria: ${category.name}');
  
  // Buscar link da categoria
  final link = product.categoryLinks.firstWhereOrNull(
    (l) => l.categoryId == category.id,
  );
  
  if (link != null) {
    print('\n--- Dados do CategoryLink ---');
    print('price: ${link.price} (${link.price.runtimeType})');
    print('promotionalPrice: ${link.promotionalPrice} (${link.promotionalPrice.runtimeType})');
    print('isOnPromotion: ${link.isOnPromotion} (${link.isOnPromotion.runtimeType})');
    
    // Verificação manual
    final hasPromo = link.isOnPromotion && 
                     link.promotionalPrice != null && 
                     link.promotionalPrice! > 0 && 
                     link.promotionalPrice! < link.price;
    
    print('\n--- Verificação Manual ---');
    print('hasPromo: $hasPromo');
    print('promotionalPrice > 0: ${link.promotionalPrice! > 0}');
    print('promotionalPrice < price: ${link.promotionalPrice! < link.price}');
    
    if (hasPromo) {
      final displayPrice = link.promotionalPrice!;
      final originalPrice = link.price;
      final discount = ((originalPrice - displayPrice) / originalPrice * 100).round();
      
      print('\n--- Cálculo do Desconto ---');
      print('displayPrice: $displayPrice');
      print('originalPrice: $originalPrice');
      print('originalPrice - displayPrice: ${originalPrice - displayPrice}');
      print('(originalPrice - displayPrice) / originalPrice: ${(originalPrice - displayPrice) / originalPrice}');
      print('Multiplicado por 100: ${(originalPrice - displayPrice) / originalPrice * 100}');
      print('Arredondado: $discount%');
      
      print('\n--- Formatação para UI ---');
      print('~~R\$${originalPrice / 100:.2f}~~ R\$${displayPrice / 100:.2f} ($discount% OFF)');
    } else {
      print('\n--- Sem Promoção Válida ---');
      print('Preço normal: R\$${link.price / 100:.2f}');
    }
  } else {
    print('\n--- Nenhum CategoryLink encontrado ---');
    print('Usando preço do produto: R\$${product.price != null ? product.price! / 100 : 0:.2f}');
  }
  
  print('\n=== END DEBUG ===\n');
}

// Exemplo de uso em um widget:
// @override
// Widget build(BuildContext context) {
//   debugPromotionalPrices(product, category);
//   return YourWidget(...);
// }
