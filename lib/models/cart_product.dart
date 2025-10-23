// Em: models/cart_product.dart

import 'package:collection/collection.dart';

import 'package:totem/models/cart_variant.dart'; // Nosso CartVariant corrigido
import 'package:totem/models/coupon.dart';
import 'package:totem/models/product.dart';

import '../helpers/enums.dart';
import 'cart_variant_option.dart';

class CartProduct {
  // Composição: O CartProduct "tem um" produto original.
  final Product sourceProduct;

  // Propriedades do Estado do Carrinho
  int quantity;
  String note;
  Coupon? coupon;
  final List<CartVariant> cartVariants;

  CartProduct({
    required this.sourceProduct,
    required this.cartVariants,
    this.quantity = 1,
    this.note = '',
    this.coupon,
  });




  factory CartProduct.fromProduct(Product product, {Coupon? coupon}) {

    // ✅ CORREÇÃO 2: Adicione o tipo explícito "List<CartVariant>" aqui.
    final List<CartVariant> initialCartVariants = product.variantLinks!.map((link) {

      final cartOptions = link.variant.options.map((option) {

        final bool isDefault = product.defaultOptionIds.contains(option.id);

        return CartVariantOption.fromVariantOption(
          option,
          initialQuantity: isDefault ? 1 : 0,
        );
      }).toList();

      // ✅ CORREÇÃO 1: Adicione o parâmetro nomeado "options:" aqui.
      return CartVariant.fromProductVariantLink(link, options: cartOptions);

    }).toList();

    return CartProduct(
      sourceProduct: product,
      cartVariants: initialCartVariants,
      coupon: coupon,
    );
  }


  factory CartProduct.fromJson(Map<String, dynamic> json) {
    // AVISO: Isto reconstrói o ESTADO do carrinho, mas não possui as REGRAS
    // completas (min/max, etc.), pois elas não são salvas no JSON.
    return CartProduct(
      // Cria um 'sourceProduct' com os dados mínimos disponíveis no JSON.
      sourceProduct: Product.fromJson({
        'id': json['product_id'],
        'name': json['name'] ?? 'Produto',
        'base_price': json['price'] ?? 0,
        'image_path': json['image_url'],
        'variant_links': [], // As regras não são salvas, então a lista vem vazia.
        'category': {'id': 0, 'name': ''}, // Placeholder
        'activate_promotion': json['activate_promotion'] ?? false,
        'promotion_price': json['promotion_price'],
        'description': json['description'] ?? '',
        'featured': json['featured'] ?? false,
      }),
      quantity: json['quantity'] ?? 1,
      note: json['note'] ?? '',
      coupon: json['coupon'] != null ? Coupon.fromJson(json['coupon']) : null,
      cartVariants: (json['variants'] as List<dynamic>?)
          ?.map((v) => CartVariant.fromJson(v as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  // --- Getters ---

  int get price => (sourceProduct.activatePromotion && sourceProduct.promotionPrice != null)
      ? sourceProduct.promotionPrice!
      : sourceProduct.basePrice;

  int get totalPrice {
    final variantsTotal = cartVariants.fold<int>(0, (total, variant) {
      final optionsTotal = variant.cartOptions.fold<int>(0, (subTotal, option) {
        return subTotal + (option.price * option.quantity);
      });
      return total + optionsTotal;
    });
    return (price + variantsTotal) * quantity;
  }

  bool hasSameProperties(CartProduct other) {
    if (sourceProduct.id != other.sourceProduct.id) return false;
    if (note.trim().toLowerCase() != other.note.trim().toLowerCase()) return false;
    if (coupon?.code != other.coupon?.code) return false;

    if (cartVariants.length != other.cartVariants.length) return false;

    for (final thisVariant in cartVariants) {
      final otherVariant = other.cartVariants.firstWhereOrNull((v) => v.id == thisVariant.id);
      if (otherVariant == null) return false;

      for (final thisOption in thisVariant.cartOptions) {
        final otherOption = otherVariant.cartOptions.firstWhereOrNull((o) => o.id == thisOption.id);
        if (otherOption == null) return false;
        if (thisOption.quantity != otherOption.quantity) return false;
      }
    }
    return true;
  }



  bool get isValid {
    // O produto é válido se todos os seus grupos de complementos forem válidos.
    return cartVariants.every((variant) => variant.isValid);
  }


  CartProduct copyWith({
    Product? sourceProduct, // ✅ 1. ADICIONE O PARÂMETRO AQUI
    int? quantity,
    String? note,
    Coupon? coupon,
    List<CartVariant>? cartVariants,
  }) {
    return CartProduct(
      sourceProduct: sourceProduct ?? this.sourceProduct, // ✅ 2. USE O NOVO PARÂMETRO AQUI
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      // Se você quer que o cupom possa ser explicitamente removido, use `ValueGetter`
      // Para simplificar, vamos manter assim por enquanto.
      coupon: coupon ?? this.coupon,
      cartVariants: cartVariants ?? this.cartVariants,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': sourceProduct.id,
      'name': sourceProduct.name,
      'price': price,
      'image_url': sourceProduct.coverImageUrl,
      'quantity': quantity,
      'note': note,
      'coupon_code': coupon?.code,
      'variants': cartVariants
          .map((variant) {
        final selectedOptions = variant.cartOptions.where((option) => option.quantity > 0).toList();
        if (selectedOptions.isEmpty) return null;
        return variant.toJson();
      })
          .whereNotNull()
          .toList(),
    };
  }

  /// ✅ MÉTODO toProduct: Converte de volta para um modelo Product (se necessário).
  Product toProduct() {
    // Note que esta conversão perde as regras (variantLinks), pois o CartProduct
    // foca no estado da seleção, não nas regras originais.
    return Product(
      id: sourceProduct.id,
      name: sourceProduct.name,
      description: sourceProduct.description,
      basePrice: sourceProduct.basePrice,
      category: sourceProduct.category,
      promotionPrice: sourceProduct.promotionPrice,
      featured: sourceProduct.featured,
      activatePromotion: sourceProduct.activatePromotion,
      variantLinks: sourceProduct.variantLinks,
      productType: sourceProduct.productType,
      components: sourceProduct.components,
      defaultOptionIds: sourceProduct.defaultOptionIds,
      cashbackType: sourceProduct.cashbackType,
      cashbackValue: sourceProduct.cashbackValue,
      status: ProductStatus.active, images: [], galleryImages: [], categoryLinks: [], prices: [], // As regras não são mantidas no estado do carrinho.
    );
  }
}