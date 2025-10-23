// lib/models/variant_option.dart

class VariantOption {
  final int id;
  final int variantId;
  final String? description;

  // Propriedades resolvidas do backend
  final String resolvedName;
  final int resolvedPrice;
  final String? imagePath;

  // Disponibilidade
  final bool available;

  // ✅ CAMPOS DE ESTOQUE (NOVOS)
  final bool trackInventory;
  final int stockQuantity;
  final bool isActuallyAvailable;

  // Overrides manuais
  final String? name_override;
  final int? price_override;
  final String? pos_code;
  final int? linked_product_id;

  VariantOption({
    required this.id,
    required this.variantId,
    required this.resolvedName,
    required this.resolvedPrice,
    required this.available,
    required this.trackInventory,
    required this.stockQuantity,
    required this.isActuallyAvailable,
    this.description,
    this.imagePath,
    this.name_override,
    this.price_override,
    this.pos_code,
    this.linked_product_id,
  });

  factory VariantOption.fromJson(Map<String, dynamic> json) {
    return VariantOption(
      id: json['id'] as int,
      variantId: json['variant_id'] as int,
      resolvedName: json['resolved_name'] as String,
      resolvedPrice: json['resolved_price'] as int,
      available: json['available'] as bool? ?? true,

      // ✅ NOVOS CAMPOS
      trackInventory: json['track_inventory'] as bool? ?? false,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      isActuallyAvailable: json['is_actually_available'] as bool? ?? true,

      description: json['description'] as String?,
      imagePath: json['image_path'] as String?,
      name_override: json['name_override'] as String?,
      price_override: json['price_override'] as int?,
      pos_code: json['pos_code'] as String?,
      linked_product_id: json['linked_product_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'variant_id': variantId,
      'resolved_name': resolvedName,
      'resolved_price': resolvedPrice,
      'available': available,
      'track_inventory': trackInventory,
      'stock_quantity': stockQuantity,
      'is_actually_available': isActuallyAvailable,
      'description': description,
      'image_path': imagePath,
      'name_override': name_override,
      'price_override': price_override,
      'pos_code': pos_code,
      'linked_product_id': linked_product_id,
    };
  }

  // ✅ Verifica se a opção realmente está disponível
  bool get canBeSelected {
    if (!available) return false;
    if (!trackInventory) return true;
    return stockQuantity > 0 && isActuallyAvailable;
  }
}