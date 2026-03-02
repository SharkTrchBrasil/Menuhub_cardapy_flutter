import 'cart_item.dart';

class UpdateCartItemPayload {
  final int? cartItemId;
  final int productId;
  final int categoryId;
  final int quantity;
  final String? note;
  final String? sizeName;
  final String? sizeImageUrl; // : Imagem do tamanho da pizza
  final List<CartItemVariant>? variants;

  UpdateCartItemPayload({
    this.cartItemId,
    required this.productId,
    required this.categoryId,
    required this.quantity,
    this.note,
    this.sizeName,
    this.sizeImageUrl, //
    this.variants,
  });

  Map<String, dynamic> toJson() {
    return {
      'cart_item_id': cartItemId,
      'product_id': productId,
      'category_id': categoryId,
      'quantity': quantity,
      'note': note,
      'size_name': sizeName,
      'size_image_url': sizeImageUrl, // : Envia imagem da pizza
      'variants': variants?.map((v) => v.toJson()).toList(),
    }..removeWhere((key, value) => value == null);
  }
}
