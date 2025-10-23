// Em: lib/models/customer_address.dart

import 'package:equatable/equatable.dart';

class CustomerAddress extends Equatable {
  // --- Propriedades do Endereço ---
  final int? id;
  // Metadados
  final String label; // Ex: "Casa", "Trabalho"
  final bool isFavorite;
  // Endereço de Texto (para exibição)

  final String street;
  final String number;
  final String? complement;
  final String neighborhood;
  final String city;
  final String? reference;
  // IDs (para lógica de frete)
  final int? cityId;
  final int? neighborhoodId;

  // --- Construtor ---
  const CustomerAddress({
    this.id,
    required this.label,
    required this.isFavorite,

    required this.street,
    required this.number,
    this.complement,
    required this.neighborhood,
    required this.city,

    this.reference,
    this.cityId,
    this.neighborhoodId,
  });

  // --- Conversor do JSON da API para o Objeto Dart ---
  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: json['id'] as int?,
      label: json['label'] as String? ?? 'Endereço',
      isFavorite: json['is_favorite'] as bool? ?? false,

      street: json['street'] as String? ?? '',
      number: json['number'] as String? ?? '',
      complement: json['complement'] as String?,
      neighborhood: json['neighborhood'] as String? ?? '',
      city: json['city'] as String? ?? '',

      reference: json['reference'] as String?,
      cityId: json['city_id'] as int?,
      neighborhoodId: json['neighborhood_id'] as int?,
    );
  }

  // --- Conversor do Objeto Dart para o JSON a ser enviado para a API ---
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'is_favorite': isFavorite,

      'street': street,
      'number': number,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,

      'reference': reference,
      // Os IDs são enviados para o backend associar com as regras de frete
      'city_id': cityId,
      'neighborhood_id': neighborhoodId,
    };
  }

  // --- Método copyWith para facilitar a manipulação de estado (BLoC/Cubit) ---
  CustomerAddress copyWith({
    int? id,
    String? label,
    bool? isFavorite,

    String? street,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,

    String? reference,
    int? cityId,
    int? neighborhoodId,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      isFavorite: isFavorite ?? this.isFavorite,

      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,

      reference: reference ?? this.reference,
      cityId: cityId ?? this.cityId,
      neighborhoodId: neighborhoodId ?? this.neighborhoodId,
    );
  }

  // Um construtor 'vazio' para estados iniciais ou placeholders
  factory CustomerAddress.empty() {
    return const CustomerAddress(
        label: '', isFavorite: false, street: '',
        number: '', neighborhood: '', city: '',
    );
  }

  // --- Equatable props para comparação de objetos ---
  @override
  List<Object?> get props => [
    id,
    label,
    isFavorite,
    street,
    number,
    complement,
    neighborhood,
    city,
    reference,
    cityId,
    neighborhoodId,
  ];
}