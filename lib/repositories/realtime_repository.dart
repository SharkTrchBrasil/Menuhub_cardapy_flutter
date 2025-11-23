import 'dart:async';

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/store.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/models/store_hour.dart';
import 'package:totem/models/scheduled_pause.dart';
import 'package:totem/models/store_operation_config.dart';
import 'package:totem/models/coupon.dart';
import 'package:totem/models/delivery_fee_rule.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/banners.dart';
import '../models/cart.dart';
import '../models/coupon.dart';
import '../models/create_order_payload.dart';
import '../models/new_order.dart';
import '../models/order.dart';
import '../models/rating_summary.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/update_cart_payload.dart';
import '../models/notification.dart';
import '../services/urgent_notification_service.dart';
import 'auth_repository.dart';


class RealtimeRepository {

  RealtimeRepository(this._dsThemeSwitcher);

  late IO.Socket _socket;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const int _baseReconnectDelay = 1000; // 1s
  static const int _maxReconnectDelay = 30000; // 30s
  
  // ✅ NOVO: Gerenciamento de token de conexão
  String? _currentConnectionToken;
  Timer? _tokenRenewalTimer;
  bool _isRenewingToken = false;
  Completer<void>? _reconnectionCompleter;
  String? _storeUrl; // Armazena store_url para renovação de token

  final DsThemeSwitcher _dsThemeSwitcher;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // ✅ Constante para chave de armazenamento
  static const String _keyStoreUrl = 'store_url';

  final BehaviorSubject<Store> storeController = BehaviorSubject<Store>();

  final BehaviorSubject<List<Product>> productsController = BehaviorSubject<List<Product>>();

  final BehaviorSubject<List<BannerModel>> bannersController = BehaviorSubject<List<BannerModel>>();

// CHANGE THIS LINE:
  final BehaviorSubject<Order> orderController = BehaviorSubject<Order>(); // Changed to BehaviorSubject


  Future<void> initialize(String connectionToken) async {
    final completer = Completer<void>();

    // ✅ Salva o token atual e o store_url para renovação futura
    _currentConnectionToken = connectionToken;
    _storeUrl = await _secureStorage.read(key: _keyStoreUrl);

    final apiUrl = dotenv.env['API_URL'];

    // --- ✅ 2. MUDANÇA NA CONSTRUÇÃO DA URL ---
    // O parâmetro da query agora é `connection_token`.
    final uri = '$apiUrl?connection_token=$connectionToken';

    print("🔌 RealtimeRepository: Conectando ao servidor...");
    print('🛠️ URL de conexão: $uri');

    // ✅ ENTERPRISE: Configuração otimizada de reconexão com backoff exponencial
    _socket = IO.io(
      uri,
      IO.OptionBuilder()
          .setTransports(<String>['websocket', 'polling']) // ✅ Fallback para polling se WebSocket falhar
          .disableAutoConnect()
          // ✅ ENTERPRISE: Melhor lógica de reconexão
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(_baseReconnectDelay)
          .setReconnectionDelayMax(_maxReconnectDelay)
          .setRandomizationFactor(0.1) // ✅ Adiciona variação aleatória para evitar thundering herd
          .build(),
    );

    // ✅ LISTENERS ESSENCIAIS (permanecem iguais)
    _socket.on('connect', (_) {
      print('✅ Socket.IO: Conectado com sucesso!');
      if (!completer.isCompleted) completer.complete();
    });

    _socket.on('connect_error', (error) {
      print('❌ Socket.IO: Erro de conexão: $error');
      
      // ✅ NOVO: Detecta erro de token inválido e renova automaticamente
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') || 
          errorString.contains('expired') || 
          errorString.contains('used connection token') ||
          errorString.contains('connection token')) {
        print('🔄 Token de conexão inválido/expirado. Iniciando renovação automática...');
        _renewConnectionTokenAndReconnect();
      } else if (!completer.isCompleted) {
        completer.completeError('Erro ao conectar: $error');
      }
    });

    // ✅ MELHOR TRATAMENTO DE RECONEXÃO
    _socket.on('reconnect_attempt', (_) {
      _reconnectAttempts++;
      final exponentialDelay = _baseReconnectDelay * (1 << (_reconnectAttempts - 1).clamp(0, 5));
      final delay = exponentialDelay.clamp(0, _maxReconnectDelay);
      print('???? Socket.IO: Tentativa de reconexão #$_reconnectAttempts (próxima em ${delay}ms)...');
    });

    _socket.on('reconnect', (_) {
      _reconnectAttempts = 0; // ✅ Reset ao reconectar com sucesso
      print('???? Socket.IO: Reconectado com sucesso!');
      // Aqui você pode recarregar estado da aplicação se necessário
    });

    _socket.on('reconnect_error', (error) {
      print('❌ Socket.IO: Erro ao reconectar: $error');
      // ✅ NOVO: Detecta erro de token inválido durante reconexão
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') || 
          errorString.contains('expired') || 
          errorString.contains('used connection token')) {
        print('🔄 Token inválido durante reconexão. Renovando token...');
        _renewConnectionTokenAndReconnect();
      }
    });

    _socket.on('reconnect_failed', (_) {
      print('❌ Socket.IO: Falha ao reconectar após máximo de tentativas');
      // ✅ NOVO: Tenta renovar token e reconectar quando todas as tentativas falharem
      print('🔄 Tentando renovar token de conexão e reconectar...');
      _renewConnectionTokenAndReconnect();
    });

    // ✅ NOVO: Listener para notificações urgentes
    _socket.on('urgent_notifications', (data) {
      print('🚨 Notificações urgentes recebidas!');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final List notificationsData = payload['notifications'] as List;
        
        final List<NotificationItem> notifications = notificationsData
            .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        print('📢 Processando ${notifications.length} notificações urgentes');
        
        // Processa notificações urgentes
        final urgentService = UrgentNotificationService();
        urgentService.processUrgentNotifications(notifications);
      } catch (e, stackTrace) {
        print('❌ Erro ao processar notificações urgentes: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('initial_state_loaded', (data) {
      print('🎉 Estado inicial carregado recebido!');
      print('📊 Tipo de dados recebidos: ${data.runtimeType}');

      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;

        print('🔑 Chaves do payload: ${payload.keys.toList()}');

        // Processa a loja
        if (payload['store'] != null) {
          print('🏪 Processando dados da loja...');
          final storeData = payload['store'] as Map<String, dynamic>;
          print('   ├─ Store raw data keys: ${storeData.keys.toList()}');
          
          // ✅ DEBUG: Verifica se payment_method_groups está presente
          if (storeData.containsKey('payment_method_groups')) {
            final groups = storeData['payment_method_groups'] as List?;
            print('   ├─ ✅ payment_method_groups encontrado: ${groups?.length ?? 0} grupos');
            if (groups != null && groups.isNotEmpty) {
              for (var group in groups.take(3)) {
                final groupMap = group as Map<String, dynamic>;
                final methods = groupMap['methods'] as List?;
                print('      └─ Grupo "${groupMap['name']}": ${methods?.length ?? 0} métodos');
              }
            }
          } else {
            print('   ├─ ❌ payment_method_groups NÃO encontrado no JSON!');
          }

          final Store store = Store.fromJson(storeData);
          storeController.add(store);

          print('✅ Loja processada:');
          print('   ├─ Nome: ${store.name}');
          print('   ├─ ID: ${store.id}');
          print('   ├─ Grupos de pagamento: ${store.paymentMethodGroups.length}');
          print('   └─ Categorias: ${store.categories.length}');
          
          // ✅ DEBUG: Lista grupos de pagamento processados
          for (var group in store.paymentMethodGroups) {
            print('      └─ Pagamento: ${group.name} (${group.methods.length} métodos)');
          }

          for (var cat in store.categories) {
            print('      └─ ${cat.name} (ID: ${cat.id}, priority: ${cat.priority})');
          }
        }

        // Processa produtos
        if (payload['products'] != null) {
          print('📦 Processando produtos...');
          print('   ├─ Tipo: ${payload['products'].runtimeType}');
          print('   ├─ Quantidade: ${(payload['products'] as List).length}');

          final List<Product> products = (payload['products'] as List)
              .map((json) {
            print('      ├─ Processando produto: ${json['name']} (ID: ${json['id']})');
            return Product.fromJson(json);
          })
              .toList();

          productsController.add(products);

          print('✅ Produtos processados:');
          print('   └─ Total: ${products.length}');


          if (products.length > 3) {
            print('      └─ ... e mais ${products.length - 3} produtos');
          }
        } else {
          print('⚠️ payload["products"] é NULL!');
        }

        // Processa banners
        if (payload['banners'] != null) {
          print('🎨 Processando ${(payload['banners'] as List).length} banners...');
          final List<BannerModel> banners = (payload['banners'] as List)
              .map((json) => BannerModel.fromJson(json))
              .toList();
          bannersController.add(banners);
          print('✅ Banners processados');
        }

        print('🎉 Estado inicial carregado com sucesso!');
      } catch (e, stackTrace) {
        print('❌ Erro ao processar initial_state_loaded: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });


    // ✅ P1: EVENTOS DE DADOS DO BACKEND com suporte a delta updates
    // ✅ CORREÇÃO: Escuta 'products_updated' (com 'd') que é o evento emitido pelo backend
    _socket.on('products_updated', (data) {
      print('📦 Produtos atualizados recebidos');
      
      try {
        // ✅ Processa payload do backend que vem como Map com 'products' e 'categories'
        if (data is Map && data.containsKey('products')) {
          final List<dynamic> productsJson = data['products'] as List<dynamic>;
          final List<Product> products = productsJson.map((json) => Product.fromJson(json)).toList();
          productsController.add(products);
          print('✅ ${products.length} produtos atualizados no totem');
        } else if (data is Map && data.containsKey('type') && data['type'] == 'delta_update') {
          // ✅ P1: Processa delta update se for mensagem delta
          _handleDeltaUpdate(data as Map<String, dynamic>);
        } else if (data is List) {
          // ✅ Compatibilidade: Se vier como lista direta
          final List<Product> products = (data as List).map((json) => Product.fromJson(json)).toList();
          productsController.add(products);
        } else {
          print('⚠️ Formato de dados de produtos_updated não reconhecido: ${data.runtimeType}');
        }
      } catch (e, stackTrace) {
        print('❌ Erro ao processar products_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('banners_update', (data) {
      print('🎨 Banners atualizados recebidos');
      final List<BannerModel> banners = (data as List).map((json) => BannerModel.fromJson(json)).toList();
      bannersController.add(banners);
    });

    // ✅ LISTENER: Atualizações de loja (quando admin atualiza configurações)
    _socket.on('store_details_updated', (data) {
      print('🏪 store_details_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        if (payload['store'] != null) {
          final storeData = payload['store'] as Map<String, dynamic>;
          
          // ✅ DEBUG: Verifica payment_method_groups
          if (storeData.containsKey('payment_method_groups')) {
            final groups = storeData['payment_method_groups'] as List?;
            print('   ├─ ✅ payment_method_groups: ${groups?.length ?? 0} grupos');
          } else {
            print('   ├─ ❌ payment_method_groups NÃO encontrado!');
          }
          
          final Store updatedStore = Store.fromJson(storeData);
          storeController.add(updatedStore);
          print('✅ Loja atualizada (payment_method_groups: ${updatedStore.paymentMethodGroups.length})');
        }
      } catch (e, stackTrace) {
        print('❌ Erro ao processar store_details_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ ENTERPRISE: Listeners granulares para atualizações específicas
    // Agora processa os eventos granulares para atualizar apenas a parte específica do Store
    _socket.on('payment_methods_updated', (data) {
      print('💳 [TOTEM] payment_methods_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        // Pega o store atual
        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          print('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
          return;
        }

        // Parse dos payment_method_groups
        final paymentMethodGroups = (payload['payment_method_groups'] as List<dynamic>?)
            ?.map((e) => PaymentMethodGroup.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];

        // Atualiza apenas os métodos de pagamento
        final updatedStore = currentStore.copyWith(
          paymentMethodGroups: paymentMethodGroups,
        );

        storeController.add(updatedStore);
        print('✅ [TOTEM] Métodos de pagamento atualizados (${paymentMethodGroups.length} grupos)');
      } catch (e, stackTrace) {
        print('❌ Erro ao processar payment_methods_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('store_hours_updated', (data) {
      print('🕐 [TOTEM] store_hours_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          print('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
          return;
        }

        // Parse dos hours
        final hours = (payload['hours'] as List<dynamic>?)
            ?.map((e) => StoreHour.fromJson(e))
            .toList() ?? [];

        // Atualiza apenas os horários
        final updatedStore = currentStore.copyWith(
          hours: hours,
        );

        storeController.add(updatedStore);
        print('✅ [TOTEM] Horários atualizados (${hours.length} horários)');
      } catch (e, stackTrace) {
        print('❌ Erro ao processar store_hours_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('scheduled_pauses_updated', (data) {
      print('⏸️ [TOTEM] scheduled_pauses_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          print('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
          return;
        }

        // Parse das pausas
        final pauses = (payload['pauses'] as List<dynamic>?)
            ?.map((e) => ScheduledPause.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];

        // Atualiza apenas as pausas
        final updatedStore = currentStore.copyWith(
          scheduledPauses: pauses,
        );

        storeController.add(updatedStore);
        print('✅ [TOTEM] Pausas agendadas atualizadas (${pauses.length} pausas)');
      } catch (e, stackTrace) {
        print('❌ Erro ao processar scheduled_pauses_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('operation_config_updated', (data) {
      print('⚙️ [TOTEM] operation_config_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          print('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
          return;
        }

        // Parse da operation_config
        final operationConfig = payload['operation_config'] != null
            ? StoreOperationConfig.fromJson(payload['operation_config'] as Map<String, dynamic>)
            : null;

        // Atualiza apenas a configuração operacional
        final updatedStore = currentStore.copyWith(
          store_operation_config: operationConfig,
        );

        storeController.add(updatedStore);
        print('✅ [TOTEM] Configuração operacional atualizada');
      } catch (e, stackTrace) {
        print('❌ Erro ao processar operation_config_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('store_profile_updated', (data) {
      print('👤 [TOTEM] store_profile_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          print('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
          return;
        }

        final profile = payload['profile'] as Map<String, dynamic>?;
        if (profile == null) return;

        // ✅ CORREÇÃO: Atualiza logo e banner quando image_path ou banner_path são fornecidos
        // O backend já envia as URLs completas em image_path e banner_path
        ImageModel? updatedImage;
        ImageModel? updatedBanner;
        
        if (profile['image_path'] != null && (profile['image_path'] as String).isNotEmpty) {
          updatedImage = ImageModel(url: profile['image_path'] as String);
          print('   └─ Logo atualizada: ${profile['image_path']}');
        }
        
        if (profile['banner_path'] != null && (profile['banner_path'] as String).isNotEmpty) {
          updatedBanner = ImageModel(url: profile['banner_path'] as String);
          print('   └─ Banner atualizado: ${profile['banner_path']}');
        }

        // Atualiza apenas os campos de perfil
        final updatedStore = currentStore.copyWith(
          name: profile['name'] ?? currentStore.name,
          phone: profile['phone'] ?? currentStore.phone,
          description: profile['description'] ?? currentStore.description,
          urlSlug: profile['url_slug'] ?? currentStore.urlSlug,
          zip_code: profile['zip_code'] ?? currentStore.zip_code,
          street: profile['street'] ?? currentStore.street,
          number: profile['number'] ?? currentStore.number,
          neighborhood: profile['neighborhood'] ?? currentStore.neighborhood,
          complement: profile['complement'] ?? currentStore.complement,
          city: profile['city'] ?? currentStore.city,
          state: profile['state'] ?? currentStore.state,
          instagram: profile['instagram'] ?? currentStore.instagram,
          facebook: profile['facebook'] ?? currentStore.facebook,
          tiktok: profile['tiktok'] ?? currentStore.tiktok,
          // ✅ CORREÇÃO: Atualiza logo e banner quando fornecidos
          image: updatedImage ?? currentStore.image,
          banner: updatedBanner ?? currentStore.banner,
        );

        storeController.add(updatedStore);
        print('✅ [TOTEM] Perfil da loja atualizado (incluindo logo e banner)');
      } catch (e, stackTrace) {
        print('❌ Erro ao processar store_profile_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('coupons_updated', (data) {
      print('🎫 [TOTEM] coupons_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          print('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
          return;
        }

        // Parse dos cupons
        final coupons = (payload['coupons'] as List<dynamic>?)
            ?.map((e) => Coupon.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];

        // Atualiza apenas os cupons
        final updatedStore = currentStore.copyWith(
          coupons: coupons,
        );

        storeController.add(updatedStore);
        print('✅ [TOTEM] Cupons atualizados (${coupons.length} cupons)');
      } catch (e, stackTrace) {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          print('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
          return;
        }

        final internationalization = payload['internationalization'] as Map<String, dynamic>?;
        if (internationalization == null) return;

        // Atualiza apenas os campos de internacionalização
        final updatedStore = currentStore.copyWith(
          locale: internationalization['locale'] ?? currentStore.locale,
          currencyCode: internationalization['currency_code'] ?? currentStore.currencyCode,
          timezone: internationalization['timezone'] ?? currentStore.timezone,
        );

        storeController.add(updatedStore);
        print('✅ [TOTEM] Internacionalização atualizada (locale: ${updatedStore.locale}, currency: ${updatedStore.currencyCode}, timezone: ${updatedStore.timezone})');
      } catch (e, stackTrace) {
        print('❌ Erro ao processar store_internationalization_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    // O evento `initial_state_loaded` agora é manipulado no handler de conexão do backend,
    // então não precisamos de um listener específico para ele aqui, mas para outros eventos sim.
    _socket.on('order_update', (data) {
      print('🛒 Atualização de pedido recebida');
      final Order order = Order.fromJson(data);
      orderController.add(order);
    });

    _socket.connect();

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Timeout ao conectar ao servidor');
      },
    );
  }


  // ✅ P1: Processa delta update
  void _handleDeltaUpdate(Map<String, dynamic> deltaMessage) {
    try {
      final delta = deltaMessage['delta'] as Map<String, dynamic>;
      final entityType = deltaMessage['entity_type'] as String;
      final entityId = deltaMessage['entity_id'];
      
      if (entityType == 'product') {
        // Aplica delta ao produto existente
        final currentProducts = productsController.value;
        final productIndex = currentProducts.indexWhere((p) => p.id == entityId);
        
        if (productIndex != -1) {
          final existingProduct = currentProducts[productIndex];
          final productJson = existingProduct.toJson();
          
          // Aplica delta
          delta.forEach((key, value) {
            if (value == null) {
              productJson.remove(key);
            } else {
              productJson[key] = value;
            }
          });
          
          // Recria produto atualizado
          final updatedProduct = Product.fromJson(productJson);
          final updatedProducts = List<Product>.from(currentProducts);
          updatedProducts[productIndex] = updatedProduct;
          
          productsController.add(updatedProducts);
          print('✅ Delta update aplicado ao produto $entityId');
        }
      }
    } catch (e) {
      print('❌ Erro ao processar delta update: $e');
    }
  }

  void dispose() {
    _tokenRenewalTimer?.cancel();
    storeController.close();
    productsController.close();
    bannersController.close();
    orderController.close();
    _socket.disconnect();
  }

  // ✅ NOVO: Renova token de conexão e reconecta automaticamente
  Future<void> _renewConnectionTokenAndReconnect() async {
    // Evita múltiplas renovações simultâneas
    if (_isRenewingToken) {
      print('⏳ Renovação de token já em andamento, aguardando...');
      return;
    }

    _isRenewingToken = true;
    print('🔄 Iniciando renovação automática de token de conexão...');

    try {
      // Obtém o store_url salvo ou do ambiente
      String? storeUrl = _storeUrl;
      if (storeUrl == null || storeUrl.isEmpty) {
        storeUrl = await _secureStorage.read(key: _keyStoreUrl);
      }

      if (storeUrl == null || storeUrl.isEmpty) {
        print('❌ Store URL não encontrada. Não é possível renovar token.');
        _isRenewingToken = false;
        return;
      }

      // ✅ Cria AuthRepository temporário para buscar novo token
      // Configura Dio com base URL correta (sem interceptors para evitar loop)
      final apiUrl = dotenv.env['API_URL'];
      final dioForRenewal = Dio(BaseOptions(
        baseUrl: '$apiUrl/app',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ));
      
      final authRepo = AuthRepository(
        dioForRenewal,
        _secureStorage,
      );

      print('🔐 Solicitando novo token de conexão para: $storeUrl');
      final authResult = await authRepo.getToken(storeUrl);

      if (authResult.isLeft) {
        print('❌ Falha ao renovar token: ${authResult.left}');
        _isRenewingToken = false;
        return;
      }

      final totemAuth = authResult.right;
      final newConnectionToken = totemAuth.connectionToken;
      
      print('✅ Novo token de conexão obtido com sucesso');

      // Desconecta socket antigo se estiver conectado
      if (_socket.connected) {
        await _socket.disconnect();
      }

      // ✅ Reconecta com novo token
      await _reconnectWithNewToken(newConnectionToken);
      
      _isRenewingToken = false;
      print('✅ Reconexão automática concluída com sucesso');
    } catch (e, stackTrace) {
      print('❌ Erro ao renovar token de conexão: $e');
      print('📍 StackTrace: $stackTrace');
      _isRenewingToken = false;
      
      // ✅ Retenta após delay (para casos de deploy ou rede instável)
      Future.delayed(const Duration(seconds: 5), () {
        if (!_socket.connected) {
          print('🔄 Retentando renovação de token após delay...');
          _renewConnectionTokenAndReconnect();
        }
      });
    }
  }

  // ✅ NOVO: Reconecta com novo token de conexão
  Future<void> _reconnectWithNewToken(String newConnectionToken) async {
    _currentConnectionToken = newConnectionToken;
    _reconnectionCompleter = Completer<void>();

    final apiUrl = dotenv.env['API_URL'];
    final uri = '$apiUrl?connection_token=$newConnectionToken';

    print('🔌 Reconectando com novo token: $uri');

    // Desconecta socket antigo
    _socket.disconnect();
    _socket.dispose();

    // Cria novo socket com novo token
    _socket = IO.io(
      uri,
      IO.OptionBuilder()
          .setTransports(<String>['websocket', 'polling'])
          .disableAutoConnect()
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(_baseReconnectDelay)
          .setReconnectionDelayMax(_maxReconnectDelay)
          .setRandomizationFactor(0.1)
          .build(),
    );

    // ✅ Reconfigura listeners essenciais
    _socket.on('connect', (_) {
      print('✅ Socket.IO: Reconectado com novo token com sucesso!');
      _reconnectAttempts = 0;
      if (!_reconnectionCompleter!.isCompleted) {
        _reconnectionCompleter!.complete();
      }
    });

    _socket.on('connect_error', (error) {
      print('❌ Socket.IO: Erro ao reconectar com novo token: $error');
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') || 
          errorString.contains('expired') || 
          errorString.contains('used connection token')) {
        print('🔄 Novo token também inválido. Aguardando e tentando novamente...');
        Future.delayed(const Duration(seconds: 3), () {
          if (!_socket.connected) {
            _renewConnectionTokenAndReconnect();
          }
        });
      }
    });

    _socket.on('reconnect_error', (error) {
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') || 
          errorString.contains('expired') || 
          errorString.contains('used connection token')) {
        print('🔄 Token inválido durante reconexão. Renovando novamente...');
        _renewConnectionTokenAndReconnect();
      }
    });

    // Reconecta eventos de dados (mantém os mesmos handlers)
    _setupDataListeners();

    // Conecta
    _socket.connect();

    // Aguarda conexão ou timeout
    try {
      await _reconnectionCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Timeout ao reconectar com novo token');
        },
      );
    } catch (e) {
      print('❌ Timeout ou erro ao reconectar: $e');
      // Retenta após delay
      Future.delayed(const Duration(seconds: 5), () {
        if (!_socket.connected) {
          _renewConnectionTokenAndReconnect();
        }
      });
    }
  }

  // ✅ NOVO: Reconfigura listeners de dados (evita duplicação)
  void _setupDataListeners() {
    // Reconecta listeners essenciais de dados
    _socket.on('initial_state_loaded', (data) {
      print('🎉 Estado inicial carregado recebido após reconexão!');
      _processInitialState(data);
    });

    _socket.on('store_details_updated', (data) {
      print('🏪 Dados da loja atualizados recebidos após reconexão');
      _processStoreUpdate(data);
    });

    // ✅ ADICIONADO: Listener para store_profile_updated (logo/banner) após reconexão
    _socket.on('store_profile_updated', (data) {
      print('👤 [TOTEM] store_profile_updated recebido (após reconexão)');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) return;

        final profile = payload['profile'] as Map<String, dynamic>?;
        if (profile == null) return;

        ImageModel? updatedImage;
        ImageModel? updatedBanner;
        
        if (profile['image_path'] != null && (profile['image_path'] as String).isNotEmpty) {
          updatedImage = ImageModel(url: profile['image_path'] as String);
        }
        
        if (profile['banner_path'] != null && (profile['banner_path'] as String).isNotEmpty) {
          updatedBanner = ImageModel(url: profile['banner_path'] as String);
        }

        final updatedStore = currentStore.copyWith(
          name: profile['name'] ?? currentStore.name,
          phone: profile['phone'] ?? currentStore.phone,
          description: profile['description'] ?? currentStore.description,
          urlSlug: profile['url_slug'] ?? currentStore.urlSlug,
          zip_code: profile['zip_code'] ?? currentStore.zip_code,
          street: profile['street'] ?? currentStore.street,
          number: profile['number'] ?? currentStore.number,
          neighborhood: profile['neighborhood'] ?? currentStore.neighborhood,
          complement: profile['complement'] ?? currentStore.complement,
          city: profile['city'] ?? currentStore.city,
          state: profile['state'] ?? currentStore.state,
          instagram: profile['instagram'] ?? currentStore.instagram,
          facebook: profile['facebook'] ?? currentStore.facebook,
          tiktok: profile['tiktok'] ?? currentStore.tiktok,
          image: updatedImage ?? currentStore.image,
          banner: updatedBanner ?? currentStore.banner,
        );

        storeController.add(updatedStore);
      } catch (e, stackTrace) {
        print('❌ Erro ao processar store_profile_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ CORREÇÃO: Escuta 'products_updated' (com 'd') que é o evento emitido pelo backend
    _socket.on('products_updated', (data) {
      print('📦 Produtos atualizados recebidos (após reconexão)');
      try {
        if (data is Map && data.containsKey('products')) {
          final List<dynamic> productsJson = data['products'] as List<dynamic>;
          final List<Product> products = productsJson.map((json) => Product.fromJson(json)).toList();
          productsController.add(products);
        } else if (data is List) {
          final List<Product> products = (data as List).map((json) => Product.fromJson(json)).toList();
          productsController.add(products);
        }
      } catch (e, stackTrace) {
        print('❌ Erro ao processar products_updated: $e');
        print('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('order_update', (data) {
      print('🛒 Atualização de pedido recebida');
      final Order order = Order.fromJson(data);
      orderController.add(order);
    });
  }

  // ✅ NOVO: Processa estado inicial (extraído para evitar duplicação)
  void _processInitialState(dynamic data) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      
      if (payload['store'] != null) {
        final storeData = payload['store'] as Map<String, dynamic>;
        final Store store = Store.fromJson(storeData);
        storeController.add(store);
      }

      if (payload['products'] != null) {
        final List<Product> products = (payload['products'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
        productsController.add(products);
      }

      if (payload['banners'] != null) {
        final List<BannerModel> banners = (payload['banners'] as List)
            .map((json) => BannerModel.fromJson(json))
            .toList();
        bannersController.add(banners);
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao processar initial_state_loaded: $e');
      print('📍 StackTrace: $stackTrace');
    }
  }

  // ✅ NOVO: Processa atualização da loja (extraído)
  void _processStoreUpdate(dynamic data) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      if (payload['store'] != null) {
        final storeData = payload['store'] as Map<String, dynamic>;
        final Store updatedStore = Store.fromJson(storeData);
        storeController.add(updatedStore);
        print('✅ Loja atualizada');
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao processar store_details_updated: $e');
      print('📍 StackTrace: $stackTrace');
    }
  }

  // ✅ NOVO: Método para reconectar manualmente
  Future<void> reconnect() async {
    if (_socket.connected) {
      print('✅ Socket.IO: Já está conectado');
      return;
    }

    print('🔡 Socket.IO: Tentando reconectar manualmente...');
    _reconnectAttempts = 0; // Reset ao reconectar manualmente
    _socket.connect();

    // Aguarda a conexão com timeout
    return Future.delayed(const Duration(seconds: 10)).then((_) {
      if (!_socket.connected) {
        throw TimeoutException('Timeout ao reconectar');
      }
    });
  }

  // ✅ NOVO: Método para verificar se está conectado
  bool get isConnected => _socket.connected;

  // ✅ NOVO: Método para obter status de reconexão
  int get reconnectAttempts => _reconnectAttempts;

  // ✅ MÉTODO `linkCustomerToSession` MAIS SEGURO
  Future<void> linkCustomerToSession(int customerId) async {
    final completer = Completer<void>();

    // Adiciona uma verificação extra para garantir que o socket está conectado
    if (!_socket.connected) {
      print("❌ RealtimeRepository: Tentativa de vincular cliente com socket desconectado.");
      completer.completeError(Exception('Socket não está conectado.'));
      return completer.future;
    }

    _socket.emitWithAck('link_customer_to_session', {'customer_id': customerId}, ack: (data) {
      if (data != null && data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(Exception(data?['error'] ?? 'Erro ao vincular cliente.'));
      }
    });

    return completer.future;
  }







  Future<Cart> getOrCreateCart() async {
    final completer = Completer<Cart>();

    // Usamos emitWithAck para esperar uma resposta do servidor.
    _socket.emitWithAck('get_or_create_cart', {}, ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        // Se sucesso, converte o JSON para nosso modelo Dart.
        final cart = Cart.fromJson(data['cart']);
        completer.complete(cart);
      } else {
        // Se falhar, completa o Future com um erro.
        completer.completeError(
          Exception(data['error'] ?? 'Erro ao buscar carrinho.'),
        );
      }
    });

    return completer.future;
  }


  Future<Cart> applyCoupon(String code) async {
    final completer = Completer<Cart>();
    _socket.emitWithAck('apply_coupon_to_cart', {'coupon_code': code}, ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        completer.complete(Cart.fromJson(data['cart']));
      } else {
        completer.completeError(Exception(data['error'] ?? 'Erro ao aplicar cupom.'));
      }
    });
    return completer.future;
  }

  Future<Cart> removeCoupon() async {
    final completer = Completer<Cart>();
    _socket.emitWithAck('remove_coupon_from_cart', {}, ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        completer.complete(Cart.fromJson(data['cart']));
      } else {
        completer.completeError(Exception(data['error'] ?? 'Erro ao remover cupom.'));
      }
    });
    return completer.future;
  }


  /// Adiciona, atualiza ou remove um item do carrinho.
  Future<Cart> updateCartItem(UpdateCartItemPayload payload) async {
    final completer = Completer<Cart>();

    _socket.emitWithAck('update_cart_item', payload.toJson(), ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        final cart = Cart.fromJson(data['cart']);
        completer.complete(cart);
      } else {
        completer.completeError(
          Exception(data['error'] ?? 'Erro ao atualizar item no carrinho.'),
        );
      }
    });

    return completer.future;
  }

  /// Remove todos os itens do carrinho.
  Future<Cart> clearCart() async {
    final completer = Completer<Cart>();

    _socket.emitWithAck('clear_cart', {}, ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        final cart = Cart.fromJson(data['cart']);
        completer.complete(cart);
      } else {
        completer.completeError(
          Exception(data['error'] ?? 'Erro ao limpar o carrinho.'),
        );
      }
    });

    return completer.future;
  }


  Future<Order> sendOrder(CreateOrderPayload payload) async {
    final completer = Completer<Order>();

    // Chama o NOVO evento do backend
    _socket.emitWithAck('create_order_from_cart', payload.toJson(), ack: (data) {
      if (data != null && data['success'] == true && data['order'] != null) {
        try {
          final order = Order.fromJson(data['order']);
          completer.complete(order);
        } catch (e) {
          completer.completeError(Exception('Erro ao processar resposta do pedido.'));
        }
      } else {
        completer.completeError(
          Exception(data?['error'] ?? 'Ocorreu um erro desconhecido ao finalizar o pedido.'),
        );
      }
    });

    return completer.future;
  }



  // Future<Either<String, Order>> sendOrder(NewOrder order) async {
  //   try {
  //     final result = await _socket.emitWithAckAsync('send_order', order.toJson());
  //     print('[SOCKET] Resposta recebida: $result');
  //
  //     if (result == null || result['success'] != true) {
  //       final errorMsg = result?['error'] ?? 'Erro desconhecido';
  //       print('[SOCKET] Erro ao enviar pedido: $errorMsg');
  //       return Left(errorMsg);
  //     }
  //
  //     return Right(Order.fromJson(result['order']));
  //   } catch (e, s) {
  //     print('Error sending order: $e\n$s');
  //     return Left('Erro ao enviar pedido');
  //   }
  // }

  /// Lista todos os cupons disponíveis.
  Future<List<Coupon>> listCoupons() async {
    final completer = Completer<List<Coupon>>();

    _socket.emitWithAck('list_coupons', {}, ack: (data) {
      if (data['error'] == null && data['coupons'] != null) {
        try {
          final coupons = (data['coupons'] as List)
              .map((json) => Coupon.fromJson(json))
              .toList();
          completer.complete(coupons);
        } catch (e) {
          completer.completeError(Exception('Erro ao processar a lista de cupons.'));
        }
      } else {
        completer.completeError(Exception(data['error'] ?? 'Erro ao buscar cupons.'));
      }
    });

    return completer.future;
  }






}