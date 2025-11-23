import 'package:flutter/cupertino.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/models/rating.dart';
import 'package:totem/models/rating_summary.dart';
import 'package:totem/models/store_city.dart';
import 'package:totem/models/store_neig.dart';
import 'package:totem/models/store_operation_config.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/coupon.dart';
import 'package:totem/models/delivery_fee_rule.dart';
import 'package:totem/models/delivery_config.dart'; // ✅ NOVO
import '../core/extensions.dart';
import 'delivery_options.dart';
import 'image_model.dart';
import 'store_hour.dart';
import 'scheduled_pause.dart';

class Store {
  Store({
    this.id,
    this.name = '',
    this.urlSlug = '', // ✅ ADICIONADO
    this.phone = '',
    this.image,
    this.zip_code,
    this.street,
    this.number,
    this.neighborhood,
    this.complement,
    this.reference,
    this.city,
    this.state,
    this.instagram,
    this.facebook,
    this.banner,
    this.tiktok,
    this.description,
    this.paymentMethodGroups = const [],
    this.hours = const [],
    this.store_operation_config,
    this.ratingsSummary,
    this.cities = const [],
    this.categories = const [],
    this.scheduledPauses = const [],
    this.coupons = const [],
    this.deliveryFeeRules = const [],
    this.deliveryConfig, // ✅ NOVO v2.0
    this.latitude,
    this.longitude,
    this.deliveryRadiusKm,
    this.locale,
    this.currencyCode,
    this.timezone,
  });

  final int? id;
  final String name;
  final String urlSlug; // ✅ ADICIONADO
  final String phone;

  final String? zip_code;
  final String? street;
  final String? number;
  final String? neighborhood;
  final String? complement;
  final String? reference;
  final String? city;
  final String? state;
  final String? description;

  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final ImageModel? image;
  final ImageModel? banner;

  final List<PaymentMethodGroup> paymentMethodGroups;
  final List<StoreHour> hours;
  final StoreOperationConfig? store_operation_config;
  RatingsSummary? ratingsSummary;
  final List<StoreCity> cities;
  final List<Category> categories;
  final List<ScheduledPause> scheduledPauses;
  final List<Coupon> coupons;
  final List<DeliveryFeeRule> deliveryFeeRules;
  final DeliveryConfig? deliveryConfig; // ✅ NOVO v2.0

  // Coordenadas da loja (para cálculo de raio)
  final double? latitude;
  final double? longitude;
  final double? deliveryRadiusKm;

  // Internacionalização
  final String? locale;
  final String? currencyCode;
  final String? timezone;

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as int?,
      name: json['name'] ?? '',
      urlSlug: json['url_slug'] ?? '', // ✅ ADICIONADO O PARSE
      phone: json['phone'] ?? '',
      zip_code: json['zip_code'],
      street: json['street'],
      number: json['number'],
      neighborhood: json['neighborhood'],
      complement: json['complement'],
      reference: json['reference'],
      city: json['city'],
      state: json['state'],
      instagram: json['instagram'],
      facebook: json['facebook'],
      tiktok: json['tiktok'],
      description: json['description'],
      image: json['image_path'] != null
          ? ImageModel(url: json['image_path'] as String)
          : null,
      banner: json['banner_path'] != null
          ? ImageModel(url: json['banner_path'] as String)
          : null,
      paymentMethodGroups: (json['payment_method_groups'] as List<dynamic>?)
          ?.map((e) => PaymentMethodGroup.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      hours: (json['hours'] as List<dynamic>?)
          ?.map((e) => StoreHour.fromJson(e))
          .toList() ??
          [],
      store_operation_config: json['store_operation_config'] != null
          ? StoreOperationConfig.fromJson(json['store_operation_config'])
          : null,
      ratingsSummary: json['ratingsSummary'] != null
          ? RatingsSummary.fromMap(json['ratingsSummary'])
          : null,
      cities: (json['cities'] as List<dynamic>?)
          ?.map((e) => StoreCity.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      scheduledPauses: (json['scheduled_pauses'] as List<dynamic>?)
          ?.map((e) => ScheduledPause.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      coupons: (json['coupons'] as List<dynamic>?)
          ?.map((e) => Coupon.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      deliveryFeeRules: (json['delivery_fee_rules'] as List<dynamic>?)
          ?.map((e) => DeliveryFeeRule.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      deliveryConfig: json['delivery_config'] != null
          ? DeliveryConfig.fromJson(json['delivery_config'] as Map<String, dynamic>)
          : null, // ✅ NOVO v2.0
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      deliveryRadiusKm: (json['delivery_radius_km'] as num?)?.toDouble(),
      locale: json['locale'] as String?,
      currencyCode: json['currency_code'] as String?,
      timezone: json['timezone'] as String?,
    );
  }

  Store copyWith({
    int? id,
    String? name,
    String? urlSlug,
    String? phone,
    String? zip_code,
    String? street,
    String? number,
    String? neighborhood,
    String? complement,
    String? reference,
    String? city,
    String? state,
    String? description,
    String? instagram,
    String? facebook,
    String? tiktok,
    ImageModel? image,
    ImageModel? banner,
    List<PaymentMethodGroup>? paymentMethodGroups,
    List<StoreHour>? hours,
    StoreOperationConfig? store_operation_config,
    RatingsSummary? ratingsSummary,
    List<StoreCity>? cities,
    List<Category>? categories,
    List<ScheduledPause>? scheduledPauses,
    List<Coupon>? coupons,
    List<DeliveryFeeRule>? deliveryFeeRules,
    DeliveryConfig? deliveryConfig, // ✅ NOVO v2.0
    double? latitude,
    double? longitude,
    double? deliveryRadiusKm,
    String? locale,
    String? currencyCode,
    String? timezone,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      urlSlug: urlSlug ?? this.urlSlug,
      phone: phone ?? this.phone,
      zip_code: zip_code ?? this.zip_code,
      street: street ?? this.street,
      number: number ?? this.number,
      neighborhood: neighborhood ?? this.neighborhood,
      complement: complement ?? this.complement,
      reference: reference ?? this.reference,
      city: city ?? this.city,
      state: state ?? this.state,
      description: description ?? this.description,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      tiktok: tiktok ?? this.tiktok,
      image: image ?? this.image,
      banner: banner ?? this.banner,
      paymentMethodGroups: paymentMethodGroups ?? this.paymentMethodGroups,
      hours: hours ?? this.hours,
      store_operation_config: store_operation_config ?? this.store_operation_config,
      ratingsSummary: ratingsSummary ?? this.ratingsSummary,
      cities: cities ?? this.cities,
      categories: categories ?? this.categories,
      scheduledPauses: scheduledPauses ?? this.scheduledPauses,
      coupons: coupons ?? this.coupons,
      deliveryFeeRules: deliveryFeeRules ?? this.deliveryFeeRules,
      deliveryConfig: deliveryConfig ?? this.deliveryConfig, // ✅ NOVO v2.0
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
      locale: locale ?? this.locale,
      currencyCode: currencyCode ?? this.currencyCode,
      timezone: timezone ?? this.timezone,
    );
  }
}