/// Order Model - Menuhub Format (DEFINITIVO)
///
/// Modelo Dart que corresponde 100% ao OrderResponse do backend.
/// Valores monetários em CENTAVOS (int).
library;

import 'package:totem/core/helpers/money_amount_helper.dart';

// ==========================================
// COORDINATES
// ==========================================

class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates({required this.latitude, required this.longitude});

  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}

// ==========================================
// ADDRESS
// ==========================================

class Address {
  final String city;
  final String country;
  final String neighborhood;
  final String state;
  final String streetName;
  final String? streetNumber;
  final Coordinates? coordinates;
  final String? complement;
  final String? reference;
  final String? zipCode;

  Address({
    required this.city,
    this.country = 'BR',
    required this.neighborhood,
    required this.state,
    required this.streetName,
    this.streetNumber,
    this.coordinates,
    this.complement,
    this.reference,
    this.zipCode,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      city: json['city'] ?? '',
      country: json['country'] ?? 'BR',
      neighborhood: json['neighborhood'] ?? '',
      state: json['state'] ?? '',
      streetName: json['streetName'] ?? '',
      streetNumber: json['streetNumber'],
      coordinates:
          json['coordinates'] != null
              ? Coordinates.fromJson(json['coordinates'])
              : null,
      complement: json['complement'],
      reference: json['reference'],
      zipCode: json['zipCode'],
    );
  }

  /// Endereço formatado para exibição
  String get formatted {
    var addr = streetName;
    if (streetNumber != null) addr += ', $streetNumber';
    if (complement != null && complement!.isNotEmpty) addr += ' - $complement';
    addr += '\n$neighborhood, $city - $state';
    return addr;
  }
}

// ==========================================
// DELIVERY
// ==========================================

class EstimatedTimeOfArrival {
  final DateTime deliversAt;
  final DateTime? updatedAt;
  final DateTime? deliversEndAt;

  EstimatedTimeOfArrival({
    required this.deliversAt,
    this.updatedAt,
    this.deliversEndAt,
  });

  factory EstimatedTimeOfArrival.fromJson(Map<String, dynamic> json) {
    return EstimatedTimeOfArrival(
      deliversAt: DateTime.parse(json['deliversAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      deliversEndAt:
          json['deliversEndAt'] != null
              ? DateTime.parse(json['deliversEndAt'])
              : null,
    );
  }
}

class Delivery {
  final Address address;
  final EstimatedTimeOfArrival? estimatedTimeOfArrival;
  final DateTime? expectedDeliveryTime;
  final int? expectedDuration; // Em segundos
  final DateTime? expectedDeliveryTimeEnd;
  final bool isFullService;

  Delivery({
    required this.address,
    this.estimatedTimeOfArrival,
    this.expectedDeliveryTime,
    this.expectedDuration,
    this.expectedDeliveryTimeEnd,
    this.isFullService = false,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    // Handle both 'address' (full format) and 'deliveryAddress' (simplified format)
    final addressJson = json['address'] ?? json['deliveryAddress'];

    return Delivery(
      address:
          addressJson != null
              ? Address.fromJson(addressJson)
              : Address(
                streetName: '',
                city: '',
                state: '',
                country: 'BR',
                neighborhood: '',
              ),
      estimatedTimeOfArrival:
          json['estimatedTimeOfArrival'] != null
              ? EstimatedTimeOfArrival.fromJson(json['estimatedTimeOfArrival'])
              : null,
      expectedDeliveryTime:
          json['expectedDeliveryTime'] != null
              ? DateTime.parse(json['expectedDeliveryTime'])
              : (json['deliveryDateTime'] != null
                  ? DateTime.parse(json['deliveryDateTime'])
                  : null),
      expectedDuration: json['expectedDuration'],
      expectedDeliveryTimeEnd:
          json['expectedDeliveryTimeEnd'] != null
              ? DateTime.parse(json['expectedDeliveryTimeEnd'])
              : null,
      isFullService: json['isFullService'] ?? false,
    );
  }
}

// ==========================================
// MERCHANT
// ==========================================

class Merchant {
  final String id;
  final String name;
  final Address? address;
  final String? logo;
  final String type;
  final String? phoneNumber;

  Merchant({
    required this.id,
    required this.name,
    this.address,
    this.logo,
    this.type = 'RESTAURANT',
    this.phoneNumber,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Loja',
      address:
          json['address'] != null ? Address.fromJson(json['address']) : null,
      logo: json['logo'],
      type: json['type'] ?? 'RESTAURANT',
      phoneNumber: json['phoneNumber'],
    );
  }
}

// ==========================================
// PAYMENTS
// ==========================================

class PaymentMethodInfo {
  final String name;
  final String description;

  PaymentMethodInfo({required this.name, required this.description});

  factory PaymentMethodInfo.fromJson(Map<String, dynamic> json) {
    return PaymentMethodInfo(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }

  /// Nome amigável em português
  String get displayName {
    switch (name.toUpperCase()) {
      case 'CASH':
        return 'Dinheiro';
      case 'CREDIT':
        return 'Crédito';
      case 'DEBIT':
        return 'Débito';
      case 'PIX':
        return 'PIX';
      default:
        return description.isNotEmpty ? description : name;
    }
  }
}

class PaymentType {
  final String name;
  final String description;

  PaymentType({required this.name, required this.description});

  factory PaymentType.fromJson(Map<String, dynamic> json) {
    return PaymentType(
      name: json['name'] ?? 'OFFLINE',
      description: json['description'] ?? '',
    );
  }

  bool get isOnline => name.toUpperCase() == 'ONLINE';
}

class PaymentBrand {
  final String? id;
  final String? image;
  final String name;
  final String description;

  PaymentBrand({
    this.id,
    this.image,
    required this.name,
    required this.description,
  });

  factory PaymentBrand.fromJson(Map<String, dynamic> json) {
    return PaymentBrand(
      id: json['id'],
      image: json['image'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class MoneyAmount {
  final String currency;
  final int value; // EM CENTAVOS

  MoneyAmount({this.currency = 'BRL', required this.value});

  factory MoneyAmount.fromJson(dynamic json) {
    if (json is MoneyAmount) return json;
    if (json == null) return MoneyAmount(value: 0);

    // Helper removed as logic is inline now, or we can keep it if reused
    // But for cleaner swap, let's use the explicit logic

    if (json is int) {
      return MoneyAmount(value: json);
    }
    if (json is double) {
      return MoneyAmount(value: (json * 100).toInt());
    }
    if (json is String) {
      if (json.contains('.')) {
        return MoneyAmount(value: ((double.tryParse(json) ?? 0) * 100).toInt());
      }
      return MoneyAmount(value: int.tryParse(json) ?? 0);
    }

    if (json is Map) {
      int safeVal = 0;
      final rawVal = json['value'];
      if (rawVal is int)
        safeVal = rawVal;
      else if (rawVal is double)
        safeVal = (rawVal * 100).toInt();
      else if (rawVal is String) {
        if (rawVal.contains('.')) {
          safeVal = ((double.tryParse(rawVal) ?? 0) * 100).toInt();
        } else {
          safeVal = int.tryParse(rawVal) ?? 0;
        }
      }

      return MoneyAmount(currency: json['currency'] ?? 'BRL', value: safeVal);
    }

    return MoneyAmount(value: 0);
  }

  /// Valor em reais (double)
  double get inReais => value / 100.0;

  /// Valor formatado para exibição
  String get formatted =>
      'R\$ ${inReais.toStringAsFixed(2).replaceAll('.', ',')}';
}

class CashPayment {
  final MoneyAmount changeFor;

  CashPayment({required this.changeFor});

  factory CashPayment.fromJson(Map<String, dynamic> json) {
    return CashPayment(changeFor: MoneyAmount.fromJson(json['changeFor']));
  }
}

class PaymentMethod {
  final String id;
  final PaymentMethodInfo method;
  final PaymentType type;
  final PaymentBrand? brand;
  final CashPayment? cash;
  final MoneyAmount amount;
  final List<dynamic> transactions;

  PaymentMethod({
    required this.id,
    required this.method,
    required this.type,
    this.brand,
    this.cash,
    required this.amount,
    this.transactions = const [],
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    // Helper handlers for mixed types (String vs Map)
    dynamic methodData = json['method'];
    PaymentMethodInfo method;
    if (methodData is String) {
      method = PaymentMethodInfo(name: methodData, description: methodData);
    } else if (methodData is Map) {
      method = PaymentMethodInfo.fromJson(
        Map<String, dynamic>.from(methodData),
      );
    } else {
      method = PaymentMethodInfo(name: 'UNKNOWN', description: '');
    }

    dynamic typeData = json['type'];
    PaymentType type;
    if (typeData is String) {
      type = PaymentType(name: typeData, description: typeData);
    } else if (typeData is Map) {
      type = PaymentType.fromJson(Map<String, dynamic>.from(typeData));
    } else {
      type = PaymentType(name: 'OFFLINE', description: '');
    }

    dynamic brandData = json['brand'];
    PaymentBrand? brand;
    if (brandData is String) {
      brand = PaymentBrand(name: brandData, description: brandData);
    } else if (brandData is Map) {
      brand = PaymentBrand.fromJson(Map<String, dynamic>.from(brandData));
    }

    return PaymentMethod(
      id: json['id']?.toString() ?? '',
      method: method,
      type: type,
      brand: brand,
      cash: json['cash'] != null ? CashPayment.fromJson(json['cash']) : null,
      amount: MoneyAmount.fromJson(json['amount']),
      transactions: json['transactions'] ?? [],
    );
  }

  /// Precisa de troco?
  bool get needsChange => cash != null && cash!.changeFor.value > 0;
}

class Payments {
  final List<PaymentMethod> methods;
  final MoneyAmount total;

  Payments({required this.methods, required this.total});

  factory Payments.fromJson(Map<String, dynamic> json) {
    return Payments(
      methods:
          (json['methods'] as List<dynamic>?)
              ?.map((e) => PaymentMethod.fromJson(e))
              .toList() ??
          [],
      total: MoneyAmount.fromJson(json['total']),
    );
  }

  /// Método de pagamento principal
  PaymentMethod? get primary => methods.isNotEmpty ? methods.first : null;
}

// ==========================================
// BAG / ITEMS
// ==========================================

class SubItem {
  final String id;
  final String? externalId;
  final String name;
  final int quantity;
  final List<String> tags;
  final int totalPrice; // EM CENTAVOS
  final int totalPriceWithDiscount;
  final int unitPrice;
  final int unitPriceWithDiscount;

  SubItem({
    required this.id,
    this.externalId,
    required this.name,
    this.quantity = 1,
    this.tags = const [],
    required this.totalPrice,
    required this.totalPriceWithDiscount,
    required this.unitPrice,
    required this.unitPriceWithDiscount,
  });

  factory SubItem.fromJson(Map<String, dynamic> json) {
    // Quantidade não é MoneyAmount, usa int direto
    int safeQuantity(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    return SubItem(
      id: json['id']?.toString() ?? '',
      externalId: json['externalId'],
      name: json['name'] ?? '',
      quantity: safeQuantity(json['quantity']),
      tags: List<String>.from(json['tags'] ?? []),
      totalPrice:
          parseMoneyAmount(
            json['totalPrice'] ?? json['price'] ?? json['addition'],
          ) ??
          0,
      totalPriceWithDiscount:
          parseMoneyAmount(
            json['totalPriceWithDiscount'] ??
                json['totalPrice'] ??
                json['price'],
          ) ??
          0,
      unitPrice: parseMoneyAmount(json['unitPrice'] ?? json['price']) ?? 0,
      unitPriceWithDiscount:
          parseMoneyAmount(
            json['unitPriceWithDiscount'] ?? json['unitPrice'] ?? json['price'],
          ) ??
          0,
    );
  }

  /// Preço em reais
  double get priceInReais => totalPrice / 100.0;
}

class BagItem {
  final String id;
  final String uniqueId;
  final String? externalId;
  final String name;
  final String? description;
  final int quantity;
  final List<SubItem> subItems;
  final List<String> tags;
  final int totalPrice; // EM CENTAVOS
  final int totalPriceWithDiscount;
  final int unitPrice;
  final int unitPriceWithDiscount;
  final String? notes;
  final String? logoUrl;

  BagItem({
    required this.id,
    required this.uniqueId,
    this.externalId,
    required this.name,
    this.description,
    this.quantity = 1,
    this.subItems = const [],
    this.tags = const [],
    required this.totalPrice,
    required this.totalPriceWithDiscount,
    required this.unitPrice,
    required this.unitPriceWithDiscount,
    this.notes,
    this.logoUrl,
  });

  factory BagItem.fromJson(Map<String, dynamic> json) {
    // Quantidade não é MoneyAmount, usa int direto
    int safeQuantity(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    return BagItem(
      id: json['id']?.toString() ?? '',
      uniqueId: json['uniqueId']?.toString() ?? '',
      externalId: json['externalId'],
      name: json['name'] ?? '',
      description: json['description'],
      quantity: safeQuantity(json['quantity']),
      subItems:
          (json['subItems'] as List<dynamic>?)
              ?.map((e) => SubItem.fromJson(e))
              .toList() ??
          [],
      tags: List<String>.from(json['tags'] ?? []),
      totalPrice: parseMoneyAmount(json['totalPrice']) ?? 0,
      totalPriceWithDiscount:
          parseMoneyAmount(
            json['totalPriceWithDiscount'] ?? json['totalPrice'],
          ) ??
          0,
      unitPrice: parseMoneyAmount(json['unitPrice']) ?? 0,
      unitPriceWithDiscount:
          parseMoneyAmount(
            json['unitPriceWithDiscount'] ?? json['unitPrice'],
          ) ??
          0,
      notes: json['notes'],
      logoUrl: json['logoUrl'],
    );
  }

  /// Preço total em reais
  double get priceInReais => totalPrice / 100.0;

  /// Tem observações?
  bool get hasNotes => notes != null && notes!.isNotEmpty;
}

class DeliveryFee {
  final int value;
  final int valueWithDiscount;

  DeliveryFee({required this.value, required this.valueWithDiscount});

  factory DeliveryFee.fromJson(Map<String, dynamic> json) {
    return DeliveryFee(
      value: parseMoneyAmount(json['value']) ?? 0,
      valueWithDiscount:
          parseMoneyAmount(json['valueWithDiscount'] ?? json['value']) ?? 0,
    );
  }

  double get inReais => value / 100.0;
}

class BagTotal {
  final int value;
  final int valueWithDiscount;

  BagTotal({required this.value, required this.valueWithDiscount});

  factory BagTotal.fromJson(Map<String, dynamic> json) {
    return BagTotal(
      value: parseMoneyAmount(json['value']) ?? 0,
      valueWithDiscount:
          parseMoneyAmount(json['valueWithDiscount'] ?? json['value']) ?? 0,
    );
  }

  double get inReais => valueWithDiscount / 100.0;
}

class Bag {
  final List<dynamic> benefits;
  final DeliveryFee deliveryFee;
  final List<BagItem> items;
  final BagTotal subTotal;
  final BagTotal total;
  final bool updated;

  Bag({
    this.benefits = const [],
    required this.deliveryFee,
    required this.items,
    required this.subTotal,
    required this.total,
    this.updated = false,
  });

  factory Bag.fromJson(Map<String, dynamic> json) {
    return Bag(
      benefits: json['benefits'] ?? [],
      deliveryFee: DeliveryFee.fromJson(json['deliveryFee']),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => BagItem.fromJson(e))
              .toList() ??
          [],
      subTotal: BagTotal.fromJson(json['subTotal']),
      total: BagTotal.fromJson(json['total']),
      updated: json['updated'] ?? false,
    );
  }

  /// Quantidade total de itens
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}

// ==========================================
// DETAILS
// ==========================================

class Cancellation {
  final String code;
  final String reason;

  Cancellation({required this.code, required this.reason});

  factory Cancellation.fromJson(Map<String, dynamic> json) {
    return Cancellation(code: json['code'] ?? '', reason: json['reason'] ?? '');
  }
}

class OrderDetails {
  final String mode; // DELIVERY, TAKEOUT, DINE_IN
  final bool scheduled;
  final bool tippable;
  final bool indoorTipEnabled;
  final bool trackable;
  final bool boxable;
  final bool placedAtBox;
  final bool reviewed;
  final bool darkKitchen;
  final Cancellation? cancellation;

  OrderDetails({
    required this.mode,
    this.scheduled = false,
    this.tippable = false,
    this.indoorTipEnabled = false,
    this.trackable = false,
    this.boxable = false,
    this.placedAtBox = false,
    this.reviewed = false,
    this.darkKitchen = false,
    this.cancellation,
  });

  factory OrderDetails.fromJson(Map<String, dynamic> json) {
    return OrderDetails(
      mode: json['mode'] ?? 'DELIVERY',
      scheduled: json['scheduled'] ?? false,
      tippable: json['tippable'] ?? false,
      indoorTipEnabled: json['indoorTipEnabled'] ?? false,
      trackable: json['trackable'] ?? false,
      boxable: json['boxable'] ?? false,
      placedAtBox: json['placedAtBox'] ?? false,
      reviewed: json['reviewed'] ?? false,
      darkKitchen: json['darkKitchen'] ?? false,
      cancellation:
          json['cancellation'] != null
              ? Cancellation.fromJson(json['cancellation'])
              : null,
    );
  }

  bool get isDelivery => mode == 'DELIVERY';
  bool get isTakeout => mode == 'TAKEOUT';
  bool get isDineIn => mode == 'DINE_IN';
}

// ==========================================
// ORIGIN
// ==========================================

class Origin {
  final String platform;
  final String appName;
  final String? appVersion;

  Origin({required this.platform, required this.appName, this.appVersion});

  factory Origin.fromJson(Map<String, dynamic> json) {
    return Origin(
      platform: json['platform'] ?? 'WEB',
      appName: json['appName'] ?? 'Menuhub',
      appVersion: json['appVersion'],
    );
  }
}

// ==========================================
// DELIVERY METHOD
// ==========================================

class TimeSlot {
  final String id;
  final DateTime startDateTime;
  final DateTime endDateTime;

  TimeSlot({
    this.id = '',
    required this.startDateTime,
    required this.endDateTime,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: json['id'] ?? '',
      startDateTime: DateTime.parse(json['startDateTime']),
      endDateTime: DateTime.parse(json['endDateTime']),
    );
  }
}

class DeliveryMethod {
  final String id;
  final String mode;
  final TimeSlot? timeSlot;

  DeliveryMethod({this.id = 'DEFAULT', required this.mode, this.timeSlot});

  factory DeliveryMethod.fromJson(Map<String, dynamic> json) {
    return DeliveryMethod(
      id: json['id'] ?? 'DEFAULT',
      mode: json['mode'] ?? 'DELIVERY',
      timeSlot:
          json['timeSlot'] != null ? TimeSlot.fromJson(json['timeSlot']) : null,
    );
  }
}

// ==========================================
// FEE
// ==========================================

class Fee {
  final String id;
  final String title;
  final String? description;
  final String type;
  final MoneyAmount amount;

  Fee({
    required this.id,
    required this.title,
    this.description,
    this.type = 'UNKNOWN',
    required this.amount,
  });

  factory Fee.fromJson(Map<String, dynamic> json) {
    return Fee(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'UNKNOWN',
      amount: MoneyAmount.fromJson(json['amount']),
    );
  }
}

// ==========================================
// VERIFICATION CODE
// ==========================================

class VerificationCode {
  final String source;
  final String name;
  final String value;
  final bool required;

  VerificationCode({
    required this.source,
    required this.name,
    required this.value,
    this.required = false,
  });

  factory VerificationCode.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return VerificationCode(
        source: json['source'] ?? '',
        name: json['name'] ?? '',
        value: json['value'] ?? '',
        required: json['required'] ?? false,
      );
    }

    // Fallback for simple values (e.g. from legacy or special endpoint)
    final val = json?.toString() ?? '';
    return VerificationCode(
      source: 'legacy_or_simple',
      name: 'DELIVERY_CODE', // Assume default usage
      value: val,
      required: true,
    );
  }

  /// É código de entrega?
  bool get isDeliveryCode => name == 'DELIVERY_CODE';
}

// ==========================================
// CUSTOMER
// ==========================================

class Customer {
  final String? id;
  final String? name;
  final String? phone;
  final String? email;

  Customer({this.id, this.name, this.phone, this.email});

  factory Customer.fromJson(Map<String, dynamic> json) {
    // ✅ CORREÇÃO: phone pode vir como String ou como objeto {number: ...}
    String? phoneValue;
    final phoneData = json['phone'];
    if (phoneData is String) {
      phoneValue = phoneData;
    } else if (phoneData is Map) {
      phoneValue = phoneData['number']?.toString();
    }

    return Customer(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      phone: phoneValue,
      email: json['email']?.toString(),
    );
  }
}

// ==========================================
// ORDER (PRINCIPAL)
// ==========================================

class Order {
  // IDs
  final String id;
  final String shortId;
  final String orderNumber;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  // Status
  final String lastStatus;

  // Objetos
  final OrderDetails details;
  final Delivery delivery;
  final Merchant merchant;
  final Payments payments;
  final Bag bag;
  final Origin origin;
  final DeliveryMethod deliveryMethod;

  // Listas
  final List<Fee> fees;
  final List<VerificationCode> verificationCodes;

  // Extras
  final String salesChannel;
  final Customer? customer;

  Order({
    required this.id,
    required this.shortId,
    required this.orderNumber,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    required this.lastStatus,
    required this.details,
    required this.delivery,
    required this.merchant,
    required this.payments,
    required this.bag,
    required this.origin,
    required this.deliveryMethod,
    this.fees = const [],
    this.verificationCodes = const [],
    required this.salesChannel,
    this.customer,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // -------------------------------------------------------------------------
    // ADAPTADOR PARA PAYLOAD DO WEBSOCKET (order_created)
    // O backend pode enviar um payload simplificado no evento order_created.
    // Precisamos normalizar para o modelo completo.
    // -------------------------------------------------------------------------

    // 1. Normaliza Bag (pode vir como 'bag' ou 'items' + 'total')
    // Helper function para converter valores de preço para centavos de forma segura
    int toCents(dynamic value) {
      if (value == null) return 0;
      if (value is int) return (value * 100);
      if (value is double) return (value * 100).round();
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        return parsed != null ? (parsed * 100).round() : 0;
      }
      if (value is num) return (value * 100).round();
      return 0;
    }

    // Helper function para converter valores já em centavos (int) de forma segura
    int toSafeCents(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        return parsed?.round() ?? 0;
      }
      if (value is num) return value.round();
      return 0;
    }

    Map<String, dynamic> bagJson;
    if (json['bag'] != null) {
      bagJson = json['bag'];
    } else {
      // Reconstrói estrutura da Bag a partir do payload simplificado
      final rawItems = json['items'] as List<dynamic>? ?? [];
      final normalizedItems =
          rawItems.map((item) {
            return {
              'id': item['id']?.toString() ?? '',
              'uniqueId':
                  item['uniqueId']?.toString() ?? item['id']?.toString() ?? '',
              'name': item['name'] ?? '',
              'description': item['description'], // ✅ Mapeia descrição
              'quantity': item['quantity'] ?? 1,
              'unitPrice': toCents(item['unitPrice'] ?? item['price']),
              'totalPrice': toCents(item['totalPrice'] ?? item['price']),
              'totalPriceWithDiscount': toCents(
                item['totalPrice'] ?? item['price'],
              ),
              'unitPriceWithDiscount': toCents(
                item['unitPrice'] ?? item['price'],
              ),
              'subItems':
                  item['options'] ?? [], // Opções podem vir como subItems
              'logoUrl': item['imageUrl'], // ✅ Mapeia imageUrl para logoUrl
            };
          }).toList();

      final totalData = json['total'];
      bagJson = {
        'items': normalizedItems,
        'subTotal':
            totalData != null
                ? {
                  'value': toCents(totalData['subTotal']),
                  'valueWithDiscount': toCents(totalData['subTotal']),
                }
                : {'value': 0, 'valueWithDiscount': 0},
        'total':
            totalData != null
                ? {
                  'value': toCents(totalData['orderAmount']),
                  'valueWithDiscount': toCents(totalData['orderAmount']),
                }
                : {'value': 0, 'valueWithDiscount': 0},
        'deliveryFee':
            totalData != null
                ? {
                  'value': toCents(totalData['deliveryFee']),
                  'valueWithDiscount': toCents(totalData['deliveryFee']),
                }
                : {'value': 0, 'valueWithDiscount': 0},
        'updated': false,
        'benefits': [],
      };
    }

    // 2. Normaliza Details (se ausente)
    final detailsJson =
        json['details'] ??
        {
          'mode': json['orderType'] ?? 'DELIVERY',
          'scheduled': json['orderTiming'] == 'SCHEDULED',
          // Outros campos assumem default
        };

    // 3. Normaliza Origin (se ausente)
    final originJson =
        json['origin'] ?? {'platform': 'MENUHUB', 'appName': 'Menuhub'};

    // 4. Normaliza DeliveryMethod (se ausente)
    final deliveryMethodJson =
        json['deliveryMethod'] ?? {'mode': json['orderType'] ?? 'DELIVERY'};

    // 5. Normaliza Payments
    Map<String, dynamic> paymentsJson;
    if (json['payments'] != null &&
        json['payments']['methods'] != null &&
        json['payments']['methods'].isNotEmpty &&
        json['payments']['methods'][0]['method'] is Map) {
      // Já está no formato completo
      paymentsJson = json['payments'];
    } else {
      // Formato simplificado
      final rawPayments = json['payments'] ?? {};
      final rawMethods = rawPayments['methods'] as List<dynamic>? ?? [];

      final normalizedMethods =
          rawMethods.map((m) {
            return {
              'id': '1', // ID fictício
              'method': {
                'name': m['method'] ?? 'UNKNOWN',
                'description': m['method'] ?? 'UNKNOWN',
              },
              'type': {
                'name': m['type'] ?? 'OFFLINE',
                'description': m['type'] ?? 'OFFLINE',
              },
              'amount': {
                'value': toCents(m['value']),
                'currency': m['currency'] ?? 'BRL',
              },
              'cash':
                  m['cash'] != null
                      ? {
                        'changeFor': {
                          'value': toCents(m['cash']['changeFor']),
                          'currency': 'BRL',
                        },
                      }
                      : null,
              'transactions': [],
            };
          }).toList();

      // Calcula o total de forma segura
      final pendingValue = rawPayments['pending'];
      final prepaidValue = rawPayments['prepaid'];
      final pendingNum =
          pendingValue is num
              ? pendingValue.toDouble()
              : (double.tryParse(pendingValue?.toString() ?? '0') ?? 0);
      final prepaidNum =
          prepaidValue is num
              ? prepaidValue.toDouble()
              : (double.tryParse(prepaidValue?.toString() ?? '0') ?? 0);
      final totalValue = ((pendingNum + prepaidNum) * 100).round();

      paymentsJson = {
        'methods': normalizedMethods,
        'total': {'value': totalValue, 'currency': 'BRL'},
      };
    }

    return Order(
      id: json['id']?.toString() ?? '',
      shortId:
          json['shortId']?.toString() ?? json['displayId']?.toString() ?? '',
      orderNumber:
          json['orderNumber']?.toString() ??
          json['displayId']?.toString() ??
          '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : DateTime.parse(json['createdAt']),
      closedAt:
          json['closedAt'] != null ? DateTime.parse(json['closedAt']) : null,
      lastStatus: json['lastStatus'] ?? json['status'] ?? 'PENDING',
      details: OrderDetails.fromJson(detailsJson),
      delivery: Delivery.fromJson(
        json['delivery'] ??
            // Fallback para delivery vazio se necessário
            {
              'address': {
                'streetName': '',
                'city': '',
                'state': '',
                'country': 'BR',
                'neighborhood': '',
              },
            },
      ),
      merchant: Merchant.fromJson(json['merchant'] ?? {'id': '', 'name': ''}),
      payments: Payments.fromJson(paymentsJson),
      bag: Bag.fromJson(bagJson),
      origin: Origin.fromJson(originJson),
      deliveryMethod: DeliveryMethod.fromJson(deliveryMethodJson),
      fees:
          (json['fees'] as List<dynamic>?)
              ?.map((e) => Fee.fromJson(e))
              .toList() ??
          [],
      verificationCodes:
          (json['verificationCodes'] as List<dynamic>?)
              ?.map((e) => VerificationCode.fromJson(e))
              .toList() ??
          [],
      salesChannel: json['salesChannel'] ?? 'MENUHUB',
      customer:
          json['customer'] != null ? Customer.fromJson(json['customer']) : null,
    );
  }

  // ==========================================
  // HELPERS / GETTERS
  // ==========================================

  String get displayId => shortId;

  String get statusLabel {
    switch (lastStatus.toUpperCase()) {
      case 'PENDING':
        return 'Pendente';
      case 'CONFIRMED':
        return 'Confirmado';
      case 'PREPARING':
        return 'Preparando';
      case 'READY':
        return 'Pronto';
      case 'DISPATCHED':
        return 'Saiu para entrega';
      case 'CONCLUDED':
        return 'Concluído';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return lastStatus;
    }
  }

  String get orderStatus => lastStatus;
  bool get isDelivery => details.isDelivery;
  bool get isTakeout => details.isTakeout;
  bool get isCancelled => lastStatus.toUpperCase() == 'CANCELLED';
  bool get isConcluded => lastStatus.toUpperCase() == 'CONCLUDED';
  bool get isActive => !isCancelled && !isConcluded;

  String? get deliveryCode {
    final code = verificationCodes.firstWhere(
      (c) => c.isDeliveryCode,
      orElse: () => VerificationCode(source: '', name: '', value: ''),
    );
    return code.value.isNotEmpty ? code.value : null;
  }

  double get totalAmount => bag.total.inReais;
  double get subtotalAmount => bag.subTotal.inReais;
  double get deliveryFeeAmount => bag.deliveryFee.inReais;
  bool get needsChange => payments.primary?.needsChange ?? false;
  double? get changeFor {
    if (!needsChange) return null;
    return payments.primary!.cash!.changeFor.inReais;
  }

  List<BagItem> get items => bag.items;
  int get itemCount => bag.itemCount;
  String get formattedAddress => delivery.address.formatted;

  // ==========================================
  // COMPATIBILITY GETTERS
  // ==========================================

  String? get pickupCode {
    // Check verificationCodes for pickup code if available
    // For now returning null or mocking if needed
    return null;
  }

  double get discountAmount => bag.benefits.fold(
    0.0,
    (sum, b) => sum + (double.tryParse(b.toString()) ?? 0.0),
  );

  String get publicId => shortId;
  String? get sequentialId => orderNumber.isNotEmpty ? orderNumber : shortId;
  DateTime? get scheduledFor => details.scheduled ? DateTime.now() : null;

  String? get addressState => delivery.address.state;
  String? get addressZipCode => delivery.address.zipCode;

  OrderChargeCompatibility get charge => OrderChargeCompatibility(this);

  // Simplified logic for paymentStatus
  String get paymentStatus =>
      (payments.methods.isNotEmpty &&
                  payments.methods.any((m) => m.transactions.isNotEmpty)) ||
              payments.total.value > 0
          ? 'paid'
          : 'pending';

  String get deliveryType => details.mode.toLowerCase();

  List<BagItem> get products => bag.items;

  // Alias for changeAmount
  double? get changeAmount => changeFor;
}

// ==========================================
// COMPATIBILITY CLASSES & EXTENSIONS
// ==========================================

typedef OrderItem = BagItem;

class OrderChargeCompatibility {
  final Order _order;
  OrderChargeCompatibility(this._order);

  int get grandTotal => _order.payments.total.value;
  int get subtotal => _order.bag.subTotal.value;
  int get deliveryFee => _order.bag.deliveryFee.value;
  int get serviceFee => 0;
  int get amount => grandTotal; // ✅ Compatibility alias
}

// OrderProduct stub to satisfy legacy UI without importing full model if possible
// But UI expects List<OrderProduct> in OrderItemsList widget.
// We must adapt BagItem to look like OrderProduct or update OrderItemsList.
// Given OrderItemsList is a widget, it's better to update the widget or strict adherence?
// No, let's fix the call site in OrderDetailsPage to convert.

extension BagItemCompatibility on BagItem {
  String? get imageUrl => logoUrl;
  List<SubItem> get options => subItems;
  String? get observations => notes;
}

extension DeliveryCompatibility on Delivery {
  Address get deliveryAddress => address;
  String? get pickupCode => null;
}

extension PaymentsCompatibility on Payments {
  PaymentMethod? get primaryMethod => methods.isNotEmpty ? methods.first : null;
}

extension PaymentMethodCompatibility on PaymentMethod {
  String get displayName => method.displayName;
}

extension SubItemCompatibility on SubItem {
  double get price => priceInReais;
}
