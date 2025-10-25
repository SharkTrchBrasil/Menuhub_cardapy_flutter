import 'cart_item.dart';

class UpdateCartItemPayload {
  final int? cartItemId;
  final int productId;
  final int categoryId; // ✅ CAMPO ADICIONADO
  final int quantity;
  final String? note;
  final String? sizeName;
  final List<CartItemVariant>? variants;

  UpdateCartItemPayload({
    this.cartItemId,
    required this.productId,
    required this.categoryId, // ✅ ADICIONADO AO CONSTRUTOR
    required this.quantity,
    this.note,
    this.sizeName,
    this.variants,
  });

  Map<String, dynamic> toJson() {
    return {
      'cart_item_id': cartItemId,
      'product_id': productId,
      'category_id': categoryId, // ✅ ADICIONADO AO JSON
      'quantity': quantity,
      'note': note,
      'size_name': sizeName,
      'variants': variants?.map((v) => v.toJson()).toList(),
    }..removeWhere((key, value) => value == null);
  }
}