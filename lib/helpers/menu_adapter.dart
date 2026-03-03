// lib/helpers/menu_adapter.dart
// Adapter para converter o novo formato de menu para os models existentes do Totem

import 'package:totem/models/menu/menu_response.dart';
import 'package:totem/models/menu/menu_category.dart';
import 'package:totem/models/menu/menu_item.dart';
import 'package:totem/models/menu/menu_choice.dart';
import 'package:totem/models/menu/garnish_item.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/core/enums/available_type.dart';
import 'package:totem/helpers/enums/product_status.dart';
import 'package:totem/helpers/enums/product_type.dart';
// ✅ CORREÇÃO BUG #1: Imports para converter choices -> variantLinks
import 'package:totem/models/product_variant_link.dart';
import 'package:totem/models/variant.dart';
import 'package:totem/models/variant_option.dart';
import 'package:totem/helpers/enums/displaymode.dart';

import '../models/product_category_link.dart';

/// Adapter para converter MenuResponse para models existentes do Totem
class MenuAdapter {
  /// Helper para converter código (pode ser ID numérico ou UUID) em ID inteiro
  /// ✅ CORREÇÃO: Backend envia IDs como strings numéricas ("1", "2", etc)
  /// Precisamos verificar se é número antes de tentar tratar como UUID
  static int _codeToInt(String code) {
    // ✅ PRIMEIRO: Tenta parsear como número simples
    // Backend envia IDs numéricos do banco como strings ("1", "2", "3")
    final parsed = int.tryParse(code);
    if (parsed != null) {
      return parsed;
    }

    // Se não for número, trata como UUID
    final cleanUuid = code.replaceAll('-', '');
    // Usa os primeiros 8 caracteres hexadecimais, mas garante que seja válido
    if (cleanUuid.length >= 8) {
      final hexString = cleanUuid.substring(0, 8);
      return int.tryParse(hexString, radix: 16) ?? cleanUuid.hashCode.abs();
    }
    // Se não tiver 8 caracteres, usa hash code completo
    return cleanUuid.hashCode.abs();
  }

  /// Converte MenuResponse para lista de Category e Product
  /// ✅ IMPORTANTE: Produtos com preço zero são filtrados (considerados pausados)
  static MenuAdapterResult convertMenuResponse(MenuResponse menuResponse) {
    final List<Category> categories = [];
    final List<Product> products = [];

    for (final menuCategory in menuResponse.data.menu) {
      // Converte MenuCategory para Category
      final category = _convertMenuCategory(menuCategory);
      categories.add(category);

      // Converte MenuItem para Product
      for (final menuItem in menuCategory.itens) {
        // ✅ EXIBIÇÃO FIEL: O Totem não filtra produtos por preço.
        // Confiamos na lógica do Back-end que já decide o que deve ou não ser enviado.

        final product = _convertMenuItem(menuItem, category);
        products.add(product);
      }
    }

    return MenuAdapterResult(
      categories: categories, // Retorna todas as categorias processadas
      products: products,
    );
  }

  /// Converte MenuCategory para Category
  static Category _convertMenuCategory(MenuCategory menuCategory) {
    // Determina o tipo da categoria baseado no template
    CategoryType categoryType = CategoryType.GENERAL;
    if (menuCategory.template == 'pizza') {
      categoryType = CategoryType.CUSTOMIZABLE;
    }

    // ✅ NOVO: Mapeia max_flavors por tamanho para dividir preços corretamente
    // Cria um mapa: tamanho_id -> max_flavors
    final Map<int, int> sizeMaxFlavorsMap = {};
    for (final item in menuCategory.itens) {
      final sizeId = _codeToInt(item.id);
      // ✅ FIX: Extrai max_flavors do NOME (regex), NÃO do productInfo.quantity.
      // productInfo.quantity contém PEDAÇOS (slices), não sabores.
      // Ex: "MÉDIA 3 SABORES (6 PEDAÇOS)" → productInfo.quantity=6 (pedaços), sabores=3
      int? maxFlavors;
      final regex = RegExp(r'(\d+)\s*SABORES?', caseSensitive: false);
      final match = regex.firstMatch(item.description);
      if (match != null) {
        maxFlavors = int.tryParse(match.group(1)!);
      }
      if (maxFlavors != null && maxFlavors > 0) {
        sizeMaxFlavorsMap[sizeId] = maxFlavors;
      }
    }

    // ✅ FORMATO CANÔNICO: Usa product_option_groups do backend se disponível
    // O backend injeta 1 grupo TOPPING raw (com prices_by_size) por tamanho.
    // Isso garante formato idêntico entre carga inicial e category_updated.
    // Fallback: converte choices (formato legado) se o backend não enviou.
    Map<int, List<OptionGroup>> productOptionGroupsMap = {};
    final categoryId = _codeToInt(menuCategory.code);

    if (menuCategory.productOptionGroups != null &&
        menuCategory.productOptionGroups!.isNotEmpty) {
      // ✅ CANÔNICO: Parseia product_option_groups do backend
      print(
        '🔍 [MenuAdapter] product_option_groups recebido: ${menuCategory.productOptionGroups!.length} chaves',
      );
      menuCategory.productOptionGroups!.forEach((key, value) {
        final productId = int.tryParse(key.toString());
        if (productId == null) return;
        if (value is! List) return;

        final groups = <OptionGroup>[];
        for (final v in value) {
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
            final group = OptionGroup.fromJson(groupMap);
            groups.add(group);
            print(
              '   ✅ Grupo ${group.groupType} "${group.name}": ${group.items.length} items',
            );
          } catch (e) {
            print('   ❌ Erro ao parsear grupo: $e');
            // Skip bad group
          }
        }
        if (groups.isNotEmpty) {
          productOptionGroupsMap[productId] = groups;
        }
      });
    } else {
      // ✅ FALLBACK LEGADO: Converte choices em OptionGroups
      for (final item in menuCategory.itens) {
        if (item.choices != null && item.choices!.isNotEmpty) {
          final baseItemId = _codeToInt(item.id);
          final itemProductId = item.linkedProductId ?? baseItemId;

          final List<OptionGroup> itemOptionGroups = [];
          for (final choice in item.choices!) {
            final optionGroup = _convertMenuChoice(choice, null);
            itemOptionGroups.add(optionGroup);
          }

          if (itemOptionGroups.isNotEmpty) {
            productOptionGroupsMap[itemProductId] = itemOptionGroups;
          }
        }
      }
    }

    // ✅ Para categorias CUSTOMIZABLE, cria grupo de tamanhos a partir dos MenuItems
    // Para outras categorias, mantém a lógica antiga
    final List<OptionGroup> optionGroups = [];
    if (categoryType == CategoryType.CUSTOMIZABLE &&
        menuCategory.itens.isNotEmpty) {
      // ✅ NOVO: Cria grupo de tamanhos a partir dos MenuItems (cada MenuItem é um tamanho)
      final List<OptionItem> sizeItems = [];
      for (final item in menuCategory.itens) {
        final baseItemId = _codeToInt(item.id);
        final itemProductId =
            item.linkedProductId ?? baseItemId; // ✅ SIMPLIFICADO

        // Extrai informações do tamanho
        final sizeNameMatch = RegExp(
          r'^([A-ZÁÉÍÓÚÇ]+)',
        ).firstMatch(item.description);
        final sizeName = sizeNameMatch?.group(1) ?? item.description;

        // ✅ FIX: Extrai maxFlavors do NOME (regex), NÃO do productInfo.quantity.
        // productInfo.quantity contém PEDAÇOS (slices), não sabores.
        int? maxFlavors;
        final flavorsRegex = RegExp(r'(\d+)\s*SABORES?', caseSensitive: false);
        final flavorsMatch = flavorsRegex.firstMatch(item.description);
        if (flavorsMatch != null) {
          maxFlavors = int.tryParse(flavorsMatch.group(1)!);
        }

        // Extrai slices
        int? slices;
        final slicesMatch = RegExp(
          r'(\d+)\s*PEDAÇOS?',
          caseSensitive: false,
        ).firstMatch(item.description);
        if (slicesMatch != null) {
          slices = int.tryParse(slicesMatch.group(1)!);
        }

        // Converte logoUrl para ImageModel
        ImageModel? image;
        if (item.logoUrl != null && item.logoUrl!.isNotEmpty) {
          image = ImageModel(url: item.logoUrl!);
        }

        sizeItems.add(
          OptionItem(
            id: baseItemId, // ✅ CRÍTICO: ID real do tamanho de opção (511, 512, 513) para getPriceForSize
            name: item.description, // Nome completo do tamanho
            description: item.details,
            price: (item.unitMinPrice * 100).round(), // Preço em centavos
            isActive: true,
            image: image,
            maxFlavors: maxFlavors,
            slices: slices,
            linkedProductId:
                item.linkedProductId, // ✅ VITAL: ID do produto real no banco (274, 275, 276)
          ),
        );
      }

      if (sizeItems.isNotEmpty) {
        optionGroups.add(
          OptionGroup(
            id: 1, // ID fixo para grupo de tamanhos
            name: 'Tamanho',
            groupType: OptionGroupType.size,
            minSelection: 1,
            maxSelection: 1,
            items: sizeItems,
            displayOrder: 0,
            isActive: true,
          ),
        );
      }

      // Adiciona outros grupos de opções do primeiro item (sabores, massa, borda, etc.)
      final firstItem = menuCategory.itens.first;
      if (firstItem.choices != null && firstItem.choices!.isNotEmpty) {
        for (final choice in firstItem.choices!) {
          // Pula o grupo de tamanhos se existir (já criado acima)
          final optionGroup = _convertMenuChoice(choice, null);
          // Verifica se não é um grupo de tamanhos duplicado
          if (optionGroup.groupType != OptionGroupType.size) {
            optionGroups.add(optionGroup);
          }
        }
      }
    } else if (menuCategory.itens.isNotEmpty &&
        menuCategory.itens.first.choices != null) {
      // Para categorias normais, mantém a lógica antiga
      for (final choice in menuCategory.itens.first.choices!) {
        final optionGroup = _convertMenuChoice(choice, null);
        optionGroups.add(optionGroup);
      }
    }

    // Converte itens para productLinks (simplificado)
    final List<ProductCategoryLink> productLinks =
        menuCategory.itens.asMap().entries.map<ProductCategoryLink>((entry) {
          final index = entry.key;
          final item = entry.value;
          // ✅ SIMPLIFICADO: Usa linkedProductId se disponível
          final baseItemId = _codeToInt(item.id);
          final itemProductId = item.linkedProductId ?? baseItemId;
          return ProductCategoryLink(
            productId: itemProductId,
            categoryId: categoryId,
            price: (item.unitMinPrice * 100).round(), // Converte para centavos
            // ✅ Usa dados de promoção do item (vindos do backend)
            isOnPromotion: item.isOnPromotion,
            promotionalPrice:
                item.promotionalPrice != null
                    ? (item.promotionalPrice! * 100).round()
                    : null,
            isAvailable: true,
            isFeatured: false,
            displayOrder: index,
            availabilityType: AvailabilityType.always,
            schedules: const [],
          );
        }).toList();

    return Category(
      id: categoryId,
      name: menuCategory.name,
      description: null,
      priority: 0,
      isActive: true,
      type: categoryType,
      image: null,
      optionGroups:
          optionGroups, // ✅ Preenchido com os choices dos itens (referência)
      productLinks: productLinks,
      availabilityType: AvailabilityType.always,
      schedules: [],
      productOptionGroups:
          productOptionGroupsMap.isNotEmpty
              ? productOptionGroupsMap
              : null, // ✅ Choices específicos de cada tamanho
    );
  }

  /// Converte MenuItem para Product
  static Product _convertMenuItem(MenuItem menuItem, Category category) {
    // Determina se é customizável
    // Nota: ProductType.CUSTOMIZABLE não existe, usando INDIVIDUAL
    // A customização é gerenciada pela categoria (optionGroups)
    final ProductType productType = ProductType.INDIVIDUAL;

    // Converte preço de reais para centavos
    // ✅ CORREÇÃO: Usa unitMinPrice se unitPrice for 0 (caso das pizzas)
    double effectivePrice = menuItem.unitPrice;
    if (effectivePrice <= 0 && menuItem.unitMinPrice > 0) {
      effectivePrice = menuItem.unitMinPrice;
    }

    final int? priceInCents =
        effectivePrice > 0 ? (effectivePrice * 100).round() : null;

    // ✅ Dados de promoção vindos do backend via MenuItem
    final bool isOnPromotion = menuItem.isOnPromotion;
    final int? promotionalPriceCents =
        (isOnPromotion && menuItem.promotionalPrice != null)
            ? (menuItem.promotionalPrice! * 100).round()
            : null;
    // Preço original (quando em promoção, é o preço que sera riscado na UI)
    final int? originalPriceCents =
        (isOnPromotion && menuItem.originalPrice != null)
            ? (menuItem.originalPrice! * 100).round()
            : null;

    // Converte logoUrl para ImageModel
    final List<ImageModel> images = [];
    if (menuItem.logoUrl != null && menuItem.logoUrl!.isNotEmpty) {
      // Assumindo que logoUrl é um file_key que precisa ser convertido para URL completa
      // Isso será feito pelo backend ou por um helper
      images.add(ImageModel(url: menuItem.logoUrl!));
    }

    // Extrai tamanho das productTags se disponível
    String? sizeTag;
    if (menuItem.productTags != null && menuItem.productTags!.isNotEmpty) {
      final pizzaSizeTag = menuItem.productTags!.firstWhere(
        (tag) => tag.group == 'PIZZA_SIZE',
        orElse: () => menuItem.productTags!.first,
      );
      if (pizzaSizeTag.tags.isNotEmpty) {
        sizeTag = pizzaSizeTag.tags.first;
      }
    }

    // Determina unidade baseado no productInfo
    ProductUnit unit = ProductUnit.UNIT;
    if (menuItem.productInfo != null) {
      unit = ProductUnit.fromString(menuItem.productInfo!.unit);
    }

    // ✅ SIMPLIFICADO: Usa linkedProductId diretamente se disponível
    // Para pizzas, o backend JÁ cria o Product e envia linkedProductId
    // Não há necessidade de criar IDs virtuais no frontend
    final baseId = _codeToInt(menuItem.id);
    final categoryId =
        category.id ?? 0; // ✅ Necessário para primaryCategoryId e categoryLinks
    final productId = menuItem.linkedProductId ?? baseId;

    return Product(
      id: productId,
      name: menuItem.description,
      description: menuItem.details,
      status: ProductStatus.ACTIVE,
      ean: null,
      externalCode: menuItem.code,
      stockQuantity: 0,
      controlStock: false,
      minStock: 0,
      maxStock: 0,
      unit: unit,
      priority: 0,
      featured: false,
      storeId: 0, // Será preenchido pelo contexto
      servesUpTo: null,
      weight: menuItem.productInfo?.quantity,
      soldCount: menuItem.soldCount,
      productType: productType,
      price: priceInCents,
      costPrice: null,
      // ✅ Promoção: usa dados reais do backend
      isOnPromotion: isOnPromotion,
      promotionalPrice: promotionalPriceCents,
      primaryCategoryId: categoryId,
      hasMultiplePrices:
          menuItem.unitPrice != menuItem.unitMinPrice ||
          (menuItem.choices != null && menuItem.choices!.isNotEmpty),
      // ✅ CORREÇÃO BUG #1: Converte choices para variantLinks (complementos)
      variantLinks: _convertChoicesToVariantLinks(menuItem.choices),
      categoryLinks: [
        ProductCategoryLink(
          productId: productId,
          categoryId: categoryId,
          // Se em promoção, price deve ser o original (para cálculo de desconto)
          price:
              isOnPromotion && originalPriceCents != null
                  ? originalPriceCents
                  : (priceInCents ?? 0),
          // ✅ Campos de promoção propagados do backend
          isOnPromotion: isOnPromotion,
          promotionalPrice: promotionalPriceCents,
          isAvailable: true,
          isFeatured: false,
          displayOrder: 0,
          availabilityType: AvailabilityType.always,
          schedules: const [],
        ),
      ],
      prices:
          [], // Preços por tamanho serão calculados dos choices se necessário
      images: images,
      videoUrl: null,
      availabilityType: AvailabilityType.always,
      schedules: [],
      packaging: menuItem.productInfo?.packaging,
      quantity: menuItem.productInfo?.quantity,
      sellingMinimum: null,
      sellingIncremental: null,
      averageUnit: null,
      isIndustrialized: false,
      externalItemId: menuItem.id,
      externalProductId: menuItem.code,
      availabilityStatus: null,
      stockStatus: null,
      hasViolation: false,
      canEdit: true,
      violationCheckState: null,
      sellingRank: 0,
      promotionTags:
          menuItem.productTags
              ?.map((tag) => '${tag.group}:${tag.tags.join(",")}')
              .toList() ??
          [],
      classification: [],
      cashbackType: null,
      cashbackValue: 0,
      masterProductId: null,
      linkedProductId: menuItem.linkedProductId,
    );
  }

  /// Converte MenuChoice para OptionGroup
  /// [maxFlavors] é usado para dividir preços de sabores quando necessário
  static OptionGroup _convertMenuChoice(MenuChoice choice, int? maxFlavors) {
    // Determina o tipo do grupo baseado no código e nome
    OptionGroupType groupType = OptionGroupType.generic;

    // Detecta sabores (SABOR, SABOR2, SABOR3, SABOR4, SBR)
    if (choice.code.startsWith('SABOR') || choice.code == 'SBR') {
      groupType = OptionGroupType.topping;
    }
    // Detecta preferências (massa + borda)
    else if (choice.name.toLowerCase().contains('preferência') ||
        choice.name.toLowerCase().contains('preferencia')) {
      // Verifica se contém massa e borda juntos
      final hasMassa = choice.garnishItens.any(
        (g) => g.description.toLowerCase().contains('massa'),
      );
      final hasBorda = choice.garnishItens.any(
        (g) => g.description.toLowerCase().contains('borda'),
      );

      if (hasMassa && hasBorda) {
        // É um grupo combinado de massa+borda
        // Por enquanto mantém como generic, mas pode ser separado depois
        groupType = OptionGroupType.generic;
      } else if (hasMassa) {
        groupType = OptionGroupType.crust;
      } else if (hasBorda) {
        groupType = OptionGroupType.edge;
      }
    }
    // Outros grupos (ex: "Ponto da carne")
    else {
      groupType = OptionGroupType.generic;
    }

    // Converte garnishItens para OptionItem
    // ✅ CORREÇÃO: Para sabores (TOPPING), divide preço pelo maxFlavors se > 1
    final List<OptionItem> items =
        choice.garnishItens
            .map(
              (garnish) => _convertGarnishItem(
                garnish,
                isTopping: groupType == OptionGroupType.topping,
                maxFlavors: maxFlavors,
              ),
            )
            .toList();

    return OptionGroup(
      id: _codeToInt(choice.code),
      name: choice.name,
      groupType: groupType,
      minSelection: choice.min,
      maxSelection: choice.max,
      items: items,
      displayOrder: 0,
      isActive: true,
    );
  }

  /// Converte GarnishItem para OptionItem
  /// [isTopping] indica se é um sabor (não usado mais, backend já divide)
  /// [maxFlavors] número de sabores permitidos (não usado mais, backend já divide)
  static OptionItem _convertGarnishItem(
    GarnishItem garnish, {
    bool isTopping = false,
    int? maxFlavors,
  }) {
    // ✅ CORREÇÃO: Backend já envia preços divididos pelo max_flavors
    // Apenas converte de reais para centavos
    final int priceInCents = (garnish.unitPrice * 100).round();

    // Converte logoUrl para ImageModel
    ImageModel? image;
    if (garnish.logoUrl != null && garnish.logoUrl!.isNotEmpty) {
      image = ImageModel(url: garnish.logoUrl!);
    }

    return OptionItem(
      id: _codeToInt(garnish.id),
      name: garnish.description,
      description: garnish.details,
      price: priceInCents,
      isActive: true,
      priority: 0,
      externalCode: garnish.code,
      slices: null,
      maxFlavors: null,
      tags: [],
      image: image,
      parentCustomizationOptionId: null,
      pricesBySize: null, // Será calculado se necessário
      isIndustrialized: false,
      isShared: null,
      externalProductId: garnish.code,
      crustId: garnish.crustId,
      edgeId: garnish.edgeId,
      crustName: garnish.crustName,
      edgeName: garnish.edgeName,
      crustPrice:
          garnish.crustPrice != null
              ? (garnish.crustPrice! * 100).round()
              : null,
      edgePrice:
          garnish.edgePrice != null ? (garnish.edgePrice! * 100).round() : null,
    );
  }

  /// ✅ CORREÇÃO BUG #1: Converte lista de MenuChoice para ProductVariantLink
  /// Isso garante que produtos normais tenham seus complementos disponíveis
  static List<ProductVariantLink> _convertChoicesToVariantLinks(
    List<MenuChoice>? choices,
  ) {
    if (choices == null || choices.isEmpty) return [];

    final List<ProductVariantLink> variantLinks = [];
    int displayOrder = 0;

    for (final choice in choices) {
      // Determina o modo de exibição baseado em min/max
      UIDisplayMode displayMode;
      if (choice.max == 1) {
        displayMode = UIDisplayMode.SINGLE;
      } else if (choice.min > 0 || choice.max > 1) {
        displayMode = UIDisplayMode.MULTIPLE;
      } else {
        displayMode = UIDisplayMode.QUANTITY;
      }

      // Converte garnishItens para VariantOptions
      final List<VariantOption> options = [];
      for (final garnish in choice.garnishItens) {
        final priceInCents = (garnish.unitPrice * 100).round();

        options.add(
          VariantOption(
            id: _codeToInt(garnish.id),
            variantId: _codeToInt(choice.code),
            resolvedName: garnish.description,
            resolvedPrice: priceInCents,
            available: true,
            trackInventory: false,
            stockQuantity: 0,
            isActuallyAvailable: true,
            description: garnish.details,
            imagePath: garnish.logoUrl,
          ),
        );
      }

      if (options.isEmpty) continue;

      // Cria Variant
      final variant = Variant(
        id: _codeToInt(choice.code),
        name: choice.name,
        type: VariantType.SPECIFICATIONS,
        options: options,
      );

      // Cria ProductVariantLink
      variantLinks.add(
        ProductVariantLink(
          uiDisplayMode: displayMode,
          minSelectedOptions: choice.min,
          maxSelectedOptions: choice.max,
          maxTotalQuantity: null,
          variant: variant,
          available: true,
          displayOrder: displayOrder++,
        ),
      );
    }

    return variantLinks;
  }
}

/// Resultado da conversão do menu
class MenuAdapterResult {
  final List<Category> categories;
  final List<Product> products;

  const MenuAdapterResult({required this.categories, required this.products});
}
