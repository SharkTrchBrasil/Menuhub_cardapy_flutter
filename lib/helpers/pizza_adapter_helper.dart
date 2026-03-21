// lib/helpers/pizza_adapter_helper.dart

import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/image_model.dart';
import 'package:collection/collection.dart';
import 'package:totem/helpers/enums/product_status.dart';
import 'package:totem/core/utils/app_logger.dart';

/// Resultado da adaptação de pizza
class PizzaAdaptationResult {
  final Product product;
  final Category category;

  PizzaAdaptationResult(this.product, this.category);
}

/// Helper para adaptar produtos de pizza (CUSTOMIZABLE) para usar o dialog de produtos GENERAL
class PizzaAdapterHelper {
  // ═══════════════════════════════════════════════════════════════════════
  // IDs VIRTUAIS — Faixa negativa para NUNCA colidir com IDs reais do DB
  // PostgreSQL auto-increment é sempre positivo.
  // ═══════════════════════════════════════════════════════════════════════
  static const int kPreferencesGroupId = -999;
  static const int kFlavorGroupBaseId =
      -1000; // slot i → kFlavorGroupBaseId - i
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
      print(
        "⚠️ [PizzaAdapter] Grupo SIZE não encontrado. Procurando item $sizeId em outros grupos...",
      );
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

    final selectedSize = sizeGroup.items.firstWhereOrNull(
      (item) => item.id == sizeId,
    );

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
    // 1. TENTA EXTRAIR DO NOME (Mais confiável para o que o usuário vê)
    // Ex: "FAMÍLIA 4 SABORES (16 PEDAÇOS)" -> 4
    final regex = RegExp(r'(\d+)\s*SABORES?', caseSensitive: false);
    final match = regex.firstMatch(size.name);
    if (match != null) {
      final fromName = int.parse(match.group(1)!);
      if (fromName > 0) return fromName;
    }

    // 2. FALLBACK: Campo maxFlavors do objeto
    if (size.maxFlavors != null && size.maxFlavors! > 0) {
      return size.maxFlavors!;
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
      final groupName =
          i == 0
              ? 'Escolha um sabor'
              : i == 1
              ? 'Escolha o segundo sabor'
              : i == 2
              ? 'Escolha o terceiro sabor'
              : 'Escolha o ${i + 1}º sabor';

      // Cria OptionItems virtuais para cada sabor disponível e ATIVO
      final flavorItems =
          availableFlavors
              .map((flavor) {
                // ✅ VALIDAÇÃO 1: Verifica se o sabor (produto) está ativo
                if (flavor.status != ProductStatus.ACTIVE) {
                  return null; // Sabor pausado/inativo, não inclui
                }

                // Encontra o preço deste sabor para o tamanho selecionado
                final flavorPrice = flavor.prices.firstWhereOrNull(
                  (fp) => fp.sizeOptionId == size.id,
                );

                // ✅ VALIDAÇÃO 2: Filtra sabores sem preço ou indisponíveis no tamanho (pausados)
                if (flavorPrice == null ||
                    flavorPrice.id == null ||
                    !flavorPrice.isAvailable) {
                  return null;
                }

                // Formata o nome com fração (ex: "1/2 Calabresa")
                final fraction = maxFlavors > 1 ? '1/$maxFlavors ' : '';
                final displayName = '${fraction}${flavor.name}';

                // ✅ REGRA DO MAIS CARO: Mostra o preço fracionado para exibição
                // Ex: Pizza Média R$ 39,99 com 2 sabores = exibe "+ R$ 19,99" por sabor
                // Mas na hora de calcular o total, usa o MAIOR preço cheio
                final displayPrice =
                    maxFlavors > 1
                        ? (flavorPrice.price / maxFlavors).round()
                        : flavorPrice.price;

                return OptionItem(
                  id: flavor.id,
                  name: displayName,
                  description: flavor.description,
                  price: displayPrice, // ✅ Preço fracionado para exibição
                  isActive: true, // ✅ Já filtrado acima, sempre ativo aqui
                  image:
                      flavor.imageUrl != null
                          ? ImageModel(url: flavor.imageUrl!)
                          : null,
                );
              })
              .whereType<OptionItem>()
              .toList();

      // ✅ Se não há sabores ativos, não cria o grupo
      if (flavorItems.isEmpty) continue;

      // Cria o grupo virtual de sabores
      final flavorGroup = OptionGroup(
        id:
            kFlavorGroupBaseId -
            i, // ID virtual negativo (-1000, -1001, -1002...)
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

  /// ✅ Cria flavor groups diretamente dos OptionItems do backend (productOptionGroups).
  /// Usado quando o backend envia os TOPPING groups com prices_by_size já populados.
  /// Diferente de createFlavorGroups (que usa Products), este método trabalha com OptionItems
  /// e busca o preço via getPriceForSize(size.id).
  ///
  /// Suporta dois cenários:
  /// 1. **Carga inicial** (build_menu_format): OptionItems já vêm com price dividido e nome
  ///    prefixado ("1/2 Sabor"). pricesBySize=null → usamos item.price/name direto.
  /// 2. **category_updated**: OptionItems têm pricesBySize populado com preço cheio por tamanho.
  ///    Dividimos e adicionamos prefixo de fração.
  static List<OptionGroup> _createFlavorGroupsFromOptionItems(
    List<OptionGroup> rawToppingGroups,
    OptionItem size,
    int maxFlavors,
  ) {
    // Coleta todos os OptionItems ativos de todos os grupos TOPPING
    final allToppingItemsRaw =
        rawToppingGroups
            .expand((g) => g.items.where((i) => i.isActive))
            .toList();

    // ✅ FIX: Remove duplicatas por ID (caso o backend envie múltiplos grupos TOPPING com os mesmos sabores)
    final seenIds = <int>{};
    final allToppingItems =
        allToppingItemsRaw.where((item) {
          final itemId = item.id;
          if (itemId == null) return false; // Ignora items sem ID
          if (seenIds.contains(itemId)) {
            return false; // Já vimos este sabor, pula
          }
          seenIds.add(itemId);
          return true;
        }).toList();

    if (allToppingItems.isEmpty) return [];

    // Detecta se estamos no cenário da carga inicial (preços já divididos, nomes com fração)
    // Na carga inicial, pricesBySize é null em todos os items
    final bool isPreFormatted = allToppingItems.every(
      (item) => item.pricesBySize == null || item.pricesBySize!.isEmpty,
    );

    print(
      '🔍 [FlavorGroups] isPreFormatted: $isPreFormatted, size.id: ${size.id}, maxFlavors: $maxFlavors',
    );
    print('   └─ allToppingItems: ${allToppingItems.length} items');
    for (final item in allToppingItems) {
      print(
        '      - ${item.name}: price=${item.price}, pricesBySize=${item.pricesBySize?.length ?? 0}',
      );
    }

    final List<OptionGroup> flavorGroups = [];

    for (int i = 0; i < maxFlavors; i++) {
      final groupName =
          i == 0
              ? 'Escolha um sabor'
              : i == 1
              ? 'Escolha o segundo sabor'
              : i == 2
              ? 'Escolha o terceiro sabor'
              : 'Escolha o ${i + 1}º sabor';

      final flavorItems =
          allToppingItems
              .map((item) {
                if (isPreFormatted) {
                  // Cenário 1: Carga inicial — item.price já dividido, item.name já com fração
                  if (item.price <= 0) return null;
                  return OptionItem(
                    id: item.id,
                    name: item.name,
                    description: item.description,
                    price: item.price,
                    isActive: true,
                    image: item.image,
                  );
                } else {
                  // Cenário 2: category_updated — preço cheio em pricesBySize, precisa dividir
                  final fullPrice =
                      item.getPriceForSize(size.id) ??
                      item.getPriceForSize(size.linkedProductId) ??
                      item.price;
                  print(
                    '      🔍 Item "${item.name}": fullPrice=$fullPrice (size.id=${size.id})',
                  );
                  if (fullPrice <= 0) {
                    print('         ❌ Ignorado: fullPrice <= 0');
                    return null;
                  }

                  // Formata o nome com fração (ex: "1/2 Calabresa"), evitando prefixo duplicado
                  final hasPrefix = RegExp(r'^\d+/\d+\s').hasMatch(item.name);
                  final displayName =
                      (maxFlavors > 1 && !hasPrefix)
                          ? '1/$maxFlavors ${item.name}'
                          : item.name;

                  // Preço fracionado para exibição
                  final displayPrice =
                      maxFlavors > 1
                          ? (fullPrice / maxFlavors).round()
                          : fullPrice;

                  return OptionItem(
                    id: item.id,
                    name: displayName,
                    description: item.description,
                    price: displayPrice,
                    isActive: true,
                    image: item.image,
                    pricesBySize: item.pricesBySize,
                  );
                }
              })
              .whereType<OptionItem>()
              .toList();

      if (flavorItems.isEmpty) continue;

      flavorGroups.add(
        OptionGroup(
          id:
              kFlavorGroupBaseId -
              i, // ID virtual negativo (-1000, -1001, -1002...)
          name: groupName,
          groupType: OptionGroupType.flavor,
          minSelection: 1,
          maxSelection: 1,
          items: flavorItems,
        ),
      );
    }

    return flavorGroups;
  }

  /// Cria o grupo de preferências (massa + borda combinadas)
  static OptionGroup? createPreferencesGroup(Category category) {
    final doughGroup = category.optionGroups.firstWhereOrNull(
      (g) => g.groupType == OptionGroupType.crust,
    );

    final edgeGroup = category.optionGroups.firstWhereOrNull(
      (g) => g.groupType == OptionGroupType.edge,
    );

    if (doughGroup == null || edgeGroup == null) return null;

    final List<OptionItem> combos = [];

    // Gera todas as combinações de massa + borda
    // ✅ CORREÇÃO: Limpa prefixos duplicados e usa IDs reais
    for (var dough in doughGroup.items.where((item) => item.isActive)) {
      for (var edge in edgeGroup.items.where((item) => item.isActive)) {
        // ✅ Remove prefixos duplicados dos nomes
        String cleanDoughName = dough.name;
        if (cleanDoughName.toLowerCase().startsWith('massa ')) {
          cleanDoughName = cleanDoughName.substring(6);
        }

        String cleanEdgeName = edge.name;
        while (cleanEdgeName.toLowerCase().startsWith('borda ')) {
          cleanEdgeName = cleanEdgeName.substring(6);
        }

        final comboName = 'Massa $cleanDoughName + Borda $cleanEdgeName';
        final comboPrice =
            dough.price + edge.price; // Soma dos preços em centavos

        combos.add(
          OptionItem(
            id:
                (dough.id ?? 0) * 100000 +
                (edge.id ?? 0), // ✅ UNIQUE ID COMBINADO
            name: comboName,
            price: comboPrice,
            isActive: true,
            parentCustomizationOptionId: edge.id, // Fallback legacy
            crustId: dough.id, // ID real da massa
            edgeId: edge.id, // ID real da borda
            crustName: dough.name,
            edgeName: edge.name,
            crustPrice: dough.price,
            edgePrice: edge.price,
          ),
        );
      }
    }

    if (combos.isEmpty) return null;

    return OptionGroup(
      id: kPreferencesGroupId, // ID virtual negativo (-999)
      name: 'Escolha a sua Preferência',
      groupType:
          OptionGroupType
              .generic, // Usa GENERIC ao invés de preference que não existe
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
      if (category.productOptionGroups!.containsKey(sizeProductId)) {
        // Busca os optionGroups específicos deste tamanho
        final productGroups = category.productOptionGroups![sizeProductId]!;

        // Filtra e transforma os grupos de sabores (TOPPING)
        final rawToppingGroups =
            productGroups
                .where((g) => g.groupType == OptionGroupType.topping)
                .toList();

        if (rawToppingGroups.isNotEmpty) {
          final maxFlavors = getMaxFlavorsFromSize(size);
          print(
            '🍕 [PizzaAdapter] rawToppingGroups: ${rawToppingGroups.length} grupos, maxFlavors: $maxFlavors',
          );
          for (final g in rawToppingGroups) {
            print('   └─ Grupo "${g.name}": ${g.items.length} items');
          }

          if (maxFlavors > 1) {
            // ✅ FORMATO CANÔNICO: Sempre usa _createFlavorGroupsFromOptionItems
            // O backend garante formato único (1 grupo TOPPING raw com prices_by_size)
            // tanto na carga inicial quanto no category_updated.
            // Esta função faz o split em N flavor groups com dedup por ID.
            flavorGroups = _createFlavorGroupsFromOptionItems(
              rawToppingGroups,
              size,
              maxFlavors,
            );
            print('   ✅ Criados ${flavorGroups.length} flavor groups');
          } else {
            // Se apenas 1 sabor, apenas formata o preço e nome do grupo único
            flavorGroups =
                rawToppingGroups.map((group) {
                  return OptionGroup(
                    id: group.id,
                    name: group.name,
                    groupType: OptionGroupType.flavor,
                    minSelection: group.minSelection,
                    maxSelection: group.maxSelection,
                    items:
                        group.items.map((item) {
                          final priceForSize =
                              item.getPriceForSize(size.id) ??
                              item.getPriceForSize(size.linkedProductId) ??
                              item.price;
                          return OptionItem(
                            id: item.id,
                            name: item.name,
                            description: item.description,
                            price: priceForSize,
                            isActive: item.isActive,
                            image: item.image,
                          );
                        }).toList(),
                  );
                }).toList();
          }
        }
      } else {
        AppLogger.w(
          "⚠️ [PizzaAdapter] sizeProductId $sizeProductId não encontrado no productOptionGroups",
        );
      }
    } else {
      AppLogger.w(
        "⚠️ [PizzaAdapter] productOptionGroups é null, usando fallback",
      );
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

    if (category.productOptionGroups != null &&
        category.productOptionGroups!.containsKey(sizeProductId)) {
      // Busca os optionGroups específicos deste tamanho
      final productGroups = category.productOptionGroups![sizeProductId]!;

      // ✅ Identifica grupos de Massa e Borda pelo groupType enum
      final doughGroup = productGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.crust,
      );
      final edgeGroup = productGroups.firstWhereOrNull(
        (g) => g.groupType == OptionGroupType.edge,
      );

      // ✅ Se tem ambos, cria grupo combinado de preferências
      if (doughGroup != null && edgeGroup != null) {
        print(
          "🔀 [PizzaAdapter] Combinando grupos de Massa e Borda em um único grupo de Preferências",
        );

        final List<OptionItem> combos = [];
        for (var dough in doughGroup.items.where((item) => item.isActive)) {
          for (var edge in edgeGroup.items.where((item) => item.isActive)) {
            // ✅ CORREÇÃO: Remove prefixos duplicados dos nomes
            // Ex: "Massa Tradicional" -> "Tradicional" (para depois adicionar "Massa ")
            // Ex: "Borda de Catupiry" -> "de Catupiry" (para depois adicionar "Borda ")
            String cleanDoughName = dough.name;
            if (cleanDoughName.toLowerCase().startsWith('massa ')) {
              cleanDoughName = cleanDoughName.substring(6); // Remove "Massa "
            }

            String cleanEdgeName = edge.name;
            // Remove múltiplos prefixos "Borda " se existirem
            while (cleanEdgeName.toLowerCase().startsWith('borda ')) {
              cleanEdgeName = cleanEdgeName.substring(6); // Remove "Borda "
            }

            // ✅ Monta o nome combinado com prefixos corretos
            final comboName = 'Massa $cleanDoughName + Borda $cleanEdgeName';
            final comboPrice = dough.price + edge.price;

            combos.add(
              OptionItem(
                id: (dough.id ?? 0) * 100000 + (edge.id ?? 0),
                name: comboName,
                price: comboPrice,
                isActive: true,
                parentCustomizationOptionId: edge.id,
                crustId: dough.id, // ID real da massa
                edgeId: edge.id, // ID real da borda
                crustName: dough.name,
                edgeName: edge.name,
                crustPrice: dough.price,
                edgePrice: edge.price,
              ),
            );
          }
        }

        if (combos.isNotEmpty) {
          preferencesGroup = OptionGroup(
            id: kPreferencesGroupId, // ID virtual negativo (-999)
            name: 'Escolha a sua preferência',
            groupType: OptionGroupType.generic,
            minSelection: 1,
            maxSelection: 1,
            items: combos,
          );
          print(
            "✅ [PizzaAdapter] Grupo de preferências criado com ${combos.length} combinações",
          );
        }
      }

      // ✅ Outros grupos que não são TOPPING, MASSA ou BORDA
      otherGroups =
          productGroups.where((g) {
            if (g.groupType == OptionGroupType.topping) return false;
            if (g.groupType == OptionGroupType.crust) return false;
            if (g.groupType == OptionGroupType.edge) return false;
            return true;
          }).toList();

      print(
        "✅ [PizzaAdapter] Grupos extras encontrados: ${otherGroups.length}",
      );
    } else {
      print("⚠️ [PizzaAdapter] Usando fallback para preferências (bloco else)");
      // ✅ Fallback: Usa createPreferencesGroup da categoria original
      preferencesGroup = createPreferencesGroup(category);

      // Outros grupos que não são SIZE, TOPPING, MASSA ou BORDA
      otherGroups =
          category.optionGroups.where((g) {
            if (g.groupType == OptionGroupType.size) return false;
            if (g.groupType == OptionGroupType.topping) return false;
            if (g.groupType == OptionGroupType.flavor) return false;
            if (g.groupType == OptionGroupType.crust) return false;
            if (g.groupType == OptionGroupType.edge) return false;
            return true;
          }).toList();
    }

    // ✅ MENUHUB STYLE: Ordem correta dos grupos
    // 1. Preferências (Massa + Borda) - PRIMEIRO
    // 2. Sabores
    // 3. Outros grupos extras

    print("🛠️ [PizzaAdapter] Montando lista final de grupos...");
    final adaptedGroups = <OptionGroup>[];

    if (preferencesGroup != null) {
      print(
        "   👉 [1] Adicionando Preferências (${preferencesGroup.items.length} itens)",
      );
      adaptedGroups.add(preferencesGroup);
    } else {
      print("   ⚠️ [1] Preferências é NULL - não adicionado");
    }

    if (flavorGroups.isNotEmpty) {
      print("   👉 [2] Adicionando ${flavorGroups.length} grupos de Sabores");
      adaptedGroups.addAll(flavorGroups);
    }

    if (otherGroups.isNotEmpty) {
      print("   👉 [3] Adicionando ${otherGroups.length} grupos Extras");
      adaptedGroups.addAll(otherGroups);
    }

    print("🏁 [PizzaAdapter] Total de grupos final: ${adaptedGroups.length}");
    for (var i = 0; i < adaptedGroups.length; i++) {
      print(
        "   [$i] ${adaptedGroups[i].name} (type: ${adaptedGroups[i].groupType})",
      );
    }

    // ✅ REORDENAÇÃO FINAL FORÇADA (BALA DE PRATA)
    // Garante que o grupo "Escolha a sua preferência" fique SEMPRE no topo,
    // corrigindo casos onde ele pode ter entrado na lista errada (ex: vindo como flavorGroup)
    final prefIndex = adaptedGroups.indexWhere(
      (g) => g.name.toLowerCase().contains('preferência'),
    );
    if (prefIndex > 0) {
      // Se existe e não está na primeira posição
      print(
        "🔄 [PizzaAdapter] Grupo '${adaptedGroups[prefIndex].name}' encontrado na posição $prefIndex, movendo para o topo (posição 0).",
      );
      final prefGroup = adaptedGroups.removeAt(prefIndex);
      adaptedGroups.insert(0, prefGroup);

      // Log da nova ordem
      print("🏁 [PizzaAdapter] Nova ordem após correção:");
      for (var i = 0; i < adaptedGroups.length; i++) {
        print("   [$i] ${adaptedGroups[i].name}");
      }
    }

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
      productOptionGroups:
          category.productOptionGroups, // ✅ Preserva productOptionGroups
    );

    // ✅ TÍTULO: Constrói nome completo do tamanho (igual ao Menuhub)
    // Na carga inicial já vem completo: "GRANDE 4 SABORES (8 PEDAÇOS)"
    // No category_updated pode vir curto: "Grande" — então reconstrói a partir dos campos
    String displayName = size.name;
    if (!RegExp(r'SABORES?', caseSensitive: false).hasMatch(displayName)) {
      final parts = <String>[displayName.toUpperCase()];
      final mf = size.maxFlavors ?? getMaxFlavorsFromSize(size);
      if (mf > 1) {
        parts.add('$mf SABORES');
      } else if (mf == 1) {
        parts.add('1 SABOR');
      }
      if (size.slices != null && size.slices! > 0) {
        parts.add('(${size.slices} PEDAÇOS)');
      }
      displayName = parts.join(' ');
    }

    // ✅ IMAGEM: Prioriza imagem do tamanho > produto original > categoria
    List<ImageModel> displayImages = [];
    if (size.image != null && size.image!.url.isNotEmpty) {
      displayImages.add(size.image!);
      print("✅ [PizzaAdapter] Usando imagem do tamanho: ${size.image!.url}");
    } else if (originalProduct.images.isNotEmpty) {
      displayImages.addAll(originalProduct.images);
      print(
        "✅ [PizzaAdapter] Usando imagem do produto original: ${originalProduct.images.first.url}",
      );
    } else if (category.image != null) {
      displayImages.add(category.image!);
      print(
        "✅ [PizzaAdapter] Usando imagem da categoria: ${category.image!.url}",
      );
    } else {
      print("⚠️ [PizzaAdapter] Nenhuma imagem encontrada para o produto");
    }

    // Cria produto adaptado com nome do tamanho completo
    // ✅ CRÍTICO: Usa o linkedProductId do tamanho se disponível, senão do produto original
    final finalLinkedProductId =
        size.linkedProductId ?? originalProduct.linkedProductId;

    print("🔍 [PizzaAdapter] Adaptando produto:");
    print("   - originalProduct.id: ${originalProduct.id}");
    print(
      "   - originalProduct.linkedProductId: ${originalProduct.linkedProductId}",
    );
    print("   - size.id: ${size.id}");
    print("   - size.linkedProductId: ${size.linkedProductId}");
    print("   - finalLinkedProductId: $finalLinkedProductId");

    final adaptedProduct = Product(
      id: originalProduct.id,
      name: displayName, // ✅ Nome completo do tamanho (igual ao Menuhub)
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
      linkedProductId:
          finalLinkedProductId, // ✅ Usa linkedProductId do tamanho se disponível
    );

    return PizzaAdaptationResult(adaptedProduct, adaptedCategory);
  }
}
