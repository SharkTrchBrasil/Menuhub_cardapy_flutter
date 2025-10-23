import 'package:flutter/cupertino.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/models/rating.dart';
import 'package:totem/models/rating_summary.dart';
import 'package:totem/models/store_city.dart';
import 'package:totem/models/store_neig.dart';
import 'package:totem/models/store_operation_config.dart';
import '../core/extensions.dart';
import 'delivery_options.dart';
import 'image_model.dart';

import 'store_hour.dart';

class Store {
  Store( {
    this.id,
    this.name = '',
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


  });

  final int? id;
  final String name;
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


  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as int?,
      name: json['name'] ?? '',
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
      image: ImageModel(url: json['image_path']),
      banner: ImageModel(url: json['banner_path']),
      paymentMethodGroups: (json['payment_method_groups'] as List<dynamic>?)
        ?.map((e) => PaymentMethodGroup.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
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
          .toList() ?? [],




    );
  }


}
