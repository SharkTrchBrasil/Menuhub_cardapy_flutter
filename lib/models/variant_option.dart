enum UIDisplayMode { SINGLE, MULTIPLE, QUANTITY, UNKNOWN }

class VariantOption {
  final int id;
  final int variantId;
  final String? description;

  // Propriedades "resolvidas" que vêm prontas do backend
  final String resolvedName;
  final int resolvedPrice;
  final String? imagePath;

  // Flag de override manual que vem da API
  final bool available;

  // ✅ NOVOS CAMPOS DE ESTOQUE E DISPONIBILIDADE
  final bool trackInventory;
  final int stockQuantity;
  final bool isActuallyAvailable;

  // Campos de override que podem ou não vir da API
  final String? name_override;
  final int? price_override;
  final String? pos_code;
  final int? linked_product_id;

  // ✅ CONSTRUTOR ATUALIZADO E SIMPLIFICADO
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

  // ✅ FROMJSON ATUALIZADO PARA LER TODOS OS CAMPOS DA API
  factory VariantOption.fromJson(Map<String, dynamic> json) {
    return VariantOption(
      id: json['id'],
      variantId: json['variant_id'],
      resolvedName: json['resolved_name'] ?? 'Opção sem nome',
      resolvedPrice: json['resolved_price'] ?? 0,
      imagePath: json['image_path'],
      description: json['description'],
      available: json['available'] ?? true,

      // ✅ LENDO OS NOVOS CAMPOS DA API COM VALORES PADRÃO
      trackInventory: json['track_inventory'] ?? false,
      stockQuantity: json['stock_quantity'] ?? 0,
      isActuallyAvailable: json['is_actually_available'] ?? false,

      // Campos de override
      name_override: json['name_override'],
      price_override: json['price_override'],
      pos_code: json['pos_code'],
      linked_product_id: json['linked_product_id'],
    );
  }

  // ✅ COPYWITH ATUALIZADO PARA INCLUIR TODOS OS CAMPOS
  VariantOption copyWith({
    int? id,
    int? variantId,
    String? description,
    String? resolvedName,
    int? resolvedPrice,
    String? imagePath,
    bool? available,
    bool? trackInventory,
    int? stockQuantity,
    bool? isActuallyAvailable,
    String? name_override,
    int? price_override,
    String? pos_code,
    int? linked_product_id,
  }) {
    return VariantOption(
      id: id ?? this.id,
      variantId: variantId ?? this.variantId,
      description: description ?? this.description,
      resolvedName: resolvedName ?? this.resolvedName,
      resolvedPrice: resolvedPrice ?? this.resolvedPrice,
      imagePath: imagePath ?? this.imagePath,
      available: available ?? this.available,
      trackInventory: trackInventory ?? this.trackInventory,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActuallyAvailable: isActuallyAvailable ?? this.isActuallyAvailable,
      name_override: name_override ?? this.name_override,
      price_override: price_override ?? this.price_override,
      pos_code: pos_code ?? this.pos_code,
      linked_product_id: linked_product_id ?? this.linked_product_id,
    );
  }

  // ✅ TOJSON ATUALIZADO (usado para enviar dados para a API, ex: em um painel admin)
  Map<String, dynamic> toJson() {
    return {
      'variant_id': variantId,
      'name_override': name_override,
      'price_override': price_override,
      'available': available,
      'pos_code': pos_code,
      'linked_product_id': linked_product_id,
      'description': description,
      // Adicionando os campos de estoque para poderem ser editados
      'track_inventory': trackInventory,
      'stock_quantity': stockQuantity,
    };
  }
}