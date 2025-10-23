// lib/models/flavor_price.dart

/// Representa preços de sabores/tamanhos para produtos como pizzas.
///
/// Exemplo:
/// - Pizza Pequena (1 sabor): R$ 30
/// - Pizza Média (até 2 sabores): R$ 45
/// - Pizza Grande (até 3 sabores): R$ 60
class FlavorPrice {
  final int? id;
  final String sizeName; // Ex: "Pequena", "Média", "Grande"
  final int maxFlavors; // Quantidade máxima de sabores permitidos
  final int price; // Preço em centavos
  final bool available;
  final int? priority; // Ordem de exibição

  FlavorPrice({
    this.id,
    required this.sizeName,
    required this.maxFlavors,
    required this.price,
    this.available = true,
    this.priority,
  });

  // ✅ FACTORY CONSTRUCTOR VAZIO
  factory FlavorPrice.empty() {
    return FlavorPrice(
      id: null,
      sizeName: '',
      maxFlavors: 1,
      price: 0,
      available: true,
      priority: null,
    );
  }

  // ✅ FROM JSON
  factory FlavorPrice.fromJson(Map<String, dynamic> json) {
    return FlavorPrice(
      id: json['id'] as int?,
      sizeName: json['size_name'] as String? ?? '',
      maxFlavors: json['max_flavors'] as int? ?? 1,
      price: json['price'] as int? ?? 0,
      available: json['available'] as bool? ?? true,
      priority: json['priority'] as int?,
    );
  }

  // ✅ TO JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size_name': sizeName,
      'max_flavors': maxFlavors,
      'price': price,
      'available': available,
      'priority': priority,
    };
  }

  // ✅ COPYWITH
  FlavorPrice copyWith({
    int? id,
    String? sizeName,
    int? maxFlavors,
    int? price,
    bool? available,
    int? priority,
  }) {
    return FlavorPrice(
      id: id ?? this.id,
      sizeName: sizeName ?? this.sizeName,
      maxFlavors: maxFlavors ?? this.maxFlavors,
      price: price ?? this.price,
      available: available ?? this.available,
      priority: priority ?? this.priority,
    );
  }

  // ✅ HELPER: Formata o preço
  String get formattedPrice {
    return 'R\$ ${(price / 100).toStringAsFixed(2)}';
  }

  // ✅ HELPER: Descrição completa
  String get description {
    if (maxFlavors == 1) {
      return '$sizeName (1 sabor) - $formattedPrice';
    }
    return '$sizeName (até $maxFlavors sabores) - $formattedPrice';
  }

  @override
  String toString() {
    return 'FlavorPrice(sizeName: $sizeName, maxFlavors: $maxFlavors, price: $formattedPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlavorPrice &&
        other.id == id &&
        other.sizeName == sizeName &&
        other.maxFlavors == maxFlavors &&
        other.price == price;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    sizeName.hashCode ^
    maxFlavors.hashCode ^
    price.hashCode;
  }
}