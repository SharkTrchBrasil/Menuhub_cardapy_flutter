// Em: lib/models/payment_method.dart

import 'package:equatable/equatable.dart';

// --- Nível 1: A Configuração da Loja ---
/// ✅ ENTERPRISE: Modelo alinhado com Backend (fee_value e fee_type tipados)
class StorePaymentMethodActivation extends Equatable {
  final int id;
  final bool isActive;
  final double feePercentage; // ✅ Mantido para compatibilidade (deprecated)
  final double? feeValue; // ✅ NOVO: Valor da taxa (em reais ou percentual)
  final String?
  feeType; // ✅ NOVO: Tipo da taxa ('%', 'R$', 'fixed', 'percentage')
  final Map<String, dynamic>? details;
  final bool isForDelivery;
  final bool isForPickup;
  final bool isForInStore;

  const StorePaymentMethodActivation({
    required this.id,
    required this.isActive,
    required this.feePercentage,
    this.feeValue, // ✅ NOVO
    this.feeType, // ✅ NOVO
    this.details,
    required this.isForDelivery,
    required this.isForPickup,
    required this.isForInStore,
  });

  factory StorePaymentMethodActivation.fromJson(Map<String, dynamic> json) {
    // ✅ NOVO: Extrai fee_value e fee_type de details se não estiverem no nível raiz
    final details =
        json['details'] != null
            ? Map<String, dynamic>.from(json['details'])
            : null;
    final feeValue =
        json['fee_value'] != null
            ? (json['fee_value'] as num).toDouble()
            : (details?['fee_value'] != null
                ? (details!['fee_value'] as num).toDouble()
                : null);
    final feeType =
        json['fee_type'] as String? ?? details?['fee_type'] as String?;

    return StorePaymentMethodActivation(
      id: json['id'] ?? 0, // Garante que não seja nulo
      isActive: json['is_active'] ?? true,
      feePercentage:
          (json['fee_percentage'] as num?)?.toDouble() ??
          0.0, // ✅ Mantido para compatibilidade
      feeValue: feeValue, // ✅ NOVO
      feeType: feeType, // ✅ NOVO
      details: details,
      isForDelivery: json['is_for_delivery'] ?? false,
      isForPickup: json['is_for_pickup'] ?? false,
      isForInStore: json['is_for_in_store'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_active': isActive,
      'fee_percentage': feePercentage,
      if (feeValue != null) 'fee_value': feeValue, // ✅ NOVO
      if (feeType != null) 'fee_type': feeType, // ✅ NOVO
      'details': details,
      'is_for_delivery': isForDelivery,
      'is_for_pickup': isForPickup,
      'is_for_in_store': isForInStore,
    };
  }

  // ✅ NOVO: Helper para calcular taxa corretamente
  // ✅ UNIFICADO: Sempre usa feeValue e feeType (deprecado feePercentage)
  double calculateFee(double subtotal) {
    if (feeValue == null || feeValue == 0) return 0.0;

    if (feeType == '%' || feeType == 'percentage') {
      // Taxa percentual: feeValue já é o percentual
      return (subtotal * feeValue!) / 100.0;
    } else if (feeType == 'R\$' || feeType == '\$' || feeType == 'fixed') {
      // Taxa fixa: feeValue já está em reais
      return feeValue!;
    }

    // ✅ Se não tem tipo definido, retorna 0 (não usa feePercentage como fallback)
    return 0.0;
  }

  StorePaymentMethodActivation copyWith({
    int? id,
    bool? isActive,
    double? feePercentage,
    double? feeValue, // ✅ NOVO
    String? feeType, // ✅ NOVO
    Map<String, dynamic>? details,
    bool? isForDelivery,
    bool? isForPickup,
    bool? isForInStore,
  }) {
    return StorePaymentMethodActivation(
      id: id ?? this.id,
      isActive: isActive ?? this.isActive,
      feePercentage: feePercentage ?? this.feePercentage,
      feeValue: feeValue ?? this.feeValue, // ✅ NOVO
      feeType: feeType ?? this.feeType, // ✅ NOVO
      details: details ?? this.details,
      isForDelivery: isForDelivery ?? this.isForDelivery,
      isForPickup: isForPickup ?? this.isForPickup,
      isForInStore: isForInStore ?? this.isForInStore,
    );
  }

  @override
  List<Object?> get props => [
    id,
    isActive,
    feePercentage,
    feeValue,
    feeType,
    details,
    isForDelivery,
    isForPickup,
    isForInStore,
  ];
}

// --- Nível 2: A Opção Final ---
class PlatformPaymentMethod extends Equatable {
  final int id;
  final String name;
  final String method_type;
  final String? iconKey;
  final bool requiresDetails; // ✅ ADICIONADO: Campo do backend
  final StorePaymentMethodActivation? activation;

  const PlatformPaymentMethod({
    required this.id,
    required this.name,
    this.iconKey,
    this.activation,
    required this.method_type,
    this.requiresDetails = false, // ✅ ADICIONADO
  });

  factory PlatformPaymentMethod.fromJson(Map<String, dynamic> json) {
    return PlatformPaymentMethod(
      id: json['id'],
      name: json['name'],
      iconKey: json['icon_key'],
      method_type: json['method_type'], // ✅ ADICIONADO
      requiresDetails: json['requires_details'] ?? false, // ✅ ADICIONADO
      activation:
          json['activation'] != null
              ? StorePaymentMethodActivation.fromJson(json['activation'])
              : null,
    );
  }

  // ✅ ADICIONADO copyWith E deepCopy
  PlatformPaymentMethod copyWith({
    int? id,
    String? name,
    String? method_type,
    String? iconKey,
    bool? requiresDetails,
    StorePaymentMethodActivation? activation,
  }) {
    return PlatformPaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      method_type: method_type ?? this.method_type,
      iconKey: iconKey ?? this.iconKey,
      requiresDetails: requiresDetails ?? this.requiresDetails,
      activation: activation ?? this.activation,
    );
  }

  PlatformPaymentMethod deepCopy() => PlatformPaymentMethod(
    id: id,
    name: name,
    iconKey: iconKey,
    method_type: method_type,
    requiresDetails: requiresDetails,
    activation: activation?.copyWith(), // Copia a ativação também
  );

  @override
  List<Object?> get props => [
    id,
    name,
    iconKey,
    method_type,
    requiresDetails,
    activation,
  ];
}

// --- Nível 3: A Categoria ---
class PaymentMethodCategory extends Equatable {
  final String name;
  final List<PlatformPaymentMethod> methods;

  const PaymentMethodCategory({required this.name, required this.methods});

  factory PaymentMethodCategory.fromJson(Map<String, dynamic> json) {
    final methodsList =
        (json['methods'] as List)
            .map((methodJson) => PlatformPaymentMethod.fromJson(methodJson))
            .toList();
    return PaymentMethodCategory(name: json['name'], methods: methodsList);
  }

  // ✅ ADICIONADO copyWith E deepCopy
  PaymentMethodCategory copyWith({
    String? name,
    List<PlatformPaymentMethod>? methods,
  }) {
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
// ✅ ATUALIZADO: Agora corresponde ao backend que retorna methods diretamente (sem categories)
// ✅ ADICIONADO: title e description para corresponder ao Admin e backend
class PaymentMethodGroup extends Equatable {
  final String name;
  final String?
  title; // ✅ ADICIONADO: Título do grupo (ex: "Cartões de Crédito")
  final String? description; // ✅ ADICIONADO: Descrição do grupo
  final List<PlatformPaymentMethod>
  methods; // ✅ Mudou de categories para methods

  const PaymentMethodGroup({
    required this.name,
    this.title,
    this.description,
    required this.methods,
  });

  factory PaymentMethodGroup.fromJson(Map<String, dynamic> json) {
    // ✅ Compatibilidade: Aceita tanto a estrutura nova (methods) quanto antiga (categories)
    List<PlatformPaymentMethod> methodsList = [];

    if (json['methods'] != null) {
      // Nova estrutura: methods diretamente
      methodsList =
          (json['methods'] as List)
              .map((methodJson) => PlatformPaymentMethod.fromJson(methodJson))
              .toList();
    } else if (json['categories'] != null) {
      // Estrutura antiga: categories -> methods (para compatibilidade)
      final categoriesList =
          (json['categories'] as List)
              .map(
                (categoryJson) => PaymentMethodCategory.fromJson(categoryJson),
              )
              .toList();
      methodsList = categoriesList.expand((cat) => cat.methods).toList();
    }

    return PaymentMethodGroup(
      name: json['name'] ?? '',
      title: json['title'], // ✅ ADICIONADO
      description: json['description'], // ✅ ADICIONADO
      methods: methodsList,
    );
  }

  // ✅ ADICIONADO copyWith E deepCopy
  PaymentMethodGroup copyWith({
    String? name,
    String? title,
    String? description,
    List<PlatformPaymentMethod>? methods,
  }) {
    return PaymentMethodGroup(
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      methods: methods ?? this.methods,
    );
  }

  PaymentMethodGroup deepCopy() => PaymentMethodGroup(
    name: name,
    title: title,
    description: description,
    methods: methods.map((m) => m.deepCopy()).toList(),
  );

  @override
  List<Object?> get props => [name, title, description, methods];
}
