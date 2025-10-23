import 'package:totem/models/cart.dart'; // Importe os modelos que acabamos de criar

class UpdateCartItemPayload {
  final int? cartItemId;
  final int productId;
  final int quantity;
  final String? note;
  final List<CartItemVariant>? variants;

  UpdateCartItemPayload({
    this.cartItemId,
    required this.productId,
    required this.quantity,
    this.note,
    this.variants,
  });

  Map<String, dynamic> toJson() {
    return {
      'cart_item_id': cartItemId, // ✅
      'product_id': productId,
      'quantity': quantity,
      'note': note,
      'variants': variants?.map((v) => v.toJson()).toList(),
    };
  }
}