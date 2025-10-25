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



