import 'package:collection/collection.dart';
import 'package:totem/models/cart_item.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/order.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/product_variant_link.dart';
import 'package:totem/models/update_cart_payload.dart';

class OrderReorderHelper {
  static List<UpdateCartItemPayload> buildPayloads({
    required Order order,
    required List<Product> products,
    required List<Category> categories,
  }) {
    final payloads = <UpdateCartItemPayload>[];

    for (final bagItem in order.bag.items) {
      final product =
          products.firstWhereOrNull((p) => p.id.toString() == bagItem.externalId) ??
          products.firstWhereOrNull((p) => p.name == bagItem.name);

      if (product == null || product.id == null) {
        continue;
      }

      final categoryId =
          product.primaryCategoryId ??
          (product.categoryLinks.isNotEmpty ? product.categoryLinks.first.categoryId : 0);
      final category = categories.firstWhereOrNull((c) => c.id == categoryId);

      String? sizeName;
      String? sizeImageUrl;

      final variants =
          (category?.isCustomizable ?? false)
              ? _buildPizzaVariants(
                category: category!,
                product: product,
                bagItem: bagItem,
              )
              : _buildRegularVariants(
                category: category,
                product: product,
                bagItem: bagItem,
              );

      if (category?.isCustomizable ?? false) {
        sizeName = bagItem.name;
        sizeImageUrl =
            (bagItem.logoUrl != null && bagItem.logoUrl!.isNotEmpty)
                ? bagItem.logoUrl
                : product.imageUrl;
      }

      payloads.add(
        UpdateCartItemPayload(
          productId: product.id!,
          categoryId: categoryId,
          quantity: bagItem.quantity,
          note: bagItem.notes,
          sizeName: sizeName,
          sizeImageUrl: sizeImageUrl,
          variants: variants.isNotEmpty ? variants : null,
        ),
      );
    }

    return payloads;
  }

  static String _normalizeName(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static OptionGroup? _findRegularGroup({
    required Category category,
    required Product product,
    required String groupName,
    required List<SubItem> subItems,
  }) {
    final productGroups = category.productOptionGroups?[product.id] ?? const [];
    final allGroups = [...productGroups, ...category.optionGroups];

    final byName = allGroups.firstWhereOrNull(
      (group) => _normalizeName(group.name) == _normalizeName(groupName),
    );
    if (byName != null) {
      return byName;
    }

    return allGroups.firstWhereOrNull((group) {
      return subItems.every((subItem) {
        final subId = int.tryParse(subItem.externalId ?? '');
        final normalizedSubName = _normalizeName(subItem.name);

        return group.items.any(
          (item) =>
              (subId != null && item.id == subId) ||
              _normalizeName(item.name) == normalizedSubName,
        );
      });
    });
  }

  static OptionItem? _findRegularOptionItem({
    required OptionGroup group,
    required SubItem subItem,
  }) {
    final subId = int.tryParse(subItem.externalId ?? '');
    final normalizedSubName = _normalizeName(subItem.name);

    return group.items.firstWhereOrNull(
      (item) =>
          (subId != null && item.id == subId) ||
          _normalizeName(item.name) == normalizedSubName,
    );
  }

  static ProductVariantLink? _findRegularVariantLink({
    required Product product,
    required String groupName,
    required List<SubItem> subItems,
  }) {
    final byName = product.variantLinks.firstWhereOrNull(
      (link) => _normalizeName(link.variant.name) == _normalizeName(groupName),
    );
    if (byName != null) {
      return byName;
    }

    return product.variantLinks.firstWhereOrNull((link) {
      return subItems.every((subItem) {
        final subId = int.tryParse(subItem.externalId ?? '');
        final normalizedSubName = _normalizeName(subItem.name);

        return link.variant.options.any(
          (option) =>
              (subId != null && option.id == subId) ||
              _normalizeName(option.resolvedName) == normalizedSubName,
        );
      });
    });
  }

  static int? _findRegularVariantOptionId({
    required ProductVariantLink variantLink,
    required SubItem subItem,
  }) {
    final subId = int.tryParse(subItem.externalId ?? '');
    final normalizedSubName = _normalizeName(subItem.name);

    return variantLink.variant.options
        .firstWhereOrNull(
          (option) =>
              (subId != null && option.id == subId) ||
              _normalizeName(option.resolvedName) == normalizedSubName,
        )
        ?.id;
  }

  static OptionGroup? _findPizzaGroup({
    required Category category,
    required Product product,
    required SubItem subItem,
  }) {
    final parsedType = OptionGroupType.fromString(subItem.groupType);
    final productGroups =
        category.productOptionGroups?[product.id] ??
        category.productOptionGroups?[product.linkedProductId ?? -1] ??
        const [];

    if (parsedType != OptionGroupType.other) {
      final productGroup = productGroups.firstWhereOrNull(
        (g) => g.groupType == parsedType,
      );
      if (productGroup != null) return productGroup;

      final categoryGroup = category.optionGroups.firstWhereOrNull(
        (g) => g.groupType == parsedType,
      );
      if (categoryGroup != null) return categoryGroup;
    }

    final normalizedGroupName = _normalizeName(subItem.groupName);
    final normalizedSubName = _normalizeName(subItem.name);

    return productGroups.firstWhereOrNull(
          (g) =>
              _normalizeName(g.name) == normalizedGroupName ||
              _normalizeName(g.name) == normalizedSubName,
        ) ??
        category.optionGroups.firstWhereOrNull(
          (g) =>
              _normalizeName(g.name) == normalizedGroupName ||
              _normalizeName(g.name) == normalizedSubName,
        );
  }

  static OptionItem? _findPizzaOptionItem({
    required OptionGroup? group,
    required SubItem subItem,
  }) {
    final externalId = int.tryParse(subItem.externalId ?? '');

    if (externalId != null) {
      final byId = group?.items.firstWhereOrNull((item) => item.id == externalId);
      if (byId != null) return byId;
    }

    final normalizedName = _normalizeName(subItem.name);
    return group?.items.firstWhereOrNull(
      (item) => _normalizeName(item.name) == normalizedName,
    );
  }

  static List<CartItemVariant> _buildPizzaVariants({
    required Category category,
    required Product product,
    required BagItem bagItem,
  }) {
    if (bagItem.subItems.isEmpty) {
      return const [];
    }

    final groupedOptions = <String, List<CartItemVariantOption>>{};
    final groupedIds = <String, int?>{};
    final groupedTypes = <String, String?>{};
    final groupedNames = <String, String?>{};

    for (final sub in bagItem.subItems) {
      final group = _findPizzaGroup(
        category: category,
        product: product,
        subItem: sub,
      );
      final optionItem = _findPizzaOptionItem(group: group, subItem: sub);
      final groupType =
          group?.groupType.toApiString() ??
          OptionGroupType.fromString(sub.groupType).toApiString();
      final groupName = group?.name ?? sub.groupName ?? 'Opções';
      final groupId = group?.id;
      final optionName = switch (group?.groupType ??
          OptionGroupType.fromString(sub.groupType)) {
        OptionGroupType.crust =>
          sub.name.toLowerCase().startsWith('massa ') ? sub.name : 'Massa ${sub.name}',
        OptionGroupType.edge =>
          sub.name.toLowerCase().startsWith('borda ') ? sub.name : 'Borda ${sub.name}',
        _ => sub.name,
      };

      final key = '${groupId ?? groupName}::$groupType';
      final option = CartItemVariantOption(
        optionItemId: optionItem?.id ?? int.tryParse(sub.externalId ?? ''),
        variantOptionId: null,
        quantity: sub.quantity,
        name: optionName,
        price: sub.unitPrice,
      );

      groupedOptions.putIfAbsent(key, () => <CartItemVariantOption>[]).add(option);
      groupedIds[key] = groupId;
      groupedTypes[key] = groupType;
      groupedNames[key] = groupName;
    }

    return groupedOptions.entries
        .map(
          (entry) => CartItemVariant(
            optionGroupId: groupedIds[entry.key],
            variantId: null,
            groupType: groupedTypes[entry.key],
            name: groupedNames[entry.key] ?? 'Opções',
            options: entry.value,
          ),
        )
        .toList();
  }

  static List<CartItemVariant> _buildRegularVariants({
    required Category? category,
    required Product product,
    required BagItem bagItem,
  }) {
    final variants = <CartItemVariant>[];

    if (bagItem.subItems.isEmpty) {
      return variants;
    }

    final groupedSubItems = groupBy(
      bagItem.subItems,
      (SubItem s) => s.groupName ?? 'Opções',
    );

    for (final entry in groupedSubItems.entries) {
      final groupName = entry.key;
      final subs = entry.value;

      int? variantId;
      int? optionGroupId;
      String? groupType;
      OptionGroup? optGroup;
      ProductVariantLink? variantLink;

      variantLink = _findRegularVariantLink(
        product: product,
        groupName: groupName,
        subItems: subs,
      );

      if (variantLink?.variant.id != null) {
        variantId = variantLink!.variant.id;
      }

      if (category != null) {
        optGroup = _findRegularGroup(
          category: category,
          product: product,
          groupName: groupName,
          subItems: subs,
        );

        if (optGroup != null) {
          optionGroupId = optGroup.id;
          groupType = optGroup.groupType.toApiString();
        }
      }

      final options = <CartItemVariantOption>[];
      for (final sub in subs) {
        final matchedVariantOptionId =
            variantLink != null
                ? _findRegularVariantOptionId(
                  variantLink: variantLink,
                  subItem: sub,
                )
                : null;
        final matchedOption =
            optGroup != null
                ? _findRegularOptionItem(group: optGroup, subItem: sub)
                : null;
        final id =
            matchedVariantOptionId ??
            matchedOption?.id ??
            int.tryParse(sub.externalId ?? '');

        options.add(
          CartItemVariantOption(
            optionItemId:
                (groupType == 'TOPPING' ||
                        groupType == 'CRUST' ||
                        groupType == 'EDGE' ||
                        groupType == 'SIZE')
                    ? id
                    : null,
            variantOptionId:
                (groupType != 'TOPPING' &&
                        groupType != 'CRUST' &&
                        groupType != 'EDGE' &&
                        groupType != 'SIZE')
                    ? id
                    : null,
            quantity: sub.quantity,
            name: sub.name,
            price: sub.unitPrice,
          ),
        );
      }

      if (options.isNotEmpty) {
        variants.add(
          CartItemVariant(
            variantId: variantId,
            optionGroupId: optionGroupId,
            groupType: groupType,
            name: variantLink?.variant.name ?? groupName,
            options: options,
          ),
        );
      }
    }

    return variants;
  }
}
