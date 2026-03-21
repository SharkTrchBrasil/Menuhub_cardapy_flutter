// lib/pages/cart/cart_persistence_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem/models/cart.dart';
import 'package:totem/models/cart_item.dart';
import 'package:totem/models/product.dart';

class CartPersistenceService {
  static const String _cartKey = 'current_cart';
  static const String _lastSyncKey = 'last_sync';

  /// Salva o carrinho localmente
  static Future<void> saveCart(Cart cart) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = {
        'id': cart.id,
        'status': cart.status,
        'couponCode': cart.couponCode,
        'observation': cart.observation,
        'items': cart.items.map((item) => _cartItemToJson(item)).toList(),
        'subtotal': cart.subtotal,
        'discount': cart.discount,
        'total': cart.total,
        'deliveryFee': cart.deliveryFee,
        'deliveryDiscount': cart.deliveryDiscount,
        'finalDeliveryFee': cart.finalDeliveryFee,
        'promotionMessage': cart.promotionMessage,
        'isFreeDelivery': cart.isFreeDelivery,
      };
      await prefs.setString(_cartKey, jsonEncode(cartJson));
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Erro ao salvar carrinho: $e');
    }
  }

  /// Carrega o carrinho salvo localmente
  static Future<Cart?> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJsonString = prefs.getString(_cartKey);
      if (cartJsonString == null) return null;

      final cartJson = jsonDecode(cartJsonString) as Map<String, dynamic>;

      // Reconstrói os itens do carrinho
      final itemsList = cartJson['items'] as List<dynamic>;
      final items =
          itemsList
              .map(
                (itemJson) =>
                    _cartItemFromJson(itemJson as Map<String, dynamic>),
              )
              .toList();

      return Cart(
        id: cartJson['id'] as int,
        status: cartJson['status'] as String,
        couponCode: cartJson['couponCode'] as String?,
        observation: cartJson['observation'] as String?,
        items: items,
        subtotal: cartJson['subtotal'] as int,
        discount: (cartJson['discount'] as int?) ?? 0,
        total: cartJson['total'] as int,
        deliveryFee: (cartJson['deliveryFee'] as int?) ?? 0,
        deliveryDiscount: (cartJson['deliveryDiscount'] as int?) ?? 0,
        finalDeliveryFee: (cartJson['finalDeliveryFee'] as int?) ?? 0,
        promotionMessage: cartJson['promotionMessage'] as String?,
        isFreeDelivery: (cartJson['isFreeDelivery'] as bool?) ?? false,
      );
    } catch (e) {
      print('Erro ao carregar carrinho: $e');
      return null;
    }
  }

  /// Limpa o carrinho salvo
  static Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey);
      await prefs.remove(_lastSyncKey);
    } catch (e) {
      print('Erro ao limpar carrinho: $e');
    }
  }

  /// Verifica se há um carrinho salvo
  static Future<bool> hasSavedCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_cartKey);
    } catch (e) {
      return false;
    }
  }

  static Map<String, dynamic> _cartItemToJson(CartItem item) {
    return {
      'id': item.id,
      'productId': item.product.id,
      'quantity': item.quantity,
      'note': item.note,
      'sizeName': item.sizeName,
      'variants':
          item.variants
              .map(
                (v) => {
                  'variantId': v.variantId,
                  'option_group_id': v.optionGroupId,
                  'group_type': v.groupType,
                  'name': v.name,
                  'options':
                      v.options
                          .map(
                            (o) => {
                              'variant_option_id': o.variantOptionId,
                              'option_item_id': o.optionItemId,
                              'quantity': o.quantity,
                              'name': o.name,
                              'price': o.price,
                            },
                          )
                          .toList(),
                },
              )
              .toList(),
    };
  }

  static CartItem _cartItemFromJson(Map<String, dynamic> json) {
    // Nota: Product será um placeholder simplificado, pois não temos dados completos
    // Em um cenário real, seria necessário buscar os dados completos do servidor
    final productJson = json['product'] as Map<String, dynamic>?;
    final product = Product(
      id: productJson?['id'] as int? ?? json['productId'] as int,
      name: productJson?['name'] as String? ?? 'Produto não disponível',
      description: productJson?['description'] as String? ?? '',
      price: productJson?['price'] as int? ?? 0,
      available: productJson?['available'] as bool? ?? true,
    );

    final variantsList =
        (json['variants'] as List<dynamic>?)
            ?.map(
              (v) => CartItemVariant(
                variantId: v['variantId'] as int? ?? v['variant_id'] as int?,
                optionGroupId: v['option_group_id'] as int?,
                groupType: v['group_type'] as String?,
                name: v['name'] as String? ?? '',
                options:
                    (v['options'] as List<dynamic>)
                        .map(
                          (o) => CartItemVariantOption(
                            variantOptionId:
                                o['variant_option_id'] as int? ??
                                o['variantOptionId'] as int?,
                            optionItemId:
                                o['option_item_id'] as int? ??
                                o['optionItemId'] as int?,
                            quantity: o['quantity'] as int,
                            name: o['name'] as String? ?? '',
                            price: o['price'] as int? ?? 0,
                          ),
                        )
                        .toList(),
              ),
            )
            .toList() ??
        [];

    return CartItem(
      id: json['id'] as int,
      product: product,
      quantity: json['quantity'] as int,
      note: json['note'] as String?,
      variants: variantsList,
      unitPrice: json['unit_price'] as int? ?? 0,
      totalPrice: json['total_price'] as int? ?? 0,
      sizeName: json['size_name'] as String?,
      sizeImageUrl: json['size_image_url'] as String?,
    );
  }
}
