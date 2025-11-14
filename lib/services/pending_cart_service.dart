// ✅ Serviço para salvar payload pendente de adicionar ao carrinho após login
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/update_cart_payload.dart';
import '../models/cart_item.dart';

class PendingCartService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  static const String _pendingCartKey = 'pending_cart_item';

  /// Salva o payload pendente para adicionar ao carrinho após login
  static Future<void> savePendingCartItem(UpdateCartItemPayload payload) async {
    try {
      final json = payload.toJson();
      await _storage.write(key: _pendingCartKey, value: jsonEncode(json));
      print('✅ Payload pendente salvo: ${payload.productId}');
    } catch (e) {
      print('❌ Erro ao salvar payload pendente: $e');
    }
  }

  /// Recupera o payload pendente
  static Future<UpdateCartItemPayload?> getPendingCartItem() async {
    try {
      final jsonString = await _storage.read(key: _pendingCartKey);
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      // ✅ Converte variants usando CartItemVariant.fromJson
      List<CartItemVariant>? variantsList;
      if (json['variants'] != null) {
        variantsList = (json['variants'] as List)
            .map((v) => CartItemVariant.fromJson(v as Map<String, dynamic>))
            .toList();
      }
      
      return UpdateCartItemPayload(
        cartItemId: json['cart_item_id'] as int?,
        productId: json['product_id'] as int,
        categoryId: json['category_id'] as int,
        quantity: json['quantity'] as int,
        note: json['note'] as String?,
        sizeName: json['size_name'] as String?,
        variants: variantsList,
      );
    } catch (e) {
      print('❌ Erro ao recuperar payload pendente: $e');
      return null;
    }
  }

  /// Limpa o payload pendente após adicionar ao carrinho
  static Future<void> clearPendingCartItem() async {
    try {
      await _storage.delete(key: _pendingCartKey);
      print('✅ Payload pendente removido');
    } catch (e) {
      print('❌ Erro ao limpar payload pendente: $e');
    }
  }
}

