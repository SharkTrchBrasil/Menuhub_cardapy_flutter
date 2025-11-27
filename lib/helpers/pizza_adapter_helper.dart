// lib/helpers/pizza_adapter_helper.dart

import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/image_model.dart';
import 'package:collection/collection.dart';

/// Resultado da adaptação de pizza
class PizzaAdaptationResult {
  final Product product;
  final Category category;

  PizzaAdaptationResult(this.product, this.category);
}

/// Helper para adaptar produtos de pizza (CUSTOMIZABLE) para usar o dialog de produtos GENERAL
class PizzaAdapterHelper {
  /// Detecta se é um produto de pizza baseado na categoria
  static bool isPizza(Category? category) {
    return category != null && category.type == CategoryType.CUSTOMIZABLE;
  }

  /// Extrai o tamanho selecionado da URL ou contexto
  /// Formato esperado: /product/:slug/:productId?size=:sizeId
  static OptionItem? getSelectedSize(Category category, int? sizeId) {
    if (sizeId == null) return null;
    
    // 1. Tenta encontrar o grupo explicitamente marcado como SIZE
    var sizeGroup = category.optionGroups.firstWhereOrNull(
      (g) => g.groupType == OptionGroupType.size,
    );
    
    // 2. Fallback: Se não achar grupo SIZE, procura em qualquer grupo que contenha o item
    if (sizeGroup == null) {
      print("⚠️ [PizzaAdapter] Grupo SIZE não encontrado. Procurando item $sizeId em outros grupos...");
      for (var group in category.optionGroups) {
        if (group.items.any((item) => item.id == sizeId)) {
          sizeGroup = group;
          print("✅ [PizzaAdapter] Item encontrado no grupo: ${group.name}");
          break;
        }
      }
    }
    
    if (sizeGroup == null) {
      print("❌ [PizzaAdapter] Tamanho $sizeId não encontrado em nenhum grupo.");
      return null;
    }
    
    return sizeGroup.items.firstWhereOrNull((item) => item.id == sizeId);
  }

  /// Extrai o número máximo de sabores permitidos do nome do tamanho
  /// Ex: "FAMÍLIA 4 SABORES (16 PEDAÇOS)" -> 4
  static int getMaxFlavorsFromSize(OptionItem size) {
    // Primeiro tenta usar o campo maxFlavors se disponível
    if (size.maxFlavors != null && size.maxFlavors! > 0) {
      return size.maxFlavors!;
    }
    
    // Caso contrário, extrai do nome
    final regex = RegExp(r'(\d+)\s*SABORES?', caseSensitive: false);
    final match = regex.firstMatch(size.name);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 1; // Padrão: 1 sabor
  }

  /// Cria grupos dinâmicos de sabores baseado no número permitido
  /// Retorna lista de OptionGroups virtuais para seleção de sabores
  static List<OptionGroup> createFlavorGroups(
    Category category,
    OptionItem size,
    List<Product> availableFlavors,
  ) {
    final maxFlavors = getMaxFlavorsFromSize(size);
    final List<OptionGroup> flavorGroups = [];

    for (int i = 0; i < maxFlavors; i++) {
      final groupName = i == 0
          ? 'Escolha um sabor'
          : i == 1
              ? 'Escolha o segundo sabor'
              : i == 2
                  ? 'Escolha o terceiro sabor'
                  : 'Escolha o ${i + 1}º sabor';

      // Cria OptionItems virtuais para cada sabor disponível e ATIVO
      final flavorItems = availableFlavors.map((flavor) {
        // Encontra o preço deste sabor para o tamanho selecionado
        final flavorPrice = flavor.prices.firstWhereOrNull(
          (fp) => fp.sizeOptionId == size.id,
        );

        // ✅ Filtra sabores sem preço ou indisponíveis (pausados)
        if (flavorPrice == null || flavorPrice.id == null || !flavorPrice.isAvailable) {
          return null;
        }

        // Formata o nome com fração (ex: "1/4 Pizza Calabresa")
        final fraction = maxFlavors > 1 ? '1/$maxFlavors ' : '';
        final displayName = '${fraction}${flavor.name}';

        return OptionItem(
          id: flavor.id,
          name: displayName,
          description: flavor.description,
          price: flavorPrice.price,
          isActive: true, // ✅ Já filtrado acima, sempre ativo aqui
          image: flavor.coverImageUrl != null ? ImageModel(url: flavor.coverImageUrl!) : null,
        );
      }).whereType<OptionItem>().toList();

      // ✅ Se não há sabores ativos, não cria o grupo
      if (flavorItems.isEmpty) continue;

      // Cria o grupo virtual de sabores
      final flavorGroup = OptionGroup(
        id: 1000 + i, // ID virtual único
        name: groupName,
        groupType: OptionGroupType.flavor, // Tipo especial para sabores
        minSelection: 1, // Obrigatório
        maxSelection: 1, // Apenas 1 sabor por slot
        items: flavorItems,
      );

      flavorGroups.add(flavorGroup);
    }

    return flavorGroups;
  }

  /// Cria o grupo de preferências (massa + borda combinadas)
  static OptionGroup? createPreferencesGroup(Category category) {
    final doughGroup = category.optionGroups.firstWhereOrNull(
      (g) => g.name.toLowerCase().contains('massa'),
    );

    final edgeGroup = category.optionGroups.firstWhereOrNull(
      (g) => g.name.toLowerCase().contains('borda'),
    );

    if (doughGroup == null || edgeGroup == null) return null;

    final List<OptionItem> combos = [];
    int comboId = 2000; // IDs virtuais começando em 2000

    // Gera todas as combinações de massa + borda
    for (var dough in doughGroup.items.where((item) => item.isActive)) {
      for (var edge in edgeGroup.items.where((item) => item.isActive)) {
        final comboName = '${dough.name} + ${edge.name}';
        final comboPrice = dough.price + edge.price; // Soma dos preços em centavos

        combos.add(OptionItem(
          id: comboId++,
          name: comboName,
          price: comboPrice,
          isActive: true,
        ));
      }
    }

    if (combos.isEmpty) return null;

    return OptionGroup(
      id: 999, // ID virtual único
      name: 'Escolha a sua Preferência',
      groupType: OptionGroupType.generic, // Usa GENERIC ao invés de preference que não existe
      minSelection: 1, // Obrigatório
      maxSelection: 1, 
      items: combos,
    );
  }

  /// Adapta o produto de pizza para usar com o dialog de produtos GENERAL
  /// Retorna um resultado contendo o Produto adaptado (nome, imagem) e a Categoria adaptada (grupos de opções)
  static PizzaAdaptationResult adaptPizzaProduct({
    required Product originalProduct,
    required Category category,
    required OptionItem size,
    required List<Product> availableFlavors,
  }) {
    // Cria grupos de sabores dinâmicos
    final flavorGroups = createFlavorGroups(category, size, availableFlavors);
    
    // Cria grupo de preferências (massa + borda)
    final preferencesGroup = createPreferencesGroup(category);

    // Encontra o grupo que contém o tamanho selecionado para garantir sua remoção
    final sizeGroup = category.optionGroups.firstWhereOrNull((g) => g.items.any((i) => i.id == size.id));

    // Combina os grupos para a NOVA CATEGORIA
    final adaptedGroups = [
      ...flavorGroups,
      if (preferencesGroup != null) preferencesGroup,
      // Mantém outros grupos que não sejam de pizza (ex: adicionais genéricos, se houver)
      ...category.optionGroups.where((g) => 
        g.id != sizeGroup?.id && // ✅ Remove o grupo específico do tamanho selecionado
        g.groupType != OptionGroupType.size && 
        g.groupType != OptionGroupType.flavor && 
        !g.name.toUpperCase().contains('MASSA') &&
        !g.name.toUpperCase().contains('BORDA')
      ),
    ];

    // Cria uma nova categoria com os grupos adaptados
    final adaptedCategory = Category(
      id: category.id,
      name: category.name,
      description: category.description,
      priority: category.priority,
      isActive: category.isActive,
      type: category.type,
      image: category.image,
      optionGroups: adaptedGroups,
      productLinks: category.productLinks,
    );

    // Cria produto adaptado com nome do tamanho
    final adaptedProduct = Product(
      id: originalProduct.id,
      name: size.name, // ✅ Título = nome do tamanho
      description: originalProduct.description,
      // ✅ Passa a imagem como uma lista de ImageModel
      images: category.image != null 
          ? [category.image!] 
          : (originalProduct.images.isNotEmpty ? originalProduct.images : []),
      prices: originalProduct.prices, 
      categoryLinks: originalProduct.categoryLinks,
      
      // Preenche os campos obrigatórios com valores do original
      status: originalProduct.status,
      storeId: originalProduct.storeId,
      productType: originalProduct.productType,
      unit: originalProduct.unit,
      availabilityType: originalProduct.availabilityType,
      schedules: originalProduct.schedules,
      dietaryTags: originalProduct.dietaryTags,
      beverageTags: originalProduct.beverageTags,
    );

    return PizzaAdaptationResult(adaptedProduct, adaptedCategory);
  }
}
