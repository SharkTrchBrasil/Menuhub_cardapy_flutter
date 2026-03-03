// lib/models/category.dart

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/product_category_link.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/models/availability_model.dart';

enum CategoryType {
  GENERAL,
  CUSTOMIZABLE,
  UNKNOWN;

  static CategoryType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'GENERAL':
        return CategoryType.GENERAL;
      case 'CUSTOMIZABLE':
        return CategoryType.CUSTOMIZABLE;
      default:
        return CategoryType.UNKNOWN;
    }
  }

  String toApiString() => name;
}

class Category extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final int priority;
  final bool isActive;
  final CategoryType type;
  final ImageModel? image;
  final List<OptionGroup> optionGroups;
  final List<ProductCategoryLink> productLinks;
  // ✅ NOVOS CAMPOS: Disponibilidade e horários
  final AvailabilityType availabilityType;
  final List<ScheduleRule> schedules;
  // ✅ NOVO: Mapa de optionGroups por produto (para pizzas com múltiplos choices)
  // productId -> List<OptionGroup> (choices específicos de cada tamanho)
  final Map<int, List<OptionGroup>>? productOptionGroups;

  const Category({
    this.id,
    required this.name,
    this.description,
    required this.priority,
    required this.isActive,
    this.type = CategoryType.GENERAL,
    this.image,
    this.optionGroups = const [],
    this.productLinks = const [],
    this.availabilityType = AvailabilityType.always,
    this.schedules = const [],
    this.productOptionGroups,
  });

  bool get isCustomizable => type == CategoryType.CUSTOMIZABLE;

  Category copyWith({
    int? id,
    String? name,
    String? description,
    int? priority,
    bool? isActive,
    CategoryType? type,
    ImageModel? image,
    List<OptionGroup>? optionGroups,
    List<ProductCategoryLink>? productLinks,
    Map<int, List<OptionGroup>>? productOptionGroups,
    // ✅ FIX: campos faltantes que eram silenciosamente resetados a cada copyWith
    AvailabilityType? availabilityType,
    List<ScheduleRule>? schedules,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      type: type ?? this.type,
      image: image ?? this.image,
      optionGroups: optionGroups ?? this.optionGroups,
      productLinks: productLinks ?? this.productLinks,
      productOptionGroups: productOptionGroups ?? this.productOptionGroups,
      availabilityType: availabilityType ?? this.availabilityType,
      schedules: schedules ?? this.schedules,
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    // ✅ CRITICAL FIX: Garante que json é um Map Dart puro (não JS Proxy)
    // Em Flutter Web, objetos vindos do socket podem ser JS Proxy que passam
    // o teste `is Map<String, dynamic>` mas falham ao acessar propriedades.
    Map<String, dynamic> safeJson;
    try {
      // Ponte JSON: força conversão para tipos Dart puros
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded);
      safeJson =
          decoded is Map<String, dynamic>
              ? decoded
              : Map<String, dynamic>.from(decoded as Map);
    } catch (e) {
      // Fallback: tenta conversão manual
      safeJson = Map<String, dynamic>.from(json);
    }

    // ✅ Parse de availability_type robusto
    AvailabilityType availabilityType = AvailabilityType.always;
    try {
      if (safeJson['availability_type'] != null) {
        final typeStr = safeJson['availability_type'].toString().toUpperCase();
        if (typeStr == 'SCHEDULED') {
          availabilityType = AvailabilityType.scheduled;
        } else if (typeStr == 'ALWAYS') {
          availabilityType = AvailabilityType.always;
        }
      }
    } catch (e) {
      // Ignora erro de parse e mantem default
    }

    // ✅ Parse de schedules
    List<ScheduleRule> schedules = [];
    try {
      if (safeJson['schedules'] != null && safeJson['schedules'] is List) {
        schedules =
            (safeJson['schedules'] as List<dynamic>)
                .map(
                  (scheduleJson) => ScheduleRule.fromJson(
                    scheduleJson as Map<String, dynamic>,
                  ),
                )
                .toList();
      }
    } catch (e) {
      // Ignora erro de parse
    }

    // ✅ Detecta tipo da categoria
    CategoryType categoryType = CategoryType.GENERAL;
    try {
      if (safeJson['type'] != null) {
        categoryType = CategoryType.fromString(safeJson['type'].toString());
      }
    } catch (e) {
      // Mantem general
    }

    // ✅ Se não tiver tipo definido, tenta detectar pelo nome (para compatibilidade com formato antigo)
    if (categoryType == CategoryType.UNKNOWN ||
        categoryType == CategoryType.GENERAL) {
      final categoryName = (safeJson['name']?.toString() ?? '').toLowerCase();
      // Detecta categorias de pizza pelo nome
      if (categoryName.contains('pizza') || categoryName.contains('pizzas')) {
        categoryType = CategoryType.CUSTOMIZABLE;
      }
    }

    // ✅ Parse de imagem (suporte a image object ou image_path string)
    ImageModel? imageModel;
    if (safeJson['image'] != null && safeJson['image'] is Map) {
      imageModel = ImageModel.fromJson(safeJson['image']);
    } else if (safeJson['image_path'] != null &&
        safeJson['image_path'].toString().isNotEmpty) {
      imageModel = ImageModel(url: safeJson['image_path'].toString());
    }

    // ✅ Parse de productOptionGroups — com ponte JSON para evitar JS Proxy
    Map<int, List<OptionGroup>>? productOptionGroups;
    try {
      if (safeJson['product_option_groups'] != null &&
          safeJson['product_option_groups'] is Map) {
        productOptionGroups = {};
        (safeJson['product_option_groups'] as Map).forEach((key, value) {
          final productId = int.tryParse(key.toString());
          if (productId == null) return;

          // Garante que value é uma lista pura do Dart (sem JS Proxy)
          List<dynamic> rawList;
          try {
            // Ponte JSON: serializa e deserializa para garantir tipos puros
            final encoded = jsonEncode(value);
            final decoded = jsonDecode(encoded);
            rawList = decoded is List ? decoded : [];
          } catch (_) {
            rawList = value is List ? value : [];
          }

          final groups = <OptionGroup>[];
          for (final v in rawList) {
            try {
              final Map<String, dynamic> groupMap;
              if (v is Map<String, dynamic>) {
                groupMap = v;
              } else if (v is Map) {
                groupMap = Map<String, dynamic>.from(
                  v.map((k, val) => MapEntry(k.toString(), val)),
                );
              } else {
                continue;
              }
              groups.add(OptionGroup.fromJson(groupMap));
            } catch (eg) {
              // Skip individual bad group — não quebra o mapa todo
            }
          }

          if (groups.isNotEmpty) {
            productOptionGroups![productId] = groups;
          }
        });

        // Se o mapeamento resultou vazio, mantém null (o rebuild local pode tentar)
        if (productOptionGroups.isEmpty) {
          productOptionGroups = null;
        }
      }
    } catch (e) {
      // Ignora erro de parse — rebuild local será tentado pelo realtime_repository
      productOptionGroups = null;
    }

    // ✅ Parse de option_groups com guard por item (proteção contra JS Proxy)
    final List<OptionGroup> parsedOptionGroups = [];
    try {
      final rawGroups = safeJson['option_groups'];
      if (rawGroups is List) {
        for (final groupJson in rawGroups) {
          try {
            if (groupJson is Map<String, dynamic>) {
              parsedOptionGroups.add(OptionGroup.fromJson(groupJson));
            } else if (groupJson is Map) {
              // JS Proxy remnant — tenta converter
              final converted = Map<String, dynamic>.from(
                groupJson.map((k, v) => MapEntry(k.toString(), v)),
              );
              parsedOptionGroups.add(OptionGroup.fromJson(converted));
            }
          } catch (e) {
            // Skip individual bad group
          }
        }
      }
    } catch (e) {
      // Ignora erro de parse dos grupos
    }

    // ✅ Parse de product_links com guard por item
    final List<ProductCategoryLink> parsedProductLinks = [];
    try {
      final rawLinks = safeJson['product_links'];
      if (rawLinks is List) {
        for (final linkJson in rawLinks) {
          try {
            if (linkJson is Map<String, dynamic>) {
              parsedProductLinks.add(ProductCategoryLink.fromJson(linkJson));
            } else if (linkJson is Map) {
              final converted = Map<String, dynamic>.from(
                linkJson.map((k, v) => MapEntry(k.toString(), v)),
              );
              parsedProductLinks.add(ProductCategoryLink.fromJson(converted));
            }
          } catch (e) {
            // Skip individual bad link
          }
        }
      }
    } catch (e) {
      // Ignora erro de parse dos links
    }

    return Category(
      id:
          safeJson['id'] is int
              ? safeJson['id']
              : int.tryParse(safeJson['id']?.toString() ?? '0'),
      name: safeJson['name']?.toString() ?? '',
      description: safeJson['description']?.toString(),
      priority:
          safeJson['priority'] is int
              ? safeJson['priority']
              : (int.tryParse(safeJson['priority']?.toString() ?? '0') ?? 0),
      isActive:
          safeJson['is_active'] == true ||
          safeJson['is_active'] == 1, // Suporte a bool ou int
      type: categoryType,
      image: imageModel,
      optionGroups: parsedOptionGroups,
      productLinks: parsedProductLinks,
      availabilityType: availabilityType,
      schedules: schedules,
      productOptionGroups: productOptionGroups,
    );
  }

  const Category.empty()
    : id = 0,
      name = '',
      description = null,
      priority = 0,
      isActive = false,
      type = CategoryType.UNKNOWN,
      image = null,
      optionGroups = const [],
      productLinks = const [],
      availabilityType = AvailabilityType.always,
      schedules = const [],
      productOptionGroups = null;

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    isActive,
    optionGroups,
    productLinks,
    availabilityType,
    schedules,
    productOptionGroups,
  ];
}
