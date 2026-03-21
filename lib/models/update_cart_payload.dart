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
    print('\n🔵 [UpdateCartItemPayload.toJson] INÍCIO');
    print('   - productId: $productId');
    print('   - categoryId: $categoryId');
    print('   - quantity: $quantity');
    print('   - sizeName: $sizeName');
    print('   - variants count: ${variants?.length ?? 0}');

    if (variants != null) {
      for (var i = 0; i < variants!.length; i++) {
        final v = variants![i];
        print(
          '   - Variant $i: ${v.name} (groupType: ${v.groupType}, optionGroupId: ${v.optionGroupId})',
        );
        for (var opt in v.options) {
          if (opt.quantity > 0) {
            print(
              '      → Option: ${opt.name} (qty: ${opt.quantity}, optionItemId: ${opt.optionItemId}, variantOptionId: ${opt.variantOptionId})',
            );
          }
        }
      }
    }

    final json = {
      'cart_item_id': cartItemId,
      'product_id': productId,
      'category_id': categoryId,
      'quantity': quantity,
      'note': note,
      'size_name': sizeName,
      'size_image_url': sizeImageUrl,
      'variants': variants?.map((v) => v.toJson()).toList(),
    }..removeWhere((key, value) => value == null);

    print('🔵 [UpdateCartItemPayload.toJson] FIM\n');
    return json;
  }
}
