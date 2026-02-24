/// Estratégia de preço para pizzas com múltiplos sabores
enum PizzaPricingStrategy {
  /// Cobra pelo sabor mais caro (padrão)
  highest,
  /// Cobra pela média dos sabores
  average;

  static PizzaPricingStrategy fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'HIGHEST':
        return PizzaPricingStrategy.highest;
      case 'AVERAGE':
      default:
        return PizzaPricingStrategy.average;
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
  final int? deliveryEstimatedMin;
  final int? deliveryEstimatedMax;
  final double? deliveryFee;
  final double? deliveryMinOrder;
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

  final double? freeDeliveryThreshold;
  final bool scheduledOrdersEnabled;
  
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
    this.deliveryEstimatedMin,
    this.deliveryEstimatedMax,
    this.deliveryFee,
    this.deliveryMinOrder,
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
    this.freeDeliveryThreshold,
    this.scheduledOrdersEnabled = false,
    // Pizza
    this.pizzaPricingStrategy = PizzaPricingStrategy.highest,
  });

  static double? _parseMoney(dynamic value) {
    double? result;
    if (value is num) result = value.toDouble();
    else if (value is Map) {
      if (value['amount'] is num) result = (value['amount'] as num).toDouble();
      else if (value['value'] is num) result = (value['value'] as num).toDouble();
    }
    else if (value is String) result = double.tryParse(value);
    
    // ✅ CORREÇÃO: Converte centavos para reais se houver valor
    return result != null ? result / 100.0 : null;
  }

  factory StoreOperationConfig.fromJson(Map<String, dynamic> json) {
    return StoreOperationConfig(
      // Gerais
      isStoreOpen: json['is_store_open'] ?? true,
      pausedUntil: json['paused_until'] != null 
          ? DateTime.tryParse(json['paused_until']) 
          : null,
      autoAcceptOrders: json['auto_accept_orders'] ?? false,
      autoPrintOrders: json['auto_print_orders'] ?? false,
      is_operational: json['is_operational'] ?? true,
      // Delivery
      deliveryEnabled: json['delivery_enabled'] ?? false,
      deliveryEstimatedMin: json['delivery_estimated_min'],
      deliveryEstimatedMax: json['delivery_estimated_max'],
      deliveryFee: _parseMoney(json['delivery_fee']),
      deliveryMinOrder: _parseMoney(json['min_order_value']) ?? 
                        _parseMoney(json['delivery_min_order']),
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
      freeDeliveryThreshold: _parseMoney(json['free_delivery_threshold']),
      scheduledOrdersEnabled: json['scheduled_orders_enabled'] ?? false,
      // ✅ Pizza pricing strategy
      pizzaPricingStrategy: PizzaPricingStrategy.fromString(json['pizza_multi_flavor_pricing_strategy']),
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
    int? deliveryEstimatedMin,
    int? deliveryEstimatedMax,
    double? deliveryFee,
    double? deliveryMinOrder,
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
    double? freeDeliveryThreshold,
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
      deliveryEstimatedMin: deliveryEstimatedMin ?? this.deliveryEstimatedMin,
      deliveryEstimatedMax: deliveryEstimatedMax ?? this.deliveryEstimatedMax,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryMinOrder: deliveryMinOrder ?? this.deliveryMinOrder,
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
      mainPrinterDestination: mainPrinterDestination ?? this.mainPrinterDestination,
      kitchenPrinterDestination: kitchenPrinterDestination ?? this.kitchenPrinterDestination,
      barPrinterDestination: barPrinterDestination ?? this.barPrinterDestination,
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      scheduledOrdersEnabled: scheduledOrdersEnabled ?? this.scheduledOrdersEnabled,
      pizzaPricingStrategy: pizzaPricingStrategy ?? this.pizzaPricingStrategy,
    );
  }
}