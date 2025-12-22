// lib/helpers/pizza_adapter_helper.dart

import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/image_model.dart';
import 'package:collection/collection.dart';
import 'package:totem/helpers/enums/product_status.dart';

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
    
    final selectedSize = sizeGroup.items.firstWhereOrNull((item) => item.id == sizeId);
    
    if (selectedSize != null) {
      print("🔍 [PizzaAdapter] Tamanho encontrado: ${selectedSize.name}");
      print("   - OptionItem.id: ${selectedSize.id}");
      print("   - OptionItem.linkedProductId: ${selectedSize.linkedProductId}");
    }
    
    return selectedSize;
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
        // ✅ VALIDAÇÃO 1: Verifica se o sabor (produto) está ativo
        if (flavor.status != ProductStatus.ACTIVE) {
          return null; // Sabor pausado/inativo, não inclui
        }
        
        // Encontra o preço deste sabor para o tamanho selecionado
        final flavorPrice = flavor.prices.firstWhereOrNull(
          (fp) => fp.sizeOptionId == size.id,
        );

        // ✅ VALIDAÇÃO 2: Filtra sabores sem preço ou indisponíveis no tamanho (pausados)
        if (flavorPrice == null || flavorPrice.id == null || !flavorPrice.isAvailable) {
          return null;
        }

        // Formata o nome com fração (ex: "1/2 Calabresa")
        final fraction = maxFlavors > 1 ? '1/$maxFlavors ' : '';
        final displayName = '${fraction}${flavor.name}';

        // ✅ REGRA DO MAIS CARO: Mostra o preço fracionado para exibição
        // Ex: Pizza Média R$ 39,99 com 2 sabores = exibe "+ R$ 19,99" por sabor
        // Mas na hora de calcular o total, usa o MAIOR preço cheio
        final displayPrice = maxFlavors > 1 
            ? (flavorPrice.price / maxFlavors).round() 
            : flavorPrice.price;

        return OptionItem(
          id: flavor.id,
          name: displayName,
          description: flavor.description,
          price: displayPrice, // ✅ Preço fracionado para exibição
          isActive: true, // ✅ Já filtrado acima, sempre ativo aqui
          image: flavor.imageUrl != null ? ImageModel(url: flavor.imageUrl!) : null,
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

    // Gera todas as combinações de massa + borda
    // ✅ CORREÇÃO: Usa IDs reais dos itens de massa e borda
    for (var dough in doughGroup.items.where((item) => item.isActive)) {
      for (var edge in edgeGroup.items.where((item) => item.isActive)) {
        final comboName = '${dough.name} + ${edge.name}';
        final comboPrice = dough.price + edge.price; // Soma dos preços em centavos

        combos.add(OptionItem(
          id: dough.id, // ✅ Usa o ID real da massa como ID principal
          name: comboName,
          price: comboPrice,
          isActive: true,
          parentCustomizationOptionId: edge.id, // ✅ Armazena ID da borda
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
    // ✅ CORREÇÃO: Usa o linkedProductId do tamanho como chave
    // Cada tamanho (BROTO, GRANDE) tem seus próprios choices com preços específicos
    final sizeProductId = size.linkedProductId ?? size.id;
    
    // ✅ NOVO: Usa os choices do backend se disponíveis
    List<OptionGroup> flavorGroups = [];
    if (category.productOptionGroups != null) {
      print("🍕 [PizzaAdapter] productOptionGroups disponível com ${category.productOptionGroups!.length} tamanhos");
      print("🍕 [PizzaAdapter] Buscando choices para sizeProductId: $sizeProductId (size: ${size.name})");
      print("🍕 [PizzaAdapter] IDs disponíveis: ${category.productOptionGroups!.keys.toList()}");
      
      if (category.productOptionGroups!.containsKey(sizeProductId)) {
        // Busca os optionGroups específicos deste tamanho
        final productGroups = category.productOptionGroups![sizeProductId]!;
        print("✅ [PizzaAdapter] Encontrou ${productGroups.length} grupos para sizeProductId $sizeProductId");
        print("   └─ Grupos encontrados:");
        for (var group in productGroups) {
          print("      - ${group.name} (type: ${group.groupType}, code: ${group.id})");
        }
        // Filtra apenas os grupos de sabores (TOPPING)
        flavorGroups = productGroups.where((g) => g.groupType == OptionGroupType.topping).toList();
        print("✅ [PizzaAdapter] ${flavorGroups.length} grupos de sabores (TOPPING) encontrados:");
        for (var group in flavorGroups) {
          print("      - ${group.name} (${group.items.length} itens)");
        }
      } else {
        print("⚠️ [PizzaAdapter] sizeProductId $sizeProductId não encontrado no productOptionGroups");
      }
    } else {
      print("⚠️ [PizzaAdapter] productOptionGroups é null, usando fallback");
    }
    
    // ✅ Fallback: Se não encontrou choices do backend, cria grupos virtuais (compatibilidade)
    if (flavorGroups.isEmpty) {
      print("⚠️ [PizzaAdapter] Usando fallback: criando grupos virtuais");
      flavorGroups = createFlavorGroups(category, size, availableFlavors);
    }
    
    // ✅ NOVO: Busca grupos de preferências (MASSA e BORDA) dos choices do backend
    // ✅ ESTRATÉGIA: Combina MASSA e BORDA em um único grupo de "Preferência"
    // Os IDs são preservados: id = massa, parentCustomizationOptionId = borda
    List<OptionGroup> otherGroups = [];
    OptionGroup? preferencesGroup;
    
    if (category.productOptionGroups != null && category.productOptionGroups!.containsKey(sizeProductId)) {
      // Busca os optionGroups específicos deste tamanho
      final productGroups = category.productOptionGroups![sizeProductId]!;
      
      // Busca grupos de MASSA e BORDA
      final doughGroup = productGroups.firstWhereOrNull(
        (g) => g.name.toLowerCase().contains('massa'),
      );
      final edgeGroup = productGroups.firstWhereOrNull(
        (g) => g.name.toLowerCase().contains('borda'),
      );
      
      // ✅ Se tem ambos, cria grupo combinado de preferências
      if (doughGroup != null && edgeGroup != null) {
        print("🔀 [PizzaAdapter] Combinando grupos de Massa e Borda em um único grupo de Preferências");
        
        final List<OptionItem> combos = [];
        for (var dough in doughGroup.items.where((item) => item.isActive)) {
          for (var edge in edgeGroup.items.where((item) => item.isActive)) {
            final comboName = '${dough.name} + ${edge.name}';
            final comboPrice = dough.price + edge.price;
            
            combos.add(OptionItem(
              id: dough.id,
              name: comboName,
              price: comboPrice,
              isActive: true,
              parentCustomizationOptionId: edge.id,
            ));
          }
        }
        
        if (combos.isNotEmpty) {
          preferencesGroup = OptionGroup(
            id: 999, // ID virtual único
            name: 'Escolha a sua preferência',
            groupType: OptionGroupType.generic,
            minSelection: 1,
            maxSelection: 1,
            items: combos,
          );
          print("✅ [PizzaAdapter] Grupo de preferências criado com ${combos.length} combinações");
        }
      }
      
      // ✅ Outros grupos que não são TOPPING, MASSA ou BORDA
      otherGroups = productGroups.where((g) {
        if (g.groupType == OptionGroupType.topping) return false;
        if (g.name.toLowerCase().contains('massa')) return false;
        if (g.name.toLowerCase().contains('borda')) return false;
        return true;
      }).toList();
      
      print("✅ [PizzaAdapter] Grupos extras encontrados: ${otherGroups.length}");
    } else {
      // ✅ Fallback: Usa createPreferencesGroup da categoria original
      preferencesGroup = createPreferencesGroup(category);
      
      // Outros grupos que não são SIZE, TOPPING, MASSA ou BORDA
      otherGroups = category.optionGroups.where((g) {
        if (g.groupType == OptionGroupType.size) return false;
        if (g.groupType == OptionGroupType.topping) return false;
        if (g.groupType == OptionGroupType.flavor) return false;
        if (g.name.toLowerCase().contains('massa')) return false;
        if (g.name.toLowerCase().contains('borda')) return false;
        return true;
      }).toList();
    }

    // Combina os grupos para a NOVA CATEGORIA
    final adaptedGroups = <OptionGroup>[
      ...flavorGroups,
      if (preferencesGroup != null) preferencesGroup, // ✅ Grupo combinado de preferências
      ...otherGroups, // ✅ Outros grupos extras
    ];
    
    print("🍕 [PizzaAdapter] Grupos finais adaptados: ${adaptedGroups.length}");
    print("   └─ Grupos de sabores: ${flavorGroups.length}");
    for (var group in flavorGroups) {
      print("      - ${group.name} (${group.items.length} itens, min: ${group.minSelection}, max: ${group.maxSelection})");
    }
    if (preferencesGroup != null) {
      print("   └─ Grupo de preferências combinado: ${preferencesGroup.items.length} combinações");
    }
    print("   └─ Grupos extras: ${otherGroups.length}");

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
      productOptionGroups: category.productOptionGroups, // ✅ Preserva productOptionGroups
    );

    // ✅ TÍTULO: Usa o nome completo do tamanho (igual ao iFood)
    // Ex: "GRANDE 3 SABORES (8 PEDAÇOS)" - sem limpeza
    final displayName = size.name;

    // ✅ IMAGEM: Prioriza imagem do tamanho > produto original > categoria
    List<ImageModel> displayImages = [];
    if (size.image != null && size.image!.url.isNotEmpty) {
      displayImages.add(size.image!);
      print("✅ [PizzaAdapter] Usando imagem do tamanho: ${size.image!.url}");
    } else if (originalProduct.images.isNotEmpty) {
      displayImages.addAll(originalProduct.images);
      print("✅ [PizzaAdapter] Usando imagem do produto original: ${originalProduct.images.first.url}");
    } else if (category.image != null) {
      displayImages.add(category.image!);
      print("✅ [PizzaAdapter] Usando imagem da categoria: ${category.image!.url}");
    } else {
      print("⚠️ [PizzaAdapter] Nenhuma imagem encontrada para o produto");
    }

    // Cria produto adaptado com nome do tamanho completo
    // ✅ CRÍTICO: Usa o linkedProductId do tamanho se disponível, senão do produto original
    final finalLinkedProductId = size.linkedProductId ?? originalProduct.linkedProductId;
    
    print("🔍 [PizzaAdapter] Adaptando produto:");
    print("   - originalProduct.id: ${originalProduct.id}");
    print("   - originalProduct.linkedProductId: ${originalProduct.linkedProductId}");
    print("   - size.id: ${size.id}");
    print("   - size.linkedProductId: ${size.linkedProductId}");
    print("   - finalLinkedProductId: $finalLinkedProductId");
    
    final adaptedProduct = Product(
      id: originalProduct.id,
      name: displayName, // ✅ Nome completo do tamanho (igual ao iFood)
      description: originalProduct.description,
      images: displayImages, // ✅ Imagem correta
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
      linkedProductId: finalLinkedProductId, // ✅ Usa linkedProductId do tamanho se disponível
    );

    return PizzaAdaptationResult(adaptedProduct, adaptedCategory);
  }
}
