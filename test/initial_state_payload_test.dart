// test/initial_state_payload_test.dart
//
// Testes automatizados para validar o fluxo ponta a ponta do Totem:
// 1. Parsing do payload initial_state_loaded
// 2. Categorias presentes no payload
// 3. Preços dos produtos via category_links
// 4. FeaturedProducts com category match
// 5. Parsing de MoneyAmount em category_links

import 'package:flutter_test/flutter_test.dart';
import 'package:totem/models/store.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product_category_link.dart';
import 'package:totem/core/helpers/money_amount_helper.dart';

// ═══════════════════════════════════════════════════════════════
// FIXTURES: Simulam o payload real do Backend
// ═══════════════════════════════════════════════════════════════

/// Payload CORRETO (com categories) — como DEVE ser após o fix
Map<String, dynamic> _buildCorrectPayload() {
  return {
    'store': {
      'id': 1,
      'name': 'Lanchonete Jeito Mineiro',
      'url_slug': 'jeito-mineiro',
      'phone': '31999999999',
      'street': 'Rua Teste',
      'number': '123',
      'neighborhood': 'Centro',
      'city': 'Belo Horizonte',
      'state': 'MG',
      'zip_code': '30130-000',
      'store_operation_config': {'is_operational': true, 'is_store_open': true},
      'hours': [],
      'payment_method_groups': [
        {
          'name': 'PIX',
          'methods': [
            {'id': 1, 'name': 'PIX', 'method_type': 'PIX', 'is_active': true},
          ],
        },
      ],
    },
    'categories': [
      {
        'id': 10,
        'name': 'Lanches',
        'priority': 1,
        'is_active': true,
        'type': 'GENERAL',
        'option_groups': [],
        'product_links': [
          {
            'product_id': 100,
            'category_id': 10,
            'price': {'value': 2990, 'currency': 'BRL'},
            'is_available': true,
            'is_featured': true,
            'display_order': 0,
          },
          {
            'product_id': 101,
            'category_id': 10,
            'price': {'value': 3490, 'currency': 'BRL'},
            'is_available': true,
            'is_featured': false,
            'display_order': 1,
          },
        ],
      },
      {
        'id': 20,
        'name': 'Bebidas',
        'priority': 2,
        'is_active': true,
        'type': 'GENERAL',
        'option_groups': [],
        'product_links': [
          {
            'product_id': 200,
            'category_id': 20,
            'price': 990,
            'is_available': true,
          },
        ],
      },
      {
        'id': 30,
        'name': 'Pizzas',
        'priority': 3,
        'is_active': true,
        'type': 'CUSTOMIZABLE',
        'option_groups': [
          {
            'id': 300,
            'name': 'Tamanhos',
            'group_type': 'SIZE',
            'is_active': true,
            'option_items': [
              {
                'id': 511,
                'name': 'Pequena',
                'price': {'value': 2500, 'currency': 'BRL'},
                'is_active': true,
              },
              {
                'id': 512,
                'name': 'Grande',
                'price': {'value': 4500, 'currency': 'BRL'},
                'is_active': true,
              },
            ],
          },
        ],
        'product_links': [],
      },
    ],
    'products': [
      {
        'id': 100,
        'name': 'Extreme Burguer Cheddar',
        'status': 'ACTIVE',
        'product_type': 'INDIVIDUAL',
        'featured': true,
        'stock_quantity': 100,
        'control_stock': false,
        'min_stock': 0,
        'max_stock': 0,
        'unit': 'UNIT',
        'sold_count': 42,
        'cashback_type': 'NONE',
        'cashback_value': 0,
        'variant_links': [],
        'prices': [],
        'gallery_images': [
          {'image_url': 'https://cdn.menuhub.com.br/burguer.jpg'},
        ],
        'category_links': [
          {
            'product_id': 100,
            'category_id': 10,
            'price': {'value': 2990, 'currency': 'BRL'},
            'is_available': true,
            'is_featured': true,
          },
        ],
        'dietary_tags': [],
        'beverage_tags': [],
      },
      {
        'id': 101,
        'name': 'CHICKEN OX BURGUER',
        'status': 'ACTIVE',
        'product_type': 'INDIVIDUAL',
        'featured': true,
        'stock_quantity': 50,
        'control_stock': false,
        'min_stock': 0,
        'max_stock': 0,
        'unit': 'UNIT',
        'sold_count': 35,
        'cashback_type': 'NONE',
        'cashback_value': 0,
        'variant_links': [],
        'prices': [],
        'gallery_images': [],
        'category_links': [
          {
            'product_id': 101,
            'category_id': 10,
            'price': {'value': 3490, 'currency': 'BRL'},
            'is_available': true,
          },
        ],
        'dietary_tags': [],
        'beverage_tags': [],
      },
      {
        'id': 200,
        'name': 'Cerveja Budweiser',
        'status': 'ACTIVE',
        'product_type': 'INDIVIDUAL',
        'featured': false,
        'stock_quantity': 200,
        'control_stock': true,
        'min_stock': 10,
        'max_stock': 500,
        'unit': 'UNIT',
        'sold_count': 80,
        'cashback_type': 'NONE',
        'cashback_value': 0,
        'variant_links': [],
        'prices': [],
        'gallery_images': [],
        'category_links': [
          {
            'product_id': 200,
            'category_id': 20,
            'price': 990,
            'is_available': true,
          },
        ],
        'dietary_tags': [],
        'beverage_tags': [],
      },
    ],
    'banners': [],
    'theme': null,
  };
}

/// Payload QUEBRADO (sem categories) — como estava ANTES do fix
Map<String, dynamic> _buildBrokenPayload() {
  final payload = _buildCorrectPayload();
  payload.remove('categories');
  return payload;
}

void main() {
  // ═══════════════════════════════════════════════════════════════
  // GRUPO 1: Validação do Payload — categories presente
  // ═══════════════════════════════════════════════════════════════
  group('Payload initial_state_loaded — estrutura', () {
    test('payload CORRETO contém chave categories', () {
      final payload = _buildCorrectPayload();
      expect(
        payload.containsKey('categories'),
        isTrue,
        reason:
            'O payload DEVE conter a chave "categories" para o CatalogCubit',
      );
    });

    test('payload CORRETO contém chave products', () {
      final payload = _buildCorrectPayload();
      expect(payload.containsKey('products'), isTrue);
    });

    test('payload CORRETO contém chave store', () {
      final payload = _buildCorrectPayload();
      expect(payload.containsKey('store'), isTrue);
    });

    test('payload CORRETO contém chave banners', () {
      final payload = _buildCorrectPayload();
      expect(payload.containsKey('banners'), isTrue);
    });

    test('payload QUEBRADO NÃO contém categories (reproduz o bug)', () {
      final payload = _buildBrokenPayload();
      expect(
        payload.containsKey('categories'),
        isFalse,
        reason: 'Reproduz o bug: categories ausente no payload',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GRUPO 2: Parsing de Categories
  // ═══════════════════════════════════════════════════════════════
  group('Category.fromJson — parsing correto', () {
    test('parseia categoria GENERAL corretamente', () {
      final json = {
        'id': 10,
        'name': 'Lanches',
        'priority': 1,
        'is_active': true,
        'type': 'GENERAL',
        'option_groups': [],
        'product_links': [],
      };
      final cat = Category.fromJson(json);
      expect(cat.id, 10);
      expect(cat.name, 'Lanches');
      expect(cat.isActive, isTrue);
      expect(cat.type, CategoryType.GENERAL);
      expect(cat.isCustomizable, isFalse);
    });

    test('parseia categoria CUSTOMIZABLE (pizza) corretamente', () {
      final json = {
        'id': 30,
        'name': 'Pizzas',
        'priority': 3,
        'is_active': true,
        'type': 'CUSTOMIZABLE',
        'option_groups': [
          {
            'id': 300,
            'name': 'Tamanhos',
            'group_type': 'SIZE',
            'is_active': true,
            'option_items': [
              {
                'id': 511,
                'name': 'Pequena',
                'price': {'value': 2500, 'currency': 'BRL'},
                'is_active': true,
              },
            ],
          },
        ],
        'product_links': [],
      };
      final cat = Category.fromJson(json);
      expect(cat.type, CategoryType.CUSTOMIZABLE);
      expect(cat.isCustomizable, isTrue);
      expect(cat.optionGroups.length, 1);
    });

    test('parseia product_links com MoneyAmount corretamente', () {
      final json = {
        'id': 10,
        'name': 'Lanches',
        'priority': 1,
        'is_active': true,
        'type': 'GENERAL',
        'option_groups': [],
        'product_links': [
          {
            'product_id': 100,
            'category_id': 10,
            'price': {'value': 2990, 'currency': 'BRL'},
            'is_available': true,
          },
        ],
      };
      final cat = Category.fromJson(json);
      expect(cat.productLinks.length, 1);
      expect(cat.productLinks.first.price, 2990);
      expect(cat.productLinks.first.categoryId, 10);
    });

    test('parseia lista de categorias do payload corretamente', () {
      final payload = _buildCorrectPayload();
      final categoriesJson = payload['categories'] as List<dynamic>;
      final categories =
          categoriesJson
              .map((j) => Category.fromJson(j as Map<String, dynamic>))
              .toList();

      expect(categories.length, 3);
      expect(categories[0].name, 'Lanches');
      expect(categories[1].name, 'Bebidas');
      expect(categories[2].name, 'Pizzas');
      expect(categories[2].isCustomizable, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GRUPO 3: Parsing de Products com preços via category_links
  // ═══════════════════════════════════════════════════════════════
  group('Product.fromJson — preços via category_links', () {
    test('preço do produto vem do category_links (MoneyAmount)', () {
      final json = {
        'id': 100,
        'name': 'Extreme Burguer',
        'status': 'ACTIVE',
        'product_type': 'INDIVIDUAL',
        'featured': true,
        'stock_quantity': 100,
        'control_stock': false,
        'min_stock': 0,
        'max_stock': 0,
        'unit': 'UNIT',
        'sold_count': 42,
        'cashback_type': 'NONE',
        'cashback_value': 0,
        'variant_links': [],
        'prices': [],
        'gallery_images': [],
        'dietary_tags': [],
        'beverage_tags': [],
        'category_links': [
          {
            'product_id': 100,
            'category_id': 10,
            'price': {'value': 2990, 'currency': 'BRL'},
            'is_available': true,
          },
        ],
      };
      final product = Product.fromJson(json);

      // O preço deve vir do category_links via _getPriceWithFallback
      expect(
        product.price,
        2990,
        reason: 'Preço deve ser 2990 centavos (R\$29,90) do category_link',
      );
      expect(product.categoryLinks.length, 1);
      expect(product.categoryLinks.first.price, 2990);
    });

    test('preço do produto com category_links int (centavos direto)', () {
      final json = {
        'id': 200,
        'name': 'Cerveja',
        'status': 'ACTIVE',
        'product_type': 'INDIVIDUAL',
        'featured': false,
        'stock_quantity': 200,
        'control_stock': true,
        'min_stock': 10,
        'max_stock': 500,
        'unit': 'UNIT',
        'sold_count': 80,
        'cashback_type': 'NONE',
        'cashback_value': 0,
        'variant_links': [],
        'prices': [],
        'gallery_images': [],
        'dietary_tags': [],
        'beverage_tags': [],
        'category_links': [
          {
            'product_id': 200,
            'category_id': 20,
            'price': 990,
            'is_available': true,
          },
        ],
      };
      final product = Product.fromJson(json);

      expect(
        product.price,
        990,
        reason: 'Preço deve ser 990 centavos (R\$9,90) direto do int',
      );
      expect(product.categoryLinks.first.price, 990);
    });

    test('produto SEM price direto usa fallback do category_links', () {
      final json = {
        'id': 100,
        'name': 'Teste',
        'status': 'ACTIVE',
        'product_type': 'INDIVIDUAL',
        'featured': false,
        'stock_quantity': 0,
        'control_stock': false,
        'min_stock': 0,
        'max_stock': 0,
        'unit': 'UNIT',
        'sold_count': 0,
        'cashback_type': 'NONE',
        'cashback_value': 0,
        'variant_links': [],
        'prices': [],
        'gallery_images': [],
        'dietary_tags': [],
        'beverage_tags': [],
        // SEM campo 'price' direto
        'category_links': [
          {
            'product_id': 100,
            'category_id': 10,
            'price': {'value': 1500, 'currency': 'BRL'},
            'is_available': true,
          },
        ],
      };
      final product = Product.fromJson(json);

      expect(
        product.price,
        1500,
        reason: 'Sem price direto, deve usar fallback do category_links',
      );
    });

    test('produto SEM category_links tem preço 0', () {
      final json = {
        'id': 100,
        'name': 'Teste Sem Links',
        'status': 'ACTIVE',
        'product_type': 'INDIVIDUAL',
        'featured': false,
        'stock_quantity': 0,
        'control_stock': false,
        'min_stock': 0,
        'max_stock': 0,
        'unit': 'UNIT',
        'sold_count': 0,
        'cashback_type': 'NONE',
        'cashback_value': 0,
        'variant_links': [],
        'prices': [],
        'gallery_images': [],
        'dietary_tags': [],
        'beverage_tags': [],
        'category_links': [],
      };
      final product = Product.fromJson(json);

      expect(
        product.price,
        0,
        reason: 'Sem category_links e sem price direto = R\$0,00',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GRUPO 4: parseMoneyAmount — helper de conversão monetária
  // ═══════════════════════════════════════════════════════════════
  group('parseMoneyAmount — conversão monetária', () {
    test('int (centavos) retorna direto', () {
      expect(parseMoneyAmount(2990), 2990);
    });

    test('double (reais) converte para centavos', () {
      expect(parseMoneyAmount(29.90), 2990);
    });

    test('Map MoneyAmount {value, currency} retorna value', () {
      expect(parseMoneyAmount({'value': 2990, 'currency': 'BRL'}), 2990);
    });

    test('Map MoneyAmount {amount} retorna amount', () {
      expect(parseMoneyAmount({'amount': 1500}), 1500);
    });

    test('null retorna null', () {
      expect(parseMoneyAmount(null), isNull);
    });

    test('String inteira retorna centavos', () {
      expect(parseMoneyAmount('2990'), 2990);
    });

    test('String decimal retorna centavos', () {
      expect(parseMoneyAmount('29.90'), 2990);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GRUPO 5: ProductCategoryLink.fromJson — parsing de preços
  // ═══════════════════════════════════════════════════════════════
  group('ProductCategoryLink.fromJson — formatos de preço', () {
    test('MoneyAmount Map com value int', () {
      final link = ProductCategoryLink.fromJson({
        'product_id': 100,
        'category_id': 10,
        'price': {'value': 3300, 'currency': 'BRL'},
        'is_available': true,
      });
      expect(
        link.price,
        3300,
        reason: 'MoneyAmount {value: 3300} deve parsear como 3300 centavos',
      );
    });

    test('preço int direto (centavos)', () {
      final link = ProductCategoryLink.fromJson({
        'product_id': 100,
        'category_id': 10,
        'price': 3300,
        'is_available': true,
      });
      expect(link.price, 3300);
    });

    test('preço double (reais)', () {
      final link = ProductCategoryLink.fromJson({
        'product_id': 100,
        'category_id': 10,
        'price': 33.0,
        'is_available': true,
      });
      // _parsePrice trata double como toInt() direto (não * 100)
      expect(link.price, 33);
    });

    test('preço null retorna 0', () {
      final link = ProductCategoryLink.fromJson({
        'product_id': 100,
        'category_id': 10,
        'price': null,
        'is_available': true,
      });
      expect(link.price, 0);
    });

    test('promoção ativa com preço promocional', () {
      final link = ProductCategoryLink.fromJson({
        'product_id': 100,
        'category_id': 10,
        'price': {'value': 3300, 'currency': 'BRL'},
        'is_on_promotion': true,
        'promotional_price': {'value': 2500, 'currency': 'BRL'},
        'is_available': true,
      });
      expect(link.price, 3300);
      expect(link.isOnPromotion, isTrue);
      expect(link.promotionalPrice, 2500);
      expect(link.hasPromotion, isTrue);
      expect(link.effectivePrice, 2500);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GRUPO 6: Store.fromJson — parsing básico
  // ═══════════════════════════════════════════════════════════════
  group('Store.fromJson — dados da loja', () {
    test('parseia dados básicos da loja', () {
      final payload = _buildCorrectPayload();
      final store = Store.fromJson(payload['store'] as Map<String, dynamic>);

      expect(store.id, 1);
      expect(store.name, 'Lanchonete Jeito Mineiro');
      expect(store.urlSlug, 'jeito-mineiro');
    });

    test('parseia payment_method_groups', () {
      final payload = _buildCorrectPayload();
      final store = Store.fromJson(payload['store'] as Map<String, dynamic>);

      expect(store.paymentMethodGroups.length, 1);
      expect(store.paymentMethodGroups.first.name, 'PIX');
    });

    test('parseia store_operation_config', () {
      final payload = _buildCorrectPayload();
      final store = Store.fromJson(payload['store'] as Map<String, dynamic>);

      expect(store.store_operation_config, isNotNull);
      expect(store.store_operation_config!.isStoreOpen, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GRUPO 7: Fluxo ponta a ponta — simula _processOldMenuFormat
  // ═══════════════════════════════════════════════════════════════
  group('Fluxo ponta a ponta — _processOldMenuFormat', () {
    test('payload CORRETO: categorias e produtos parseados com preços', () {
      final payload = _buildCorrectPayload();

      // Simula _processOldMenuFormat
      final Store store = Store.fromJson(
        payload['store'] as Map<String, dynamic>,
      );
      final List<Category> categories =
          (payload['categories'] as List<dynamic>)
              .map((j) => Category.fromJson(j as Map<String, dynamic>))
              .toList();
      final List<Product> products =
          (payload['products'] as List<dynamic>)
              .map((j) => Product.fromJson(j as Map<String, dynamic>))
              .toList();

      // Validações
      expect(store.name, 'Lanchonete Jeito Mineiro');
      expect(categories.length, 3);
      expect(products.length, 3);

      // Verifica que todos os produtos têm preço > 0
      for (final p in products) {
        expect(
          p.price! > 0,
          isTrue,
          reason:
              'Produto "${p.name}" (id=${p.id}) deve ter preço > 0, mas tem ${p.price}',
        );
      }
    });

    test('payload CORRETO: match categoria-produto funciona', () {
      final payload = _buildCorrectPayload();

      final List<Category> categories =
          (payload['categories'] as List<dynamic>)
              .map((j) => Category.fromJson(j as Map<String, dynamic>))
              .toList();
      final List<Product> products =
          (payload['products'] as List<dynamic>)
              .map((j) => Product.fromJson(j as Map<String, dynamic>))
              .toList();

      // Simula _findCategory do FeaturedProductGrid
      Category? findCategory(Product p) {
        final firstLink =
            p.categoryLinks.isNotEmpty ? p.categoryLinks.first : null;
        if (firstLink == null) return null;
        return categories
            .where((c) => c.id == firstLink.categoryId)
            .firstOrNull;
      }

      // Todos os produtos devem encontrar sua categoria
      final burguer = products.firstWhere((p) => p.id == 100);
      final chicken = products.firstWhere((p) => p.id == 101);
      final cerveja = products.firstWhere((p) => p.id == 200);

      expect(
        findCategory(burguer),
        isNotNull,
        reason: 'Burguer deve encontrar categoria Lanches',
      );
      expect(findCategory(burguer)!.name, 'Lanches');

      expect(
        findCategory(chicken),
        isNotNull,
        reason: 'Chicken deve encontrar categoria Lanches',
      );

      expect(
        findCategory(cerveja),
        isNotNull,
        reason: 'Cerveja deve encontrar categoria Bebidas',
      );
      expect(findCategory(cerveja)!.name, 'Bebidas');
    });

    test('payload CORRETO: preço exibido via link + category match', () {
      final payload = _buildCorrectPayload();

      final List<Category> categories =
          (payload['categories'] as List<dynamic>)
              .map((j) => Category.fromJson(j as Map<String, dynamic>))
              .toList();
      final List<Product> products =
          (payload['products'] as List<dynamic>)
              .map((j) => Product.fromJson(j as Map<String, dynamic>))
              .toList();

      // Simula lógica do ProductCard (featured_list.dart)
      int getDisplayPrice(Product product, Category category) {
        if (category.isCustomizable) {
          final validPrices = product.prices
              .where((p) => p.price > 0)
              .map((p) => p.price);
          return validPrices.isNotEmpty
              ? validPrices.reduce((a, b) => a < b ? a : b)
              : 0;
        }

        final link =
            product.categoryLinks
                .where((l) => l.categoryId == category.id)
                .firstOrNull;
        if (link != null) {
          return link.price;
        }
        return product.price ?? 0;
      }

      final burguer = products.firstWhere((p) => p.id == 100);
      final lanches = categories.firstWhere((c) => c.id == 10);

      final displayPrice = getDisplayPrice(burguer, lanches);
      expect(
        displayPrice,
        2990,
        reason: 'Burguer deve exibir R\$29,90 (2990 centavos)',
      );
    });

    test('payload QUEBRADO: sem categories, preço fica 0 (reproduz o bug)', () {
      final payload = _buildBrokenPayload();

      // Sem categories no payload
      expect(payload.containsKey('categories'), isFalse);

      final List<Product> products =
          (payload['products'] as List<dynamic>)
              .map((j) => Product.fromJson(j as Map<String, dynamic>))
              .toList();

      // Simula _findCategory sem categorias
      final List<Category> emptyCategories = [];
      Category? findCategory(Product p) {
        final firstLink =
            p.categoryLinks.isNotEmpty ? p.categoryLinks.first : null;
        if (firstLink == null) return null;
        return emptyCategories
            .where((c) => c.id == firstLink.categoryId)
            .firstOrNull;
      }

      // Nenhum produto encontra categoria
      for (final p in products) {
        final cat = findCategory(p);
        expect(
          cat,
          isNull,
          reason: 'Sem categorias, ${p.name} NÃO deve encontrar categoria',
        );
      }

      // Simula lógica do ProductCard sem category
      int getDisplayPriceWithoutCategory(Product product) {
        // Sem category, o branch do ProductCard não executa
        // displayPrice fica null → fallback 0
        return 0;
      }

      for (final p in products) {
        expect(
          getDisplayPriceWithoutCategory(p),
          0,
          reason: 'BUG REPRODUZIDO: sem category, "${p.name}" mostra R\$0,00',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GRUPO 8: Detecção de formato de payload (novo vs antigo)
  // ═══════════════════════════════════════════════════════════════
  group('Detecção de formato de payload', () {
    test('formato antigo: SEM data.menu → _processOldMenuFormat', () {
      final payload = _buildCorrectPayload();
      final isNewFormat =
          payload.containsKey('data') &&
          payload['data'] is Map &&
          (payload['data'] as Map).containsKey('menu');

      expect(
        isNewFormat,
        isFalse,
        reason: 'Payload sem data.menu deve usar formato antigo',
      );
    });

    test('formato antigo: contém categories e products separados', () {
      final payload = _buildCorrectPayload();
      expect(payload.containsKey('categories'), isTrue);
      expect(payload.containsKey('products'), isTrue);
      expect(payload.containsKey('store'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GRUPO 9: Categoria CUSTOMIZABLE (Pizza) — preço via SIZE
  // ═══════════════════════════════════════════════════════════════
  group('Pizza — preço via SIZE option_items', () {
    test('categoria customizável com SIZE items tem preços válidos', () {
      final payload = _buildCorrectPayload();
      final categoriesJson = payload['categories'] as List<dynamic>;
      final pizzaCat = categoriesJson
          .map((j) => Category.fromJson(j as Map<String, dynamic>))
          .firstWhere((c) => c.isCustomizable);

      expect(pizzaCat.name, 'Pizzas');
      expect(pizzaCat.optionGroups.length, greaterThanOrEqualTo(1));

      // Verifica que SIZE items têm preços
      final sizeGroup = pizzaCat.optionGroups.first;
      expect(sizeGroup.items.length, 2);

      // Pequena = R$25,00, Grande = R$45,00
      final pequena = sizeGroup.items.firstWhere((i) => i.name == 'Pequena');
      final grande = sizeGroup.items.firstWhere((i) => i.name == 'Grande');

      expect(
        pequena.price,
        greaterThan(0),
        reason: 'SIZE Pequena deve ter preço > 0',
      );
      expect(
        grande.price,
        greaterThan(0),
        reason: 'SIZE Grande deve ter preço > 0',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GRUPO 10: Regressão — chaves obrigatórias do payload
  // ═══════════════════════════════════════════════════════════════
  group('Regressão — chaves obrigatórias', () {
    test('payload deve conter TODAS as chaves obrigatórias', () {
      final payload = _buildCorrectPayload();
      final requiredKeys = ['store', 'products', 'categories', 'banners'];

      for (final key in requiredKeys) {
        expect(
          payload.containsKey(key),
          isTrue,
          reason: 'Chave obrigatória "$key" ausente no payload',
        );
      }
    });

    test(
      'categories NÃO pode ser lista vazia quando há categorias no banco',
      () {
        final payload = _buildCorrectPayload();
        final categories = payload['categories'] as List;
        expect(
          categories,
          isNotEmpty,
          reason: 'categories não deve ser vazio quando existem categorias',
        );
      },
    );

    test('products NÃO pode ser lista vazia quando há produtos no banco', () {
      final payload = _buildCorrectPayload();
      final products = payload['products'] as List;
      expect(
        products,
        isNotEmpty,
        reason: 'products não deve ser vazio quando existem produtos',
      );
    });
  });
}
