

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

  // --- Configurações de Retirada (Pickup/Takeout) ---
  final bool pickupEnabled;
  final int? pickupEstimatedMin;
  final int? pickupEstimatedMax;
  final String? pickupInstructions;

  // --- Configurações de Consumo no Local (Mesas) ---
  final bool tableEnabled;
  final int? tableEstimatedMin;
  final int? tableEstimatedMax;
  final String? tableInstructions;

  // --- Configurações de Impressora ---
  final String? mainPrinterDestination;
  final String? kitchenPrinterDestination;
  final String? barPrinterDestination;

  final double? freeDeliveryThreshold;

  StoreOperationConfig({
    // Gerais
    this.isStoreOpen = true,
    this.autoAcceptOrders = false,
    this.autoPrintOrders = false,
    // Delivery
    this.deliveryEnabled = false,
    this.deliveryEstimatedMin,
    this.deliveryEstimatedMax,
    this.deliveryFee,
    this.deliveryMinOrder,
    this.deliveryScope = 'neighborhood',
    // Pickup
    this.pickupEnabled = false,
    this.pickupEstimatedMin,
    this.pickupEstimatedMax,
    this.pickupInstructions,
    // Table
    this.tableEnabled = false,
    this.tableEstimatedMin,
    this.tableEstimatedMax,
    this.tableInstructions,
    // Printers
    this.mainPrinterDestination,
    this.kitchenPrinterDestination,
    this.barPrinterDestination,
    this.is_operational = true,
    this.freeDeliveryThreshold,
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
      // Pickup
      pickupEnabled: json['pickup_enabled'] ?? false,
      pickupEstimatedMin: json['pickup_estimated_min'],
      pickupEstimatedMax: json['pickup_estimated_max'],
      pickupInstructions: json['pickup_instructions'],
      // Table
      tableEnabled: json['table_enabled'] ?? false,
      tableEstimatedMin: json['table_estimated_min'],
      tableEstimatedMax: json['table_estimated_max'],
      tableInstructions: json['table_instructions'],
      // Printers
      mainPrinterDestination: json['main_printer_destination'],
      kitchenPrinterDestination: json['kitchen_printer_destination'],
      barPrinterDestination: json['bar_printer_destination'],
      // o mesmo que você definiu no schema Pydantic da sua API.
      freeDeliveryThreshold: (json['free_delivery_threshold'] as num?)?.toDouble(),

    );
  }



}