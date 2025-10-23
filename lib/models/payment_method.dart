// Em: lib/models/payment_method.dart

import 'package:equatable/equatable.dart';

// --- Nível 1: A Configuração da Loja ---
class StorePaymentMethodActivation extends Equatable {
  final int id;
  final bool isActive;
  final double feePercentage;
  final Map<String, dynamic>? details;
  final bool isForDelivery;
  final bool isForPickup;
  final bool isForInStore;

  const StorePaymentMethodActivation({
    required this.id,
    required this.isActive,
    required this.feePercentage,
    this.details,
    required this.isForDelivery,
    required this.isForPickup,
    required this.isForInStore,
  });

  factory StorePaymentMethodActivation.fromJson(Map<String, dynamic> json) {
    return StorePaymentMethodActivation(
      id: json['id'] ?? 0, // Garante que não seja nulo
      isActive: json['is_active'],
      feePercentage: (json['fee_percentage'] as num).toDouble(),
      details: json['details'] != null ? Map<String, dynamic>.from(json['details']) : null,
      isForDelivery: json['is_for_delivery'],
      isForPickup: json['is_for_pickup'],
      isForInStore: json['is_for_in_store'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_active': isActive,
      'fee_percentage': feePercentage,
      'details': details,
      'is_for_delivery': isForDelivery,
      'is_for_pickup': isForPickup,
      'is_for_in_store': isForInStore,
    };
  }

  // ✅ copyWith JÁ EXISTIA AQUI, ESTÁ CORRETO
  StorePaymentMethodActivation copyWith({
    int? id, bool? isActive, double? feePercentage, Map<String, dynamic>? details,
    bool? isForDelivery, bool? isForPickup, bool? isForInStore,
  }) {
    return StorePaymentMethodActivation(
      id: id ?? this.id,
      isActive: isActive ?? this.isActive,
      feePercentage: feePercentage ?? this.feePercentage,
      details: details ?? this.details,
      isForDelivery: isForDelivery ?? this.isForDelivery,
      isForPickup: isForPickup ?? this.isForPickup,
      isForInStore: isForInStore ?? this.isForInStore,
    );
  }

  @override
  List<Object?> get props => [id, isActive, feePercentage, details, isForDelivery, isForPickup, isForInStore];
}


// --- Nível 2: A Opção Final ---
class PlatformPaymentMethod extends Equatable {
  final int id;
  final String name;
  final String method_type;
  final String? iconKey;
  final StorePaymentMethodActivation? activation;

  const PlatformPaymentMethod({
    required this.id,
    required this.name,
    this.iconKey,
    this.activation,
    required this.method_type,

  });

  factory PlatformPaymentMethod.fromJson(Map<String, dynamic> json) {
    return PlatformPaymentMethod(
      id: json['id'],
      name: json['name'],
      iconKey: json['icon_key'],
      method_type: json['method_type'], // ✅ ADICIONADO
      activation: json['activation'] != null
          ? StorePaymentMethodActivation.fromJson(json['activation'])
          : null,
    );
  }

  // ✅ ADICIONADO copyWith E deepCopy
  PlatformPaymentMethod copyWith({ int? id, String? name,    String? method_type, String? iconKey, StorePaymentMethodActivation? activation }) {
    return PlatformPaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      method_type: method_type ?? this.method_type,
      iconKey: iconKey ?? this.iconKey,
      activation: activation ?? this.activation,
    );
  }

  PlatformPaymentMethod deepCopy() => PlatformPaymentMethod(
    id: id, name: name, iconKey: iconKey,
    method_type: method_type,
    activation: activation?.copyWith(), // Copia a ativação também
  );

  @override
  List<Object?> get props => [id, name, iconKey,method_type, activation];
}


// --- Nível 3: A Categoria ---
class PaymentMethodCategory extends Equatable {
  final String name;
  final List<PlatformPaymentMethod> methods;

  const PaymentMethodCategory({ required this.name, required this.methods });

  factory PaymentMethodCategory.fromJson(Map<String, dynamic> json) {
    final methodsList = (json['methods'] as List)
        .map((methodJson) => PlatformPaymentMethod.fromJson(methodJson))
        .toList();
    return PaymentMethodCategory( name: json['name'], methods: methodsList );
  }

  // ✅ ADICIONADO copyWith E deepCopy
  PaymentMethodCategory copyWith({ String? name, List<PlatformPaymentMethod>? methods }) {
    return PaymentMethodCategory(
      name: name ?? this.name,
      methods: methods ?? this.methods,
    );
  }

  PaymentMethodCategory deepCopy() => PaymentMethodCategory(
    name: name,
    methods: methods.map((m) => m.deepCopy()).toList(),
  );

  @override
  List<Object?> get props => [name, methods];
}


// --- Nível 4: O Grupo Principal ---
class PaymentMethodGroup extends Equatable {
  final String name;
  final List<PaymentMethodCategory> categories;

  const PaymentMethodGroup({ required this.name, required this.categories });

  factory PaymentMethodGroup.fromJson(Map<String, dynamic> json) {
    final categoriesList = (json['categories'] as List)
        .map((categoryJson) => PaymentMethodCategory.fromJson(categoryJson))
        .toList();
    return PaymentMethodGroup( name: json['name'], categories: categoriesList );
  }

  // ✅ ADICIONADO copyWith E deepCopy
  PaymentMethodGroup copyWith({ String? name, List<PaymentMethodCategory>? categories }) {
    return PaymentMethodGroup(
      name: name ?? this.name,
      categories: categories ?? this.categories,
    );
  }

  PaymentMethodGroup deepCopy() => PaymentMethodGroup(
    name: name,
    categories: categories.map((c) => c.deepCopy()).toList(),
  );

  @override
  List<Object?> get props => [name, categories];
}