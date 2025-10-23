import 'package:dio/dio.dart';
import 'package:totem/models/product.dart';

import 'category.dart';
import 'image_model.dart';


class BannerModel {
  const BannerModel({
    this.id,
    this.startDate,
    this.endDate,
    this.product,
    this.category,
    this.image,
    this.position = 1,
    this.linkUrl,
    this.isActive = true,
  });

  final int? id;
  final Product? product;
  final Category? category;
  final ImageModel? image;
  final int position;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? linkUrl;

  factory BannerModel.fromJson(Map<String, dynamic> map) {
    return BannerModel(
      id: map['id'] as int?,
      linkUrl: map['link_url'] as String?, // Pode ser null

      product: map['product'] != null ? Product.fromJson(map['product']) : null,
      category: map['category'] != null ? Category.fromJson(map['category']) : null,

      image: map['image_path'] != null
          ? ImageModel(url: map['image_path'] as String)
          : null,

      position: map['position'] as int? ?? 1,

      isActive: map['is_active'] as bool? ?? true,

      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'])
          : null,

      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'])
          : null,
    );
  }



}
