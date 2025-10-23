

import 'package:equatable/equatable.dart';

class StoreAddress extends Equatable {
  final String street;
  final String number;
  final String neighborhood;
  final String city;
  final String state;
  final String zipCode;
  final String? complement;

  const StoreAddress({
    required this.street,
    required this.number,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.zipCode,
    this.complement,
  });

  factory StoreAddress.fromJson(Map<String, dynamic> json) {
    return StoreAddress(
      street: json['street'] as String,
      number: json['number'] as String,
      neighborhood: json['neighborhood'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      zipCode: json['zipCode'] as String,
      complement: json['complement'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'number': number,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'complement': complement,
    };
  }

  String get fullAddress => '$street, $number - $neighborhood, $city - $state, $zipCode';

  @override
  List<Object?> get props => [street, number, neighborhood, city, state, zipCode, complement];
}