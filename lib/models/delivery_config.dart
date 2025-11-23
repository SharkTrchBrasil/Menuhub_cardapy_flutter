/// ✅ NOVO v2.0: Modelo para configuração simplificada de frete
/// 
/// Substitui DeliveryFeeRule com arquitetura mais simples.
/// Suporta 3 tipos:
/// - simple_radius: Taxa fixa dentro de um raio
/// - progressive_radius: Taxa progressiva por distância
/// - custom_zones: Zonas customizadas no mapa

class DeliveryConfig {
  final int? id;
  final int storeId;
  final String type; // 'simple_radius', 'progressive_radius', 'custom_zones'
  final String? name;
  final Map<String, dynamic> config;
  final bool isActive;
  final int priority;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeliveryConfig({
    this.id,
    required this.storeId,
    required this.type,
    this.name,
    required this.config,
    this.isActive = true,
    this.priority = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryConfig.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return DeliveryConfig(
      id: json['id'] as int?,
      storeId: json['store_id'] as int,
      type: json['type'] as String,
      name: json['name'] as String?,
      config: json['config'] as Map<String, dynamic>? ?? {},
      isActive: json['is_active'] as bool? ?? true,
      priority: json['priority'] as int? ?? 1,
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'store_id': storeId,
      'type': type,
      if (name != null) 'name': name,
      'config': config,
      'is_active': isActive,
      'priority': priority,
    };
  }

  DeliveryConfig copyWith({
    int? id,
    int? storeId,
    String? type,
    String? name,
    Map<String, dynamic>? config,
    bool? isActive,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryConfig(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      type: type ?? this.type,
      name: name ?? this.name,
      config: config ?? this.config,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Retorna nome para exibição
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    
    switch (type) {
      case 'simple_radius':
        return 'Raio Simples';
      case 'progressive_radius':
        return 'Raio Progressivo';
      case 'custom_zones':
        return 'Zonas Customizadas';
      default:
        return type;
    }
  }
}

/// Modelo para resposta de cálculo de frete (v2.0)
class DeliveryFeeCalculation {
  final bool success;
  final int? fee; // Em centavos
  final double? distanceKm;
  final EstimatedTime? estimatedTime;
  final String? message;
  final String? error;
  final String? zoneName;
  final String? calculationDetail;

  DeliveryFeeCalculation({
    required this.success,
    this.fee,
    this.distanceKm,
    this.estimatedTime,
    this.message,
    this.error,
    this.zoneName,
    this.calculationDetail,
  });

  factory DeliveryFeeCalculation.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeCalculation(
      success: json['success'] as bool,
      fee: json['fee'] as int?,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      estimatedTime: json['estimated_time'] != null
          ? EstimatedTime.fromJson(json['estimated_time'])
          : null,
      message: json['message'] as String?,
      error: json['error'] as String?,
      zoneName: json['zone_name'] as String?,
      calculationDetail: json['calculation_detail'] as String?,
    );
  }

  /// Retorna valor do frete em reais
  double? get feeInReais => fee != null ? fee! / 100.0 : null;
}

/// Tempo estimado de entrega
class EstimatedTime {
  final int min;
  final int max;

  EstimatedTime({
    required this.min,
    required this.max,
  });

  factory EstimatedTime.fromJson(Map<String, dynamic> json) {
    return EstimatedTime(
      min: json['min'] as int,
      max: json['max'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min': min,
      'max': max,
    };
  }

  @override
  String toString() => '$min-$max min';
}

/// Configuração de Raio Simples
class SimpleRadiusConfig {
  final double maxRadiusKm;
  final int deliveryFee; // Em centavos
  final int? freeDeliveryThreshold; // Em centavos
  final EstimatedTime? estimatedTime;

  SimpleRadiusConfig({
    required this.maxRadiusKm,
    required this.deliveryFee,
    this.freeDeliveryThreshold,
    this.estimatedTime,
  });

  factory SimpleRadiusConfig.fromJson(Map<String, dynamic> json) {
    return SimpleRadiusConfig(
      maxRadiusKm: (json['max_radius_km'] as num).toDouble(),
      deliveryFee: json['delivery_fee'] as int,
      freeDeliveryThreshold: json['free_delivery_threshold'] as int?,
      estimatedTime: json['estimated_time'] != null
          ? EstimatedTime.fromJson(json['estimated_time'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_radius_km': maxRadiusKm,
      'delivery_fee': deliveryFee,
      if (freeDeliveryThreshold != null)
        'free_delivery_threshold': freeDeliveryThreshold,
      if (estimatedTime != null) 'estimated_time': estimatedTime!.toJson(),
    };
  }

  /// Retorna taxa em reais
  double get deliveryFeeInReais => deliveryFee / 100.0;

  /// Retorna threshold em reais
  double? get freeDeliveryThresholdInReais =>
      freeDeliveryThreshold != null ? freeDeliveryThreshold! / 100.0 : null;
}

/// Configuração de Raio Progressivo
class ProgressiveRadiusConfig {
  final double maxRadiusKm;
  final double baseRadiusKm;
  final int baseFee; // Em centavos
  final int kmRate; // Em centavos
  final double? freeKm;
  final int? freeDeliveryThreshold; // Em centavos
  final EstimatedTime? estimatedTime;

  ProgressiveRadiusConfig({
    required this.maxRadiusKm,
    required this.baseRadiusKm,
    required this.baseFee,
    required this.kmRate,
    this.freeKm,
    this.freeDeliveryThreshold,
    this.estimatedTime,
  });

  factory ProgressiveRadiusConfig.fromJson(Map<String, dynamic> json) {
    return ProgressiveRadiusConfig(
      maxRadiusKm: (json['max_radius_km'] as num).toDouble(),
      baseRadiusKm: (json['base_radius_km'] as num).toDouble(),
      baseFee: json['base_fee'] as int,
      kmRate: json['km_rate'] as int,
      freeKm: json['free_km'] != null ? (json['free_km'] as num).toDouble() : null,
      freeDeliveryThreshold: json['free_delivery_threshold'] as int?,
      estimatedTime: json['estimated_time'] != null
          ? EstimatedTime.fromJson(json['estimated_time'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_radius_km': maxRadiusKm,
      'base_radius_km': baseRadiusKm,
      'base_fee': baseFee,
      'km_rate': kmRate,
      if (freeKm != null) 'free_km': freeKm,
      if (freeDeliveryThreshold != null)
        'free_delivery_threshold': freeDeliveryThreshold,
      if (estimatedTime != null) 'estimated_time': estimatedTime!.toJson(),
    };
  }

  /// Retorna taxa base em reais
  double get baseFeeInReais => baseFee / 100.0;

  /// Retorna taxa por km em reais
  double get kmRateInReais => kmRate / 100.0;

  /// Retorna threshold em reais
  double? get freeDeliveryThresholdInReais =>
      freeDeliveryThreshold != null ? freeDeliveryThreshold! / 100.0 : null;
}

/// Ponto de um polígono
class ZonePoint {
  final double lat;
  final double lng;

  ZonePoint({
    required this.lat,
    required this.lng,
  });

  factory ZonePoint.fromJson(Map<String, dynamic> json) {
    return ZonePoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }
}

/// Zona customizada
class CustomZone {
  final int id;
  final String name;
  final List<ZonePoint> polygon;
  final int deliveryFee; // Em centavos
  final int? minOrderValue; // Em centavos
  final EstimatedTime? estimatedTime;
  final String color;

  CustomZone({
    required this.id,
    required this.name,
    required this.polygon,
    required this.deliveryFee,
    this.minOrderValue,
    this.estimatedTime,
    this.color = '#4CAF50',
  });

  factory CustomZone.fromJson(Map<String, dynamic> json) {
    return CustomZone(
      id: json['id'] as int,
      name: json['name'] as String,
      polygon: (json['polygon'] as List)
          .map((p) => ZonePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      deliveryFee: json['delivery_fee'] as int,
      minOrderValue: json['min_order_value'] as int?,
      estimatedTime: json['estimated_time'] != null
          ? EstimatedTime.fromJson(json['estimated_time'])
          : null,
      color: json['color'] as String? ?? '#4CAF50',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'polygon': polygon.map((p) => p.toJson()).toList(),
      'delivery_fee': deliveryFee,
      if (minOrderValue != null) 'min_order_value': minOrderValue,
      if (estimatedTime != null) 'estimated_time': estimatedTime!.toJson(),
      'color': color,
    };
  }

  /// Retorna taxa em reais
  double get deliveryFeeInReais => deliveryFee / 100.0;

  /// Retorna valor mínimo em reais
  double? get minOrderValueInReais =>
      minOrderValue != null ? minOrderValue! / 100.0 : null;
}

/// Configuração de Zonas Customizadas
class CustomZonesConfig {
  final List<CustomZone> zones;

  CustomZonesConfig({
    required this.zones,
  });

  factory CustomZonesConfig.fromJson(Map<String, dynamic> json) {
    return CustomZonesConfig(
      zones: (json['zones'] as List)
          .map((z) => CustomZone.fromJson(z as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'zones': zones.map((z) => z.toJson()).toList(),
    };
  }
}
