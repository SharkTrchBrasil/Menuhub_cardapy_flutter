/// Modelos para Rotas, Fidelidade e Pricing Dinâmico
import 'package:equatable/equatable.dart';

// ============= ROTAS =============

class DeliveryStop extends Equatable {
  final int id;
  final int routeId;
  final int orderId;
  final int sequence;
  final double latitude;
  final double longitude;
  final String? address;
  final double? distanceFromPreviousKm;
  final String status;
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  const DeliveryStop({
    required this.id,
    required this.routeId,
    required this.orderId,
    required this.sequence,
    required this.latitude,
    required this.longitude,
    this.address,
    this.distanceFromPreviousKm,
    required this.status,
    this.arrivedAt,
    this.completedAt,
  });

  factory DeliveryStop.fromJson(Map<String, dynamic> json) {
    return DeliveryStop(
      id: json['id'] as int,
      routeId: json['route_id'] as int,
      orderId: json['order_id'] as int,
      sequence: json['sequence'] as int,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      address: json['address'] as String?,
      distanceFromPreviousKm: json['distance_from_previous_km'] as double?,
      status: json['status'] as String,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'in_transit':
        return 'A caminho';
      case 'arrived':
        return 'Chegou';
      case 'completed':
        return 'Concluído';
      case 'failed':
        return 'Falhou';
      default:
        return status;
    }
  }

  @override
  List<Object?> get props => [
        id,
        routeId,
        orderId,
        sequence,
        latitude,
        longitude,
        status,
      ];
}

class DeliveryRoute extends Equatable {
  final int id;
  final int deliveryPersonId;
  final int storeId;
  final String? routeName;
  final int totalOrders;
  final int completedOrders;
  final double? totalDistanceKm;
  final int? estimatedDurationMinutes;
  final String status;
  final double completionPercentage;
  final List<DeliveryStop> stops;

  const DeliveryRoute({
    required this.id,
    required this.deliveryPersonId,
    required this.storeId,
    this.routeName,
    required this.totalOrders,
    required this.completedOrders,
    this.totalDistanceKm,
    this.estimatedDurationMinutes,
    required this.status,
    required this.completionPercentage,
    this.stops = const [],
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    return DeliveryRoute(
      id: json['id'] as int,
      deliveryPersonId: json['delivery_person_id'] as int,
      storeId: json['store_id'] as int,
      routeName: json['route_name'] as String?,
      totalOrders: json['total_orders'] as int,
      completedOrders: json['completed_orders'] as int,
      totalDistanceKm: json['total_distance_km'] as double?,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      status: json['status'] as String,
      completionPercentage: json['completion_percentage'] as double,
      stops: (json['stops'] as List?)
              ?.map((s) => DeliveryStop.fromJson(s))
              .toList() ??
          [],
    );
  }

  String get statusText {
    switch (status) {
      case 'planned':
        return 'Planejada';
      case 'in_progress':
        return 'Em andamento';
      case 'completed':
        return 'Concluída';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }

  String get progressText => '$completedOrders/$totalOrders entregas';

  @override
  List<Object?> get props => [
        id,
        deliveryPersonId,
        totalOrders,
        completedOrders,
        status,
      ];
}

// ============= FIDELIDADE =============

class LoyaltyTier extends Equatable {
  final String name;
  final int minOrders;
  final int discountPercentage;
  final double? freeDeliveryThreshold;
  final String badgeColor;

  const LoyaltyTier({
    required this.name,
    required this.minOrders,
    required this.discountPercentage,
    this.freeDeliveryThreshold,
    required this.badgeColor,
  });

  factory LoyaltyTier.fromJson(Map<String, dynamic> json) {
    return LoyaltyTier(
      name: json['name'] as String,
      minOrders: json['min_orders'] as int,
      discountPercentage: json['discount_percentage'] as int,
      freeDeliveryThreshold:
          json['free_delivery_threshold'] as double?,
      badgeColor: json['badge_color'] as String,
    );
  }

  @override
  List<Object?> get props => [name, minOrders, discountPercentage];
}

class CustomerLoyalty extends Equatable {
  final int customerId;
  final int totalOrders;
  final LoyaltyTier currentTier;
  final LoyaltyTier? nextTier;
  final int ordersToNextTier;
  final double totalSaved;

  const CustomerLoyalty({
    required this.customerId,
    required this.totalOrders,
    required this.currentTier,
    this.nextTier,
    required this.ordersToNextTier,
    required this.totalSaved,
  });

  factory CustomerLoyalty.fromJson(Map<String, dynamic> json) {
    return CustomerLoyalty(
      customerId: json['customer_id'] as int,
      totalOrders: json['total_orders'] as int,
      currentTier: LoyaltyTier.fromJson(json['current_tier']),
      nextTier: json['next_tier'] != null
          ? LoyaltyTier.fromJson(json['next_tier'])
          : null,
      ordersToNextTier: json['orders_to_next_tier'] as int,
      totalSaved: json['total_saved_reais'] as double,
    );
  }

  String get totalSavedFormatted => 'R\$ ${totalSaved.toStringAsFixed(2)}';
  
  String get progressText {
    if (nextTier == null) return 'Tier máximo alcançado!';
    return 'Faltam $ordersToNextTier pedidos para ${nextTier!.name}';
  }

  @override
  List<Object?> get props => [customerId, totalOrders, currentTier];
}

// ============= PRICING DINÂMICO =============

class DynamicPricing extends Equatable {
  final double baseFee;
  final double multiplier;
  final double finalFee;
  final List<String> activeRules;
  final String message;

  const DynamicPricing({
    required this.baseFee,
    required this.multiplier,
    required this.finalFee,
    required this.activeRules,
    required this.message,
  });

  factory DynamicPricing.fromJson(Map<String, dynamic> json) {
    return DynamicPricing(
      baseFee: json['base_fee_reais'] as double,
      multiplier: json['multiplier'] as double,
      finalFee: json['final_fee_reais'] as double,
      activeRules: (json['active_rules'] as List).cast<String>(),
      message: json['message'] as String,
    );
  }

  bool get hasSurge => multiplier > 1.0;
  
  String get baseFeeFormatted => 'R\$ ${baseFee.toStringAsFixed(2)}';
  String get finalFeeFormatted => 'R\$ ${finalFee.toStringAsFixed(2)}';
  
  String get surgeText {
    if (!hasSurge) return '';
    final percentage = ((multiplier - 1) * 100).toInt();
    return '+$percentage%';
  }

  @override
  List<Object?> get props => [baseFee, multiplier, finalFee];
}

// ============= AVALIAÇÕES =============

class DeliveryRating extends Equatable {
  final int orderId;
  final int rating;
  final List<String> tags;
  final String? comment;

  const DeliveryRating({
    required this.orderId,
    required this.rating,
    this.tags = const [],
    this.comment,
  });

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'rating': rating,
        'tags': tags,
        'comment': comment,
      };

  @override
  List<Object?> get props => [orderId, rating, tags];
}
