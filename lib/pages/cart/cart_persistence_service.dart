// lib/pages/cart/cart_persistence_service.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:totem/models/cart.dart';
import 'package:totem/models/cart_item.dart';

class CartPersistenceService {
  static const String _boxName = 'cart_storage';
  static const String _cartKey = 'current_cart';
  static const String _lastSyncKey = 'last_sync';

  /// Salva o carrinho localmente
  static Future<void> saveCart(Cart cart) async {
    try {
      final box = await Hive.openBox(_boxName);
      final cartJson = {
        'id': cart.id,
        'status': cart.status,
        'couponCode': cart.couponCode,
        'observation': cart.observation,
        'items': cart.items.map((item) => _cartItemToJson(item)).toList(),
        'subtotal': cart.subtotal,
        'discount': cart.discount,
        'total': cart.total,
      };
      await box.put(_cartKey, jsonEncode(cartJson));
      await box.put(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Erro ao salvar carrinho: $e');
    }
  }

  /// Carrega o carrinho salvo localmente
  static Future<Cart?> loadCart() async {
    try {
      final box = await Hive.openBox(_boxName);
      final cartJsonString = box.get(_cartKey);
      if (cartJsonString == null) return null;

      final cartJson = jsonDecode(cartJsonString) as Map<String, dynamic>;
      
      // Não podemos recriar os produtos completos, então retorna null
      // O carrinho será recriado pelo servidor
      return null;
    } catch (e) {
      print('Erro ao carregar carrinho: $e');
      return null;
    }
  }

  /// Limpa o carrinho salvo
  static Future<void> clearCart() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.delete(_cartKey);
      await box.delete(_lastSyncKey);
    } catch (e) {
      print('Erro ao limpar carrinho: $e');
    }
  }

  /// Verifica se há um carrinho salvo
  static Future<bool> hasSavedCart() async {
    try {
      final box = await Hive.openBox(_boxName);
      return box.get(_cartKey) != null;
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
      'variants': item.variants.map((v) => {
        'variantId': v.variantId,
        'name': v.name,
        'options': v.options.map((o) => {
          'variantOptionId': o.variantOptionId,
          'quantity': o.quantity,
          'name': o.name,
          'price': o.price,
        }).toList(),
      }).toList(),
    };
  }
}

