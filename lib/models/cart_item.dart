// lib/models/cart_item.dart

import 'package:totem/models/product.dart';
import 'package:totem/models/cart_variant.dart';
import 'package:totem/models/coupon.dart';

/// Representa um item no carrinho de compras
class CartItem {
  final String id; // ID único do item no carrinho (UUID)
  final Product product;
  final int quantity;
  final String note;
  final Coupon? coupon;
  final List<CartVariant> variants; // Complementos selecionados

  CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    this.note = '',
    this.coupon,
    required this.variants,
  });

  // ✅ FACTORY CONSTRUCTOR VAZIO
  factory CartItem.empty() {
    return CartItem(
      id: '',
      product: Product.empty(),
      quantity: 1,
      note: '',
      coupon: null,
      variants: [],
    );
  }

  // ✅ FACTORY: Criar a partir de um produto
  factory CartItem.fromProduct(Product product, {String? cartItemId}) {
    return CartItem(
      id: cartItemId ?? _generateId(),
      product: product,
      quantity: 1,
      note: '',
      coupon: null,
      variants: [],
    );
  }

  // ✅ FROM JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String? ?? _generateId(),
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int? ?? 1,
      note: json['note'] as String? ?? '',
      coupon: json['coupon'] != null
          ? Coupon.fromJson(json['coupon'] as Map<String, dynamic>)
          : null,
      variants: (json['variants'] as List<dynamic>?)
          ?.map((variantJson) => CartVariant.fromJson(variantJson))
          .toList() ?? [],
    );
  }

  // ✅ TO JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': product.id,
      'product': product.toJson(),
      'quantity': quantity,
      'note': note,
      'coupon_code': coupon?.code,
      'coupon': coupon?.toJson(),
      'variants': variants.map((variant) => variant.toJson()).toList(),
      'subtotal': subtotal,
      'total': total,
    };
  }

  // ✅ COPYWITH
  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    String? note,
    Coupon? coupon,
    List<CartVariant>? variants,
    bool clearCoupon = false, // Flag para remover cupom explicitamente
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      coupon: clearCoupon ? null : (coupon ?? this.coupon),
      variants: variants ?? this.variants,
    );
  }

  // ✅ CÁLCULOS DE PREÇO

  /// Preço base do produto (com promoção se ativa)
  int get basePrice {
    if (product.activatePromotion && product.promotionPrice != null) {
      return product.promotionPrice!;
    }
    return product.basePrice;
  }

  /// Preço total dos complementos selecionados
  int get variantsPrice {
    return variants.fold<int>(
      0,
          (total, variant) => total + variant.totalPrice,
    );
  }

  /// Subtotal do item (produto + complementos) * quantidade
  int get subtotal {
    return (basePrice + variantsPrice) * quantity;
  }

  /// Desconto aplicado pelo cupom (se houver)
  int get discount {
    if (coupon == null) return 0;

    if (coupon!.discountType == 'PERCENTAGE') {
      return (subtotal * coupon!.discountValue / 100).round();
    } else if (coupon!.discountType == 'FIXED') {
      return coupon!.discountValue;
    }

    return 0;
  }

  /// Total final (subtotal - desconto)
  int get total {
    final finalTotal = subtotal - discount;
    return finalTotal < 0 ? 0 : finalTotal;
  }

  // ✅ VALIDAÇÕES

  /// Verifica se todos os complementos obrigatórios foram selecionados
  bool get isValid {
    return variants.every((variant) => variant.isValid);
  }

  /// Lista de mensagens de erro de validação
  List<String> get validationErrors {
    final errors = <String>[];

    for (final variant in variants) {
      if (!variant.isValid) {
        errors.add(variant.validationMessage);
      }
    }

    return errors;
  }

  // ✅ HELPERS

  /// Verifica se dois itens são iguais (mesmo produto e complementos)
  /// Útil para agrupar itens no carrinho
  bool isSameConfiguration(CartItem other) {
    if (product.id != other.product.id) return false;
    if (note.trim().toLowerCase() != other.note.trim().toLowerCase()) return false;
    if (coupon?.code != other.coupon?.code) return false;
    if (variants.length != other.variants.length) return false;

    // Verifica se todos os complementos são iguais
    for (final thisVariant in variants) {
      final otherVariant = other.variants.firstWhere(
            (v) => v.id == thisVariant.id,
        orElse: () => CartVariant.empty(),
      );

      if (otherVariant.id == 0) return false;

      if (!thisVariant.isSameSelection(otherVariant)) {
        return false;
      }
    }

    return true;
  }

  /// Descrição resumida dos complementos selecionados
  String get variantsDescription {
    final selectedOptions = <String>[];

    for (final variant in variants) {
      for (final option in variant.options.where((o) => o.quantity > 0)) {
        if (option.quantity == 1) {
          selectedOptions.add(option.name);
        } else {
          selectedOptions.add('${option.quantity}x ${option.name}');
        }
      }
    }

    return selectedOptions.join(', ');
  }

  // ✅ GERADOR DE ID ÚNICO
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond % 1000).toString();
  }

  @override
  String toString() {
    return 'CartItem(id: $id, product: ${product.name}, quantity: $quantity, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}