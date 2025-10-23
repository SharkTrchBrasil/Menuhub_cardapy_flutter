import 'dart:html' as html;
import 'package:uuid/uuid.dart';
import 'dart:convert';


import 'package:totem/models/cart_product.dart';

class SessionHelper {
  static const _key = 'sessionId';

  static String getOrCreateSessionId() {
    final storage = html.window.localStorage;
    if (!storage.containsKey(_key)) {
      final id = const Uuid().v4();
      storage[_key] = id;
      return id;
    }
    return storage[_key]!;
  }
}



class CartStorage {
  static const _cartKey = 'cart';

  static void saveCart(List<CartProduct> products) {
    final json = products.map((p) => p.toJson()).toList();
    html.window.localStorage[_cartKey] = jsonEncode(json);
  }

  static List<CartProduct> loadCart() {
    final data = html.window.localStorage[_cartKey];
    if (data == null) return [];

    final decoded = jsonDecode(data) as List;
    return decoded.map((item) => CartProduct.fromJson(item)).toList();
  }

  static void clearCart() {
    html.window.localStorage.remove(_cartKey);
  }
}
