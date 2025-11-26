// lib/models/option_item.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/image_model.dart';

class OptionItem extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final int price; // Preço ADICIONAL, sempre em centavos (int)
  final bool isActive;
  final ImageModel? image;
  final int? slices;
  final int? maxFlavors;

  const OptionItem({
    this.id,
    required this.name,
    this.description,
    this.price = 0,
    this.isActive = true,
    this.image,
    this.slices,
    this.maxFlavors,
  });

  factory OptionItem.fromJson(Map<String, dynamic> json) {
    // Lê todos os campos numéricos como 'num?' para aceitar tanto int quanto double.
    final num? priceNum = json['price'];
    final num? slicesNum = json['slices'];
    final num? maxFlavorsNum = json['max_flavors'];

    // ✅ CORREÇÃO: O backend envia price como Decimal (ex: 12.90)
    // Converte para centavos (int) multiplicando por 100
    int priceInCents = 0;
    if (priceNum != null) {
      // Se o preço vier como valor decimal (ex: 12.90), converte para centavos
      // Se vier como centavos (ex: 1290), mantém
      if (priceNum < 1000 && priceNum != priceNum.toInt()) {
        // Valor decimal pequeno -> provavelmente em reais, converte para centavos
        priceInCents = (priceNum * 100).round();
      } else {
        priceInCents = priceNum.toInt();
      }
    }

    return OptionItem(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      price: priceInCents,
      isActive: json['is_active'] ?? true,
      image: json['image_path'] != null ? ImageModel(url: json['image_path']) : null,
      slices: slicesNum?.toInt(),
      maxFlavors: maxFlavorsNum?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'is_active': isActive,
      'image_path': image?.url,
      'slices': slices,
      'max_flavors': maxFlavors,
    };
  }

  const OptionItem.empty()
      : id = null,
        name = '',
        description = null,
        price = 0,
        isActive = true,
        image = null,
        slices = null,
        maxFlavors = null;

  @override
  List<Object?> get props => [id, name, description, price, isActive, image, slices, maxFlavors];
}