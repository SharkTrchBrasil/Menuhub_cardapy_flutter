import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem/models/cart_product.dart';

class CartStorage {
  static const _cartKey = 'cart_items';

  static Future<void> saveCart(List<CartProduct> products) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = products.map((p) => p.toJson()).toList();
    await prefs.setString(_cartKey, jsonEncode(cartJson));
  }

  static Future<List<CartProduct>> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cartKey);
    if (jsonString == null) return [];

    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((item) => CartProduct.fromJson(item)).toList();
  }

  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }
}
