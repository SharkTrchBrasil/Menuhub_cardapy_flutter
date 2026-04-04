/// Estratégia de preço para pizzas com múltiplos sabores
enum PizzaPricingStrategy {
  /// Cobra pelo sabor mais caro (padrão)
  highest,

  /// Cobra pela média dos sabores
  average;

  static PizzaPricingStrategy fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'AVERAGE':
        return PizzaPricingStrategy.average;
      default:
        return PizzaPricingStrategy.highest;
    }
  }

  String toApiString() => name.toUpperCase();
}

class StoreOperationConfig {
  // --- Configurações Gerais de Operação ---
  final bool isStoreOpen;

  // ✅ PAUSA PROGRAMADA: Data/hora até quando a loja está pausada
  final DateTime? pausedUntil;

  final bool autoAcceptOrders;
  final bool autoPrintOrders;
  final bool is_operational;

  // --- Configurações de Entrega (Delivery) ---
  final bool deliveryEnabled;
  final double minOrderValue;
  final int? deliveryPrepMin;
  final int? deliveryPrepMax;
  final String? deliveryScope;
  final bool deliveryPaused;

  // --- Configurações de Retirada (Pickup/Takeout) ---
  final bool pickupEnabled;
  final int? pickupEstimatedMin;
  final int? pickupEstimatedMax;
  final String? pickupInstructions;
  final bool pickupPaused;

  // --- Configurações de Consumo no Local (Mesas) ---
  final bool tableEnabled;
  final int? tableEstimatedMin;
  final int? tableEstimatedMax;
  final String? tableInstructions;
  final bool tablePaused;

  // --- Configurações de Impressora ---
  final String? mainPrinterDestination;
  final String? kitchenPrinterDestination;
  final String? barPrinterDestination;
  final bool scheduledOrdersEnabled;

  // --- ✅ ADMIN PRESENCE: Trava de segurança (estilo iFood) ---
  // Se false, o Totem bloqueia o cardápio pois nenhum Admin está conectado.
  // Default true para backward compatibility (backends antigos não enviam o campo).
  final bool adminOnline;

  // --- ✅ NOVO: Configuração de preço para pizzas ---
  final PizzaPricingStrategy pizzaPricingStrategy;

  StoreOperationConfig({
    // Gerais
    this.isStoreOpen = true,
    this.pausedUntil,
    this.autoAcceptOrders = false,
    this.autoPrintOrders = false,
    this.is_operational = true,
    // Delivery
    this.deliveryEnabled = false,
    this.minOrderValue = 0.0,
    this.deliveryPrepMin,
    this.deliveryPrepMax,
    this.deliveryScope = 'neighborhood',
    this.deliveryPaused = false,
    // Pickup
    this.pickupEnabled = false,
    this.pickupEstimatedMin,
    this.pickupEstimatedMax,
    this.pickupInstructions,
    this.pickupPaused = false,
    // Table
    this.tableEnabled = false,
    this.tableEstimatedMin,
    this.tableEstimatedMax,
    this.tableInstructions,
    this.tablePaused = false,
    // Printers
    this.mainPrinterDestination,
    this.kitchenPrinterDestination,
    this.barPrinterDestination,
    this.scheduledOrdersEnabled = false,
    // Admin Presence
    this.adminOnline = true,
    // Pizza
    this.pizzaPricingStrategy = PizzaPricingStrategy.highest,
  });

  static double? _parseMoney(dynamic value) {
    double? result;
    if (value is num)
      result = value.toDouble();
    else if (value is Map) {
      if (value['amount'] is num)
        result = (value['amount'] as num).toDouble();
      else if (value['value'] is num)
        result = (value['value'] as num).toDouble();
    } else if (value is String)
      result = double.tryParse(value);

    // ✅ CORREÇÃO: Converte centavos para reais se houver valor
    return result != null ? result / 100.0 : null;
  }

  factory StoreOperationConfig.fromJson(Map<String, dynamic> json) {
    return StoreOperationConfig(
      // Gerais
      isStoreOpen: json['is_store_open'] ?? true,
      pausedUntil:
          json['paused_until'] != null
              ? DateTime.tryParse(json['paused_until'])
              : null,
      autoAcceptOrders: json['auto_accept_orders'] ?? false,
      autoPrintOrders: json['auto_print_orders'] ?? false,
      is_operational: json['is_operational'] ?? true,
      // Delivery
      deliveryEnabled: json['delivery_enabled'] ?? false,
      minOrderValue: _parseMoney(json['min_order_value']) ?? 0.0,
      deliveryPrepMin: json['delivery_prep_min'] as int?,
      deliveryPrepMax: json['delivery_prep_max'] as int?,
      deliveryScope: json['delivery_scope'],
      deliveryPaused: json['delivery_paused'] ?? false,
      // Pickup
      pickupEnabled: json['pickup_enabled'] ?? false,
      pickupEstimatedMin: json['pickup_estimated_min'],
      pickupEstimatedMax: json['pickup_estimated_max'],
      pickupInstructions: json['pickup_instructions'],
      pickupPaused: json['pickup_paused'] ?? false,
      // Table
      tableEnabled: json['table_enabled'] ?? false,
      tableEstimatedMin: json['table_estimated_min'],
      tableEstimatedMax: json['table_estimated_max'],
      tableInstructions: json['table_instructions'],
      tablePaused: json['table_paused'] ?? false,
      // Printers
      mainPrinterDestination: json['main_printer_destination'],
      kitchenPrinterDestination: json['kitchen_printer_destination'],
      barPrinterDestination: json['bar_printer_destination'],
      scheduledOrdersEnabled: json['scheduled_orders_enabled'] ?? false,
      // ✅ Admin Presence (default true para backward compatibility)
      adminOnline: json['admin_online'] ?? true,
      // ✅ Pizza pricing strategy
      pizzaPricingStrategy: PizzaPricingStrategy.fromString(
        json['pizza_multi_flavor_pricing_strategy'],
      ),
    );
  }

  // ✅ Getters de disponibilidade (compatibilidade com Admin)
  bool get isDeliveryAvailable => deliveryEnabled && !deliveryPaused;
  bool get isPickupAvailable => pickupEnabled && !pickupPaused;
  bool get isTableAvailable => tableEnabled && !tablePaused;

  StoreOperationConfig copyWith({
    bool? isStoreOpen,
    DateTime? pausedUntil,
    bool? autoAcceptOrders,
    bool? autoPrintOrders,
    bool? is_operational,
    bool? deliveryEnabled,
    double? minOrderValue,
    int? deliveryPrepMin,
    int? deliveryPrepMax,
    String? deliveryScope,
    bool? deliveryPaused,
    bool? pickupEnabled,
    int? pickupEstimatedMin,
    int? pickupEstimatedMax,
    String? pickupInstructions,
    bool? pickupPaused,
    bool? tableEnabled,
    int? tableEstimatedMin,
    int? tableEstimatedMax,
    String? tableInstructions,
    bool? tablePaused,
    String? mainPrinterDestination,
    String? kitchenPrinterDestination,
    String? barPrinterDestination,
    bool? adminOnline,
    bool? scheduledOrdersEnabled,
    PizzaPricingStrategy? pizzaPricingStrategy,
  }) {
    return StoreOperationConfig(
      isStoreOpen: isStoreOpen ?? this.isStoreOpen,
      pausedUntil: pausedUntil ?? this.pausedUntil,
      autoAcceptOrders: autoAcceptOrders ?? this.autoAcceptOrders,
      autoPrintOrders: autoPrintOrders ?? this.autoPrintOrders,
      is_operational: is_operational ?? this.is_operational,
      deliveryEnabled: deliveryEnabled ?? this.deliveryEnabled,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      deliveryPrepMin: deliveryPrepMin ?? this.deliveryPrepMin,
      deliveryPrepMax: deliveryPrepMax ?? this.deliveryPrepMax,
      deliveryScope: deliveryScope ?? this.deliveryScope,
      deliveryPaused: deliveryPaused ?? this.deliveryPaused,
      pickupEnabled: pickupEnabled ?? this.pickupEnabled,
      pickupEstimatedMin: pickupEstimatedMin ?? this.pickupEstimatedMin,
      pickupEstimatedMax: pickupEstimatedMax ?? this.pickupEstimatedMax,
      pickupInstructions: pickupInstructions ?? this.pickupInstructions,
      pickupPaused: pickupPaused ?? this.pickupPaused,
      tableEnabled: tableEnabled ?? this.tableEnabled,
      tableEstimatedMin: tableEstimatedMin ?? this.tableEstimatedMin,
      tableEstimatedMax: tableEstimatedMax ?? this.tableEstimatedMax,
      tableInstructions: tableInstructions ?? this.tableInstructions,
      tablePaused: tablePaused ?? this.tablePaused,
      mainPrinterDestination:
          mainPrinterDestination ?? this.mainPrinterDestination,
      kitchenPrinterDestination:
          kitchenPrinterDestination ?? this.kitchenPrinterDestination,
      barPrinterDestination:
          barPrinterDestination ?? this.barPrinterDestination,
      scheduledOrdersEnabled:
          scheduledOrdersEnabled ?? this.scheduledOrdersEnabled,
      adminOnline: adminOnline ?? this.adminOnline,
      pizzaPricingStrategy: pizzaPricingStrategy ?? this.pizzaPricingStrategy,
    );
  }
}
