// Em: lib/models/cart.dart

import 'package:equatable/equatable.dart';
import 'cart_item.dart';

class Cart extends Equatable {
  final int id;
  final String status;
  final String? couponCode;
  final String? observation;
  final List<CartItem> items;

  // Campos calculados pelo backend
  final int subtotal;
  final int discount;  // Desconto no pedido (de cupom/voucher)
  final int total;
  
  // ✅ NOVO: Campos de promoções
  final int deliveryFee;  // Taxa de entrega original
  final int deliveryDiscount;  // Desconto no frete (de promo DELIVERY)
  final int finalDeliveryFee;  // Frete final após desconto
  final String? promotionMessage;  // Ex: "🎉 Frete grátis!"
  
  // ✅ NOVO: Indica quando cupom FREE_DELIVERY foi aplicado (frete grátis no checkout)
  final bool isFreeDelivery;

  const Cart({
    required this.id,
    required this.status,
    this.couponCode,
    this.observation,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.deliveryFee = 0,
    this.deliveryDiscount = 0,
    this.finalDeliveryFee = 0,
    this.promotionMessage,
    this.isFreeDelivery = false,
  });

  // Um construtor 'vazio' é útil para o estado inicial
  const Cart.empty()
      : id = 0,
        status = 'empty',
        couponCode = null,
        observation = null,
        items = const [],
        subtotal = 0,
        discount = 0,
        total = 0,
        deliveryFee = 0,
        deliveryDiscount = 0,
        finalDeliveryFee = 0,
        promotionMessage = null,
        isFreeDelivery = false;

  bool get isEmpty => id == 0 || items.isEmpty;
  
  /// Verifica se tem frete grátis
  bool get hasFreeDelivery => deliveryFee > 0 && finalDeliveryFee == 0;
  
  /// Verifica se tem algum desconto aplicado
  bool get hasDiscount => discount > 0 || deliveryDiscount > 0;
  
  /// Total final incluindo frete
  int get grandTotal => total + finalDeliveryFee;

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'],
      status: json['status'],
      couponCode: json['coupon_code'],
      observation: json['observation'],
      items: (json['items'] as List)
          .map((itemJson) => CartItem.fromJson(itemJson))
          .toList(),
      subtotal: json['subtotal'] ?? 0,
      discount: json['discount'] ?? 0,
      total: json['total'] ?? 0,
      deliveryFee: json['delivery_fee'] ?? 0,
      deliveryDiscount: json['delivery_discount'] ?? 0,
      finalDeliveryFee: json['final_delivery_fee'] ?? 0,
      promotionMessage: json['promotion_message'],
      isFreeDelivery: json['is_free_delivery'] ?? false,
    );
  }

  Cart copyWith({
    int? id,
    String? status,
    String? couponCode,
    String? observation,
    List<CartItem>? items,
    int? subtotal,
    int? discount,
    int? total,
    int? deliveryFee,
    int? deliveryDiscount,
    int? finalDeliveryFee,
    String? promotionMessage,
    bool? isFreeDelivery,
  }) {
    return Cart(
      id: id ?? this.id,
      status: status ?? this.status,
      couponCode: couponCode ?? this.couponCode,
      observation: observation ?? this.observation,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryDiscount: deliveryDiscount ?? this.deliveryDiscount,
      finalDeliveryFee: finalDeliveryFee ?? this.finalDeliveryFee,
      promotionMessage: promotionMessage ?? this.promotionMessage,
      isFreeDelivery: isFreeDelivery ?? this.isFreeDelivery,
    );
  }

  @override
  List<Object?> get props => [
    id, status, couponCode, observation, items, 
    subtotal, discount, total,
    deliveryFee, deliveryDiscount, finalDeliveryFee, promotionMessage,
    isFreeDelivery,
  ];
}


/// ✅ NOVO: Resposta granular para atualização de item (economiza banda)
class CartGranularResponse extends Equatable {
  final String action;  // "added", "updated", "removed", "quantity_changed"
  final CartItem? item;  // Null quando ação é "removed"
  final int? removedItemId;  // Preenchido quando ação é "removed"
  
  // Totais atualizados do carrinho
  final int cartId;
  final int cartSubtotal;
  final int cartDiscount;
  final int cartTotal;
  final int cartItemsCount;

  const CartGranularResponse({
    required this.action,
    this.item,
    this.removedItemId,
    required this.cartId,
    required this.cartSubtotal,
    required this.cartDiscount,
    required this.cartTotal,
    required this.cartItemsCount,
  });

  factory CartGranularResponse.fromJson(Map<String, dynamic> json) {
    return CartGranularResponse(
      action: json['action'] ?? 'unknown',
      item: json['item'] != null ? CartItem.fromJson(json['item']) : null,
      removedItemId: json['removed_item_id'],
      cartId: json['cart_id'] ?? 0,
      cartSubtotal: json['cart_subtotal'] ?? 0,
      cartDiscount: json['cart_discount'] ?? 0,
      cartTotal: json['cart_total'] ?? 0,
      cartItemsCount: json['cart_items_count'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    action, item, removedItemId, 
    cartId, cartSubtotal, cartDiscount, cartTotal, cartItemsCount
  ];
}

/// ✅ Exceção usada quando backend não suporta modo granular (fallback)
class CartGranularFallbackException implements Exception {
  final Cart cart;
  CartGranularFallbackException(this.cart);
  
  @override
  String toString() => 'CartGranularFallbackException: Backend retornou carrinho completo';
}