
class StoreOperationConfig {
  // --- Configurações Gerais de Operação ---
  final bool isStoreOpen;
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
  final bool deliveryPaused; // ✅ NOVO

  // --- Configurações de Retirada (Pickup/Takeout) ---
  final bool pickupEnabled;
  final int? pickupEstimatedMin;
  final int? pickupEstimatedMax;
  final String? pickupInstructions;
  final bool pickupPaused; // ✅ NOVO

  // --- Configurações de Consumo no Local (Mesas) ---
  final bool tableEnabled;
  final int? tableEstimatedMin;
  final int? tableEstimatedMax;
  final String? tableInstructions;
  final bool tablePaused; // ✅ NOVO

  // --- Configurações de Impressora ---
  final String? mainPrinterDestination;
  final String? kitchenPrinterDestination;
  final String? barPrinterDestination;

  final double? freeDeliveryThreshold;
  final bool scheduledOrdersEnabled;

  StoreOperationConfig({
    // Gerais
    this.isStoreOpen = true,
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
    this.deliveryPaused = false, // ✅ NOVO
    // Pickup
    this.pickupEnabled = false,
    this.pickupEstimatedMin,
    this.pickupEstimatedMax,
    this.pickupInstructions,
    this.pickupPaused = false, // ✅ NOVO
    // Table
    this.tableEnabled = false,
    this.tableEstimatedMin,
    this.tableEstimatedMax,
    this.tableInstructions,
    this.tablePaused = false, // ✅ NOVO
    // Printers
    this.mainPrinterDestination,
    this.kitchenPrinterDestination,
    this.barPrinterDestination,
    this.freeDeliveryThreshold,
    this.scheduledOrdersEnabled = false,
  });

  factory StoreOperationConfig.fromJson(Map<String, dynamic> json) {
    return StoreOperationConfig(
      // Gerais
      isStoreOpen: json['is_store_open'] ?? true,
      autoAcceptOrders: json['auto_accept_orders'] ?? false,
      autoPrintOrders: json['auto_print_orders'] ?? false,
      is_operational: json['is_operational'] ?? true,
      // Delivery
      deliveryEnabled: json['delivery_enabled'] ?? false,
      deliveryEstimatedMin: json['delivery_estimated_min'],
      deliveryEstimatedMax: json['delivery_estimated_max'],
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
      deliveryMinOrder: (json['delivery_min_order'] as num?)?.toDouble(),
      deliveryScope: json['delivery_scope'],
      deliveryPaused: json['delivery_paused'] ?? false, // ✅ NOVO
      // Pickup
      pickupEnabled: json['pickup_enabled'] ?? false,
      pickupEstimatedMin: json['pickup_estimated_min'],
      pickupEstimatedMax: json['pickup_estimated_max'],
      pickupInstructions: json['pickup_instructions'],
      pickupPaused: json['pickup_paused'] ?? false, // ✅ NOVO
      // Table
      tableEnabled: json['table_enabled'] ?? false,
      tableEstimatedMin: json['table_estimated_min'],
      tableEstimatedMax: json['table_estimated_max'],
      tableInstructions: json['table_instructions'],
      tablePaused: json['table_paused'] ?? false, // ✅ NOVO
      // Printers
      mainPrinterDestination: json['main_printer_destination'],
      kitchenPrinterDestination: json['kitchen_printer_destination'],
      barPrinterDestination: json['bar_printer_destination'],
      freeDeliveryThreshold: (json['free_delivery_threshold'] as num?)?.toDouble(),
      scheduledOrdersEnabled: json['scheduled_orders_enabled'] ?? false,
    );
  }

  // ✅ Getters de disponibilidade (compatibilidade com Admin)
  bool get isDeliveryAvailable => deliveryEnabled && !deliveryPaused;
  bool get isPickupAvailable => pickupEnabled && !pickupPaused;
  bool get isTableAvailable => tableEnabled && !tablePaused;

  StoreOperationConfig copyWith({
    bool? isStoreOpen,
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
  }) {
    return StoreOperationConfig(
      isStoreOpen: isStoreOpen ?? this.isStoreOpen,
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
    );
  }
}