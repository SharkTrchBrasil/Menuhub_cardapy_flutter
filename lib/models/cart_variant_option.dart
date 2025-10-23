import 'package:totem/models/variant_option.dart';

class CartVariantOption {
  // --- Propriedades do Template (Vindas da API) ---
  final int id;
  final String name;
  final String? description;
  final int price; // Em centavos
  final String? imageUrl;

  // ✅ NOVOS CAMPOS DE ESTOQUE E DISPONIBILIDADE
  final bool trackInventory;
  final int stockQuantity;
  final bool isActuallyAvailable; // A "verdade final" sobre a disponibilidade

  // --- Propriedade de Estado do Carrinho (A única que muda na tela) ---
  final int quantity;

  CartVariantOption({
    required this.id,
    required this.name,
    required this.price,
    required this.trackInventory,
    required this.stockQuantity,
    required this.isActuallyAvailable,
    this.description,
    this.imageUrl,
    this.quantity = 0,
  });

  /// ✅ CONSTRUTOR DE FÁBRICA ATUALIZADO
  /// Cria um item de carrinho a partir do "molde" (VariantOption) vindo da API.
  /// Aceita uma quantidade inicial para a funcionalidade de "opções padrão".
  factory CartVariantOption.fromVariantOption(
      VariantOption option, {
        int initialQuantity = 0,
      }) {
    return CartVariantOption(
      id: option.id,
      name: option.resolvedName,
      price: option.resolvedPrice,
      imageUrl: option.imagePath,
      description: option.description,

      // ✅ MAPEANDO OS NOVOS CAMPOS
      trackInventory: option.trackInventory,
      stockQuantity: option.stockQuantity,
      isActuallyAvailable: option.isActuallyAvailable,

      // ✅ USANDO A QUANTIDADE INICIAL
      quantity: initialQuantity,
    );
  }

  /// ✅ FROMJSON ATUALIZADO
  /// Reconstrói um item de carrinho a partir de um JSON (ex: de um pedido salvo).
  factory CartVariantOption.fromJson(Map<String, dynamic> json) {
    return CartVariantOption(
      id: json['variant_option_id'],
      name: json['name'] ?? '',
      price: json['price'],
      quantity: json['quantity'],
      description: json['description'],

      // ✅ LENDO OS NOVOS CAMPOS DO JSON COM VALORES PADRÃO SEGUROS
      trackInventory: json['track_inventory'] ?? false,
      stockQuantity: json['stock_quantity'] ?? 0,
      isActuallyAvailable: json['is_actually_available'] ?? false, // Por padrão, considera indisponível se a info não vier

      imageUrl: null, // Geralmente não é salvo no JSON do pedido
    );
  }

  /// ✅ COPYWITH ATUALIZADO E COMPLETO
  /// Cria uma cópia do objeto, permitindo a alteração de suas propriedades.
  /// Essencial para o gerenciamento de estado imutável com BLoC/Cubit.
  CartVariantOption copyWith({
    int? id,
    String? name,
    String? description,
    int? price,
    String? imageUrl,
    bool? trackInventory,
    int? stockQuantity,
    bool? isActuallyAvailable,
    int? quantity,
  }) {
    return CartVariantOption(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      trackInventory: trackInventory ?? this.trackInventory,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActuallyAvailable: isActuallyAvailable ?? this.isActuallyAvailable,
      quantity: quantity ?? this.quantity,
    );
  }
}