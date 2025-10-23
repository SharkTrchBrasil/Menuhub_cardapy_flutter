class OrderProductVariantOption {

  OrderProductVariantOption({
    required this.id,
    required this.name,
    required this.quantity,
  });

  final int id;
  final String name;
  final int quantity;

  factory OrderProductVariantOption.fromJson(Map<String, dynamic> map) {
    return OrderProductVariantOption(
      id: map['id'] as int,
      name: map['name'] as String,
      quantity: map['quantity'] as int,
    );
  }

}