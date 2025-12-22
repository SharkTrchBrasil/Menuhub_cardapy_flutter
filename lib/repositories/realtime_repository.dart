import 'dart:async';

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/store.dart';
import 'package:totem/models/category.dart' as models;
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
import 'package:totem/core/utils/app_logger.dart';

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
// ✅ NOVO: Importa models e adapter do novo formato de menu
import '../models/menu/menu_response.dart';
import '../helpers/menu_adapter.dart';


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

    AppLogger.debug("🔌 RealtimeRepository: Conectando ao servidor...");
    AppLogger.debug('🛠️ URL de conexão: $uri');

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
      AppLogger.debug('✅ Socket.IO: Conectado com sucesso!');
      if (!completer.isCompleted) completer.complete();
    });

    _socket.on('connect_error', (error) {
      AppLogger.debug('❌ Socket.IO: Erro de conexão: $error');
      
      // ✅ NOVO: Detecta erro de token inválido e renova automaticamente
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') || 
          errorString.contains('expired') || 
          errorString.contains('used connection token') ||
          errorString.contains('connection token')) {
        AppLogger.debug('🔄 Token de conexão inválido/expirado. Iniciando renovação automática...');
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
      AppLogger.debug('???? Socket.IO: Tentativa de reconexão #$_reconnectAttempts (próxima em ${delay}ms)...');
    });

    _socket.on('reconnect', (_) {
      _reconnectAttempts = 0; // ✅ Reset ao reconectar com sucesso
      AppLogger.debug('???? Socket.IO: Reconectado com sucesso!');
      // Aqui você pode recarregar estado da aplicação se necessário
    });

    _socket.on('reconnect_error', (error) {
      AppLogger.debug('❌ Socket.IO: Erro ao reconectar: $error');
      // ✅ NOVO: Detecta erro de token inválido durante reconexão
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') || 
          errorString.contains('expired') || 
          errorString.contains('used connection token')) {
        AppLogger.debug('🔄 Token inválido durante reconexão. Renovando token...');
        _renewConnectionTokenAndReconnect();
      }
    });

    _socket.on('reconnect_failed', (_) {
      AppLogger.debug('❌ Socket.IO: Falha ao reconectar após máximo de tentativas');
      // ✅ NOVO: Tenta renovar token e reconectar quando todas as tentativas falharem
      AppLogger.debug('🔄 Tentando renovar token de conexão e reconectar...');
      _renewConnectionTokenAndReconnect();
    });

    // ✅ NOVO: Listener para notificações urgentes
    _socket.on('urgent_notifications', (data) {
      AppLogger.debug('🚨 Notificações urgentes recebidas!');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final List notificationsData = payload['notifications'] as List;
        
        final List<NotificationItem> notifications = notificationsData
            .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        AppLogger.debug('📢 Processando ${notifications.length} notificações urgentes');
        
        // Processa notificações urgentes
        final urgentService = UrgentNotificationService();
        urgentService.processUrgentNotifications(notifications);
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar notificações urgentes: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('initial_state_loaded', (data) {
      AppLogger.debug('🎉 Estado inicial carregado recebido!');
      AppLogger.debug('📊 Tipo de dados recebidos: ${data.runtimeType}');

      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;

        AppLogger.debug('🔑 Chaves do payload: ${payload.keys.toList()}');

        // ✅ NOVO: Detecta formato do menu (novo ou antigo)
        final bool isNewMenuFormat = payload.containsKey('data') && 
                                     payload['data'] is Map &&
                                     (payload['data'] as Map).containsKey('menu');

        if (isNewMenuFormat) {
          AppLogger.debug('📋 Novo formato de menu detectado (com data.menu)');
          
          // ✅ DEBUG: Imprime estrutura do menu recebido
          final dataPayload = payload['data'] as Map<String, dynamic>;
          final menuList = dataPayload['menu'] as List<dynamic>? ?? [];
          AppLogger.debug('═══════════════════════════════════════════════════════');
          AppLogger.debug('🔍 [DEBUG MENU] Total de categorias no menu: ${menuList.length}');
          for (var i = 0; i < menuList.length; i++) {
            final cat = menuList[i] as Map<String, dynamic>;
            final catCode = cat['code'];
            final catName = cat['name'];
            final catTemplate = cat['template'];
            final itens = cat['itens'] as List<dynamic>? ?? [];
            AppLogger.debug('   📁 [$i] Categoria: "$catName" (code: $catCode, template: $catTemplate)');
            AppLogger.debug('      └─ Itens: ${itens.length}');
            for (var j = 0; j < itens.length && j < 3; j++) {
              final item = itens[j] as Map<String, dynamic>;
              AppLogger.debug('         └─ Item[$j]: id=${item['id']}, code=${item['code']}, desc="${item['description']}"');
            }
            if (itens.length > 3) {
              AppLogger.debug('         └─ ... e mais ${itens.length - 3} itens');
            }
          }
          AppLogger.debug('═══════════════════════════════════════════════════════');
          
          _processNewMenuFormat(payload);
        } else {
          AppLogger.debug('📋 Formato antigo de menu detectado (com products/categories separados)');
          _processOldMenuFormat(payload);
        }

        AppLogger.debug('🎉 Estado inicial carregado com sucesso!');
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar initial_state_loaded: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });


    // ✅ P1: EVENTOS DE DADOS DO BACKEND com suporte a delta updates
    // ✅ CORREÇÃO: Escuta 'products_updated' (com 'd') que é o evento emitido pelo backend
    _socket.on('products_updated', (data) {
      AppLogger.debug('═══════════════════════════════════════════════════════');
      AppLogger.debug('📦 [PRODUCTS_UPDATED] Evento recebido!');
      AppLogger.debug('📊 Tipo de dados: ${data.runtimeType}');
      
      try {
        // ✅ Processa payload do backend que vem como Map com 'products' e 'categories'
        if (data is Map && data.containsKey('products')) {
          // ✅ DEBUG: Mostra estrutura dos produtos recebidos
          final List<dynamic> productsJson = data['products'] as List<dynamic>;
          AppLogger.debug('🔍 [PRODUCTS_UPDATED] Total de produtos recebidos: ${productsJson.length}');
          
          // Mostra os primeiros 5 produtos
          for (var i = 0; i < productsJson.length && i < 5; i++) {
            final prod = productsJson[i] as Map<String, dynamic>;
            final prodId = prod['id'];
            final prodName = prod['name'];
            final primaryCatId = prod['primary_category_id'];
            final catLinks = prod['category_links'] as List<dynamic>? ?? [];
            AppLogger.debug('   └─ Produto[$i]: id=$prodId, name="$prodName", primaryCatId=$primaryCatId, categoryLinks=${catLinks.length}');
            for (var link in catLinks.take(2)) {
              final linkMap = link as Map<String, dynamic>;
              AppLogger.debug('      └─ Link: categoryId=${linkMap['category_id']}, price=${linkMap['price']}');
            }
          }
          if (productsJson.length > 5) {
            AppLogger.debug('   └─ ... e mais ${productsJson.length - 5} produtos');
          }
          
          // ✅ DEBUG: Mostra categorias se presentes
          if (data.containsKey('categories')) {
            final List<dynamic> catsJson = data['categories'] as List<dynamic>;
            AppLogger.debug('🔍 [PRODUCTS_UPDATED] Total de categorias recebidas: ${catsJson.length}');
            for (var i = 0; i < catsJson.length && i < 5; i++) {
              final cat = catsJson[i] as Map<String, dynamic>;
              AppLogger.debug('   └─ Categoria[$i]: id=${cat['id']}, name="${cat['name']}", type=${cat['type']}');
            }
          } else {
            AppLogger.debug('⚠️ [PRODUCTS_UPDATED] Nenhuma categoria no payload!');
          }
          AppLogger.debug('═══════════════════════════════════════════════════════');
          
          // ✅ Atualiza produtos
          final List<Product> products = productsJson
              .map((json) {
                try {
                  return Product.fromJson(json);
                } catch (e) {
                  AppLogger.error('❌ Erro ao parsear produto: $e');
                  return null;
                }
              })
              .whereType<Product>()
              .toList();
          productsController.add(products);
          AppLogger.debug('✅ ${products.length} produtos atualizados no totem');
          
          // ✅ CORREÇÃO: Atualiza categorias na Store se presentes
          if (data.containsKey('categories') && storeController.hasValue) {
            try {
              final currentStore = storeController.value;
              final List<dynamic> categoriesJson = data['categories'] as List<dynamic>;
              
              // ✅ Processa e atualiza categorias
              final List<models.Category> categories = categoriesJson
                  .map((json) {
                    try {
                      return models.Category.fromJson(json as Map<String, dynamic>);
                    } catch (e) {
                      AppLogger.error('❌ Erro ao parsear categoria: $e');
                      return null;
                    }
                  })
                  .whereType<models.Category>()
                  .toList();
              
              // ✅ CORREÇÃO: Atualiza a Store com as novas categorias
              final updatedStore = currentStore.copyWith(categories: categories);
              storeController.add(updatedStore);
              AppLogger.debug('✅ ${categories.length} categorias atualizadas na Store');
            } catch (e, stackTrace) {
              AppLogger.error('❌ Erro ao atualizar categorias na Store: $e');
              AppLogger.error('📍 StackTrace: $stackTrace');
              // Não interrompe o fluxo, apenas loga o erro
            }
          }
        } else if (data is Map && data.containsKey('type') && data['type'] == 'delta_update') {
          // ✅ P1: Processa delta update se for mensagem delta
          _handleDeltaUpdate(data as Map<String, dynamic>);
        } else if (data is List) {
          // ✅ Compatibilidade: Se vier como lista direta
          final List<Product> products = (data as List)
              .map((json) {
                try {
                  return Product.fromJson(json);
                } catch (e) {
                  AppLogger.error('❌ Erro ao parsear produto: $e');
                  return null;
                }
              })
              .whereType<Product>()
              .toList();
          productsController.add(products);
        } else {
          AppLogger.warning('⚠️ Formato de dados de produtos_updated não reconhecido: ${data.runtimeType}');
          AppLogger.debug('📋 Dados recebidos: $data');
        }
      } catch (e, stackTrace) {
        AppLogger.error('❌ Erro crítico ao processar products_updated: $e');
        AppLogger.error('📍 StackTrace: $stackTrace');
        AppLogger.error('📋 Dados que causaram erro: $data');
        
        // ✅ NOVO: Notifica sobre o erro (pode ser usado para mostrar mensagem ao usuário)
        // O erro é logado mas não quebra o sistema - o usuário pode continuar usando
        // Se necessário, pode-se adicionar um controller de erros aqui
      }
    });

    // ✅ CORREÇÃO: Nome do evento alinhado com backend (banners_updated)
    _socket.on('banners_updated', (data) {
      AppLogger.debug('🎨 Banners atualizados recebidos');
      final List<BannerModel> banners = (data as List).map((json) => BannerModel.fromJson(json)).toList();
      bannersController.add(banners);
    });

    // ✅ LISTENER: Atualizações de loja (quando admin atualiza configurações)
    _socket.on('store_details_updated', (data) {
      AppLogger.debug('🏪 store_details_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        if (payload['store'] != null) {
          final storeData = payload['store'] as Map<String, dynamic>;
          
          // ✅ DEBUG: Verifica payment_method_groups
          if (storeData.containsKey('payment_method_groups')) {
            final groups = storeData['payment_method_groups'] as List?;
            AppLogger.debug('   ├─ ✅ payment_method_groups: ${groups?.length ?? 0} grupos');
          } else {
            AppLogger.debug('   ├─ ❌ payment_method_groups NÃO encontrado!');
          }
          
          final Store updatedStore = Store.fromJson(storeData);
          storeController.add(updatedStore);
          AppLogger.debug('✅ Loja atualizada (payment_method_groups: ${updatedStore.paymentMethodGroups.length})');
        }
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar store_details_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ ENTERPRISE: Listeners granulares para atualizações específicas
    // Agora processa os eventos granulares para atualizar apenas a parte específica do Store
    _socket.on('payment_methods_updated', (data) {
      AppLogger.debug('💳 [TOTEM] payment_methods_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        // Pega o store atual
        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.debug('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
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
        AppLogger.debug('✅ [TOTEM] Métodos de pagamento atualizados (${paymentMethodGroups.length} grupos)');
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar payment_methods_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ NOVO: Listener específico para delivery_fee_rules_updated
    _socket.on('delivery_fee_rules_updated', (data) {
      AppLogger.debug('🚚 [TOTEM] delivery_fee_rules_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.debug('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
          return;
        }

        // Parse das regras de frete
        final deliveryFeeRules = (payload['delivery_fee_rules'] as List<dynamic>?)
            ?.map((e) => DeliveryFeeRule.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];

        // Atualiza apenas as regras de frete
        final updatedStore = currentStore.copyWith(
          deliveryFeeRules: deliveryFeeRules,
        );

        storeController.add(updatedStore);
        AppLogger.debug('✅ [TOTEM] Regras de frete atualizadas (${deliveryFeeRules.length} regras)');
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar delivery_fee_rules_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('store_hours_updated', (data) {
      AppLogger.debug('🕐 [TOTEM] store_hours_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.debug('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
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
        AppLogger.debug('✅ [TOTEM] Horários atualizados (${hours.length} horários)');
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar store_hours_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('scheduled_pauses_updated', (data) {
      AppLogger.debug('⏸️ [TOTEM] scheduled_pauses_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.debug('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
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
        AppLogger.debug('✅ [TOTEM] Pausas agendadas atualizadas (${pauses.length} pausas)');
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar scheduled_pauses_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('operation_config_updated', (data) {
      AppLogger.debug('⚙️ [TOTEM] operation_config_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.debug('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
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
        AppLogger.debug('✅ [TOTEM] Configuração operacional atualizada');
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar operation_config_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ PAUSA PROGRAMADA: Listener para mudanças de status da loja
    _socket.on('store_status_changed', (data) {
      AppLogger.debug('⏸️ [TOTEM] store_status_changed recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.debug('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
          return;
        }

        final isOpen = payload['is_open'] as bool? ?? true;
        final reason = payload['reason'] as String?;
        final pausedUntilStr = payload['paused_until'] as String?;
        
        DateTime? pausedUntil;
        if (pausedUntilStr != null) {
          pausedUntil = DateTime.tryParse(pausedUntilStr);
        }

        AppLogger.debug('   └─ is_open: $isOpen, reason: $reason, paused_until: $pausedUntilStr');

        // Atualiza o operation_config com o novo status
        final currentConfig = currentStore.store_operation_config;
        if (currentConfig != null) {
          final updatedConfig = currentConfig.copyWith(
            isStoreOpen: isOpen,
            pausedUntil: isOpen ? null : pausedUntil, // Se abrir, limpa pausedUntil
          );

          final updatedStore = currentStore.copyWith(
            store_operation_config: updatedConfig,
          );

          storeController.add(updatedStore);
          
          if (isOpen) {
            AppLogger.debug('✅ [TOTEM] Loja REABERTA (reason: $reason)');
          } else {
            AppLogger.debug('⏸️ [TOTEM] Loja PAUSADA até $pausedUntilStr (reason: $reason)');
          }
        }
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar store_status_changed: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('store_profile_updated', (data) {
      AppLogger.debug('👤 [TOTEM] store_profile_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.debug('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
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
          AppLogger.debug('   └─ Logo atualizada: ${profile['image_path']}');
        }
        
        if (profile['banner_path'] != null && (profile['banner_path'] as String).isNotEmpty) {
          updatedBanner = ImageModel(url: profile['banner_path'] as String);
          AppLogger.debug('   └─ Banner atualizado: ${profile['banner_path']}');
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
        AppLogger.debug('✅ [TOTEM] Perfil da loja atualizado (incluindo logo e banner)');
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar store_profile_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('coupons_updated', (data) {
      AppLogger.debug('🎫 [TOTEM] coupons_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.debug('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
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
        AppLogger.debug('✅ [TOTEM] Cupons atualizados (${coupons.length} cupons)');
      } catch (e, stackTrace) {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.debug('⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)');
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
        AppLogger.debug('✅ [TOTEM] Internacionalização atualizada (locale: ${updatedStore.locale}, currency: ${updatedStore.currencyCode}, timezone: ${updatedStore.timezone})');
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar store_internationalization_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    // O evento `initial_state_loaded` agora é manipulado no handler de conexão do backend,
    // então não precisamos de um listener específico para ele aqui, mas para outros eventos sim.
    _socket.on('order_update', (data) {
      AppLogger.debug('🛒 Atualização de pedido recebida');
      final Order order = Order.fromJson(data);
      orderController.add(order);
    });

    // ============================================================
    // ✅ ENTERPRISE: LISTENERS GRANULARES PARA ATUALIZAÇÕES EM TEMPO REAL
    // Esses listeners recebem apenas o item específico que foi modificado,
    // reduzindo drasticamente o payload e melhorando a performance.
    // ============================================================

    // --- PRODUTOS ---
    _socket.on('product_created', (data) {
      AppLogger.debug('📦 [GRANULAR] Produto criado recebido');
      _handleGranularProductEvent(data, 'created');
    });

    _socket.on('product_updated', (data) {
      AppLogger.debug('📦 [GRANULAR] Produto atualizado recebido');
      _handleGranularProductEvent(data, 'updated');
    });

    _socket.on('product_deleted', (data) {
      AppLogger.debug('📦 [GRANULAR] Produto deletado recebido');
      _handleGranularProductEvent(data, 'deleted');
    });

    // --- CATEGORIAS ---
    _socket.on('category_created', (data) {
      AppLogger.debug('📁 [GRANULAR] Categoria criada recebida');
      _handleGranularCategoryEvent(data, 'created');
    });

    _socket.on('category_updated', (data) {
      AppLogger.debug('📁 [GRANULAR] Categoria atualizada recebida');
      _handleGranularCategoryEvent(data, 'updated');
    });

    _socket.on('category_deleted', (data) {
      AppLogger.debug('📁 [GRANULAR] Categoria deletada recebida');
      _handleGranularCategoryEvent(data, 'deleted');
    });

    // --- VARIANTES (Complementos) ---
    _socket.on('variant_created', (data) {
      AppLogger.debug('🧩 [GRANULAR] Variante criada recebida');
      _handleGranularVariantEvent(data, 'created');
    });

    _socket.on('variant_updated', (data) {
      AppLogger.debug('🧩 [GRANULAR] Variante atualizada recebida');
      _handleGranularVariantEvent(data, 'updated');
    });

    _socket.on('variant_deleted', (data) {
      AppLogger.debug('🧩 [GRANULAR] Variante deletada recebida');
      _handleGranularVariantEvent(data, 'deleted');
    });

    // --- OPÇÕES DE VARIANTE ---
    _socket.on('variant_option_created', (data) {
      AppLogger.debug('🔘 [GRANULAR] Opção de variante criada recebida');
      _handleGranularVariantOptionEvent(data, 'created');
    });

    _socket.on('variant_option_updated', (data) {
      AppLogger.debug('🔘 [GRANULAR] Opção de variante atualizada recebida');
      _handleGranularVariantOptionEvent(data, 'updated');
    });

    _socket.on('variant_option_deleted', (data) {
      AppLogger.debug('🔘 [GRANULAR] Opção de variante deletada recebida');
      _handleGranularVariantOptionEvent(data, 'deleted');
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
          AppLogger.debug('✅ Delta update aplicado ao produto $entityId');
        }
      }
    } catch (e) {
      AppLogger.debug('❌ Erro ao processar delta update: $e');
    }
  }

  // ============================================================
  // ✅ ENTERPRISE: HANDLERS PARA EVENTOS GRANULARES
  // Esses métodos processam eventos individuais e atualizam
  // as listas locais de forma eficiente (adicionar, atualizar, remover)
  // ============================================================

  /// Handler para eventos granulares de produtos
  void _handleGranularProductEvent(dynamic data, String action) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      final storeId = payload['store_id'] as int?;
      
      // Verifica se o evento é para a loja atual
      if (storeId != null && storeController.hasValue && storeController.value.id != storeId) {
        AppLogger.debug('⚠️ [GRANULAR] Evento de produto para outra loja (ignorado)');
        return;
      }

      if (!productsController.hasValue) {
        AppLogger.debug('⚠️ [GRANULAR] Lista de produtos não inicializada ainda');
        return;
      }

      final currentProducts = List<Product>.from(productsController.value);

      switch (action) {
        case 'created':
          // ✅ CORREÇÃO: Backend envia 'product', não 'item'
          final productData = payload['product'] as Map<String, dynamic>?;
          if (productData != null) {
            final newProduct = Product.fromJson(productData);
            
            // ✅ FILTRO: Ignora produtos com preço zero (pausados)
            final hasPrice = (newProduct.price != null && newProduct.price! > 0) ||
                newProduct.variantLinks.any((link) => 
                  link.variant.options.any((opt) => opt.resolvedPrice > 0));
            if (!hasPrice) {
              AppLogger.debug('⏸️ [GRANULAR] Produto ${newProduct.name} ignorado (preço zero)');
              return;
            }
            
            // Verifica se já existe (para evitar duplicatas)
            final existingIndex = currentProducts.indexWhere((p) => p.id == newProduct.id);
            if (existingIndex == -1) {
              currentProducts.add(newProduct);
              productsController.add(currentProducts);
              AppLogger.debug('✅ [GRANULAR] Produto ${newProduct.name} adicionado à lista');
            } else {
              AppLogger.debug('⚠️ [GRANULAR] Produto ${newProduct.id} já existe, ignorando criação');
            }
          } else {
            AppLogger.debug('⚠️ [GRANULAR] Payload sem campo "product" para criação');
          }
          break;

        case 'updated':
          // ✅ CORREÇÃO: Backend envia 'product', não 'item'
          final productData = payload['product'] as Map<String, dynamic>?;
          if (productData != null) {
            final updatedProduct = Product.fromJson(productData);
            
            // ✅ FILTRO: Verifica se produto tem preço válido
            final hasPrice = (updatedProduct.price != null && updatedProduct.price! > 0) ||
                updatedProduct.variantLinks.any((link) => 
                  link.variant.options.any((opt) => opt.resolvedPrice > 0));
            
            final existingIndex = currentProducts.indexWhere((p) => p.id == updatedProduct.id);
            
            if (hasPrice) {
              // Produto tem preço válido - adiciona ou atualiza
              if (existingIndex != -1) {
                currentProducts[existingIndex] = updatedProduct;
                productsController.add(currentProducts);
                AppLogger.debug('✅ [GRANULAR] Produto ${updatedProduct.name} atualizado na lista');
              } else {
                // Produto não existe, adiciona
                currentProducts.add(updatedProduct);
                productsController.add(currentProducts);
                AppLogger.debug('✅ [GRANULAR] Produto ${updatedProduct.name} adicionado (update para novo)');
              }
            } else {
              // ✅ Produto com preço zero - remove se existir (foi pausado)
              if (existingIndex != -1) {
                final removedProduct = currentProducts.removeAt(existingIndex);
                productsController.add(currentProducts);
                AppLogger.debug('⏸️ [GRANULAR] Produto ${removedProduct.name} removido (preço zerado = pausado)');
              }
            }
          } else {
            AppLogger.debug('⚠️ [GRANULAR] Payload sem campo "product" para atualização');
          }
          break;

        case 'deleted':
          // ✅ CORREÇÃO: Backend envia 'product_id', não 'item_id'
          final productId = payload['product_id'] as int?;
          if (productId != null) {
            final existingIndex = currentProducts.indexWhere((p) => p.id == productId);
            if (existingIndex != -1) {
              final removedProduct = currentProducts.removeAt(existingIndex);
              productsController.add(currentProducts);
              AppLogger.debug('✅ [GRANULAR] Produto ${removedProduct.name} removido da lista');
            } else {
              AppLogger.debug('⚠️ [GRANULAR] Produto $productId não encontrado para remoção');
            }
          } else {
            AppLogger.debug('⚠️ [GRANULAR] Payload sem campo "product_id" para deleção');
          }
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ [GRANULAR] Erro ao processar evento de produto: $e');
      AppLogger.error('📍 StackTrace: $stackTrace');
    }
  }

  /// Handler para eventos granulares de categorias
  void _handleGranularCategoryEvent(dynamic data, String action) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      final storeId = payload['store_id'] as int?;

      if (!storeController.hasValue) {
        AppLogger.debug('⚠️ [GRANULAR] Store não inicializada ainda');
        return;
      }

      final currentStore = storeController.value;
      if (storeId != null && currentStore.id != storeId) {
        AppLogger.debug('⚠️ [GRANULAR] Evento de categoria para outra loja (ignorado)');
        return;
      }

      final currentCategories = List<models.Category>.from(currentStore.categories);

      switch (action) {
        case 'created':
          // ✅ CORREÇÃO: Backend envia 'category', não 'item'
          final categoryData = payload['category'] as Map<String, dynamic>?;
          if (categoryData != null) {
            final newCategory = models.Category.fromJson(categoryData);
            final existingIndex = currentCategories.indexWhere((c) => c.id == newCategory.id);
            if (existingIndex == -1) {
              currentCategories.add(newCategory);
              final updatedStore = currentStore.copyWith(categories: currentCategories);
              storeController.add(updatedStore);
              AppLogger.debug('✅ [GRANULAR] Categoria ${newCategory.name} adicionada');
            }
          } else {
            AppLogger.debug('⚠️ [GRANULAR] Payload sem campo "category" para criação');
          }
          break;

        case 'updated':
          // ✅ CORREÇÃO: Backend envia 'category', não 'item'
          final categoryData = payload['category'] as Map<String, dynamic>?;
          if (categoryData != null) {
            final updatedCategory = models.Category.fromJson(categoryData);
            final existingIndex = currentCategories.indexWhere((c) => c.id == updatedCategory.id);
            if (existingIndex != -1) {
              currentCategories[existingIndex] = updatedCategory;
              final updatedStore = currentStore.copyWith(categories: currentCategories);
              storeController.add(updatedStore);
              AppLogger.debug('✅ [GRANULAR] Categoria ${updatedCategory.name} atualizada');
            } else {
              currentCategories.add(updatedCategory);
              final updatedStore = currentStore.copyWith(categories: currentCategories);
              storeController.add(updatedStore);
              AppLogger.debug('✅ [GRANULAR] Categoria ${updatedCategory.name} adicionada (update para nova)');
            }
          } else {
            AppLogger.debug('⚠️ [GRANULAR] Payload sem campo "category" para atualização');
          }
          break;

        case 'deleted':
          // ✅ CORREÇÃO: Backend envia 'category_id', não 'item_id'
          final categoryId = payload['category_id'] as int?;
          if (categoryId != null) {
            final existingIndex = currentCategories.indexWhere((c) => c.id == categoryId);
            if (existingIndex != -1) {
              final removedCategory = currentCategories.removeAt(existingIndex);
              final updatedStore = currentStore.copyWith(categories: currentCategories);
              storeController.add(updatedStore);
              AppLogger.debug('✅ [GRANULAR] Categoria ${removedCategory.name} removida');
            }
          } else {
            AppLogger.debug('⚠️ [GRANULAR] Payload sem campo "category_id" para deleção');
          }
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ [GRANULAR] Erro ao processar evento de categoria: $e');
      AppLogger.error('📍 StackTrace: $stackTrace');
    }
  }

  /// Handler para eventos granulares de variantes (complementos)
  /// Nota: Variantes são associadas a produtos, então precisamos atualizar os produtos
  void _handleGranularVariantEvent(dynamic data, String action) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      final storeId = payload['store_id'] as int?;

      if (storeId != null && storeController.hasValue && storeController.value.id != storeId) {
        AppLogger.debug('⚠️ [GRANULAR] Evento de variante para outra loja (ignorado)');
        return;
      }

      // ✅ CORREÇÃO: Backend envia 'variant', não 'item'
      AppLogger.debug('🧩 [GRANULAR] Evento de variante processado: $action');
      
      // Variantes afetam produtos, então precisamos recarregar os produtos afetados
      // Por enquanto, logamos o evento. Em uma implementação futura, podemos
      // atualizar apenas os produtos específicos que usam essa variante
      final variantData = payload['variant'] as Map<String, dynamic>?;
      final variantId = payload['variant_id'] as int?;
      
      if (variantData != null) {
        AppLogger.debug('🧩 [GRANULAR] Variante recebida: ${variantData['id'] ?? variantId}');
        // TODO: Implementar atualização granular de produtos que usam esta variante
        // Por enquanto, o evento é processado mas não atualiza produtos automaticamente
        // Isso pode ser implementado se necessário no futuro
      } else if (variantId != null && action == 'deleted') {
        AppLogger.debug('🧩 [GRANULAR] Variante $variantId deletada');
      } else {
        AppLogger.debug('⚠️ [GRANULAR] Payload sem campo "variant" ou "variant_id"');
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [GRANULAR] Erro ao processar evento de variante: $e');
      AppLogger.error('📍 StackTrace: $stackTrace');
    }
  }

  /// Handler para eventos granulares de opções de variante
  void _handleGranularVariantOptionEvent(dynamic data, String action) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      final storeId = payload['store_id'] as int?;

      if (storeId != null && storeController.hasValue && storeController.value.id != storeId) {
        AppLogger.debug('⚠️ [GRANULAR] Evento de opção de variante para outra loja (ignorado)');
        return;
      }

      // ✅ CORREÇÃO: Backend envia 'variant_option', não 'item'
      AppLogger.debug('🔘 [GRANULAR] Evento de opção de variante processado: $action');
      
      // Opções de variante afetam produtos através de suas variantes
      final variantOptionData = payload['variant_option'] as Map<String, dynamic>?;
      final variantId = payload['variant_id'] as int?;
      
      if (variantOptionData != null) {
        AppLogger.debug('🔘 [GRANULAR] Opção de variante recebida: ${variantOptionData['id']} (variante: ${variantOptionData['variant_id'] ?? variantId})');
        // TODO: Implementar atualização granular de produtos que usam esta opção
      } else if (variantId != null && action == 'deleted') {
        final optionId = payload['item_id'] as int?;
        AppLogger.debug('🔘 [GRANULAR] Opção de variante $optionId deletada (variante: $variantId)');
      } else {
        AppLogger.debug('⚠️ [GRANULAR] Payload sem campo "variant_option" ou "variant_id"');
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [GRANULAR] Erro ao processar evento de opção de variante: $e');
      AppLogger.error('📍 StackTrace: $stackTrace');
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
      AppLogger.debug('⏳ Renovação de token já em andamento, aguardando...');
      return;
    }

    _isRenewingToken = true;
    AppLogger.debug('🔄 Iniciando renovação automática de token de conexão...');

    try {
      // Obtém o store_url salvo ou do ambiente
      String? storeUrl = _storeUrl;
      if (storeUrl == null || storeUrl.isEmpty) {
        storeUrl = await _secureStorage.read(key: _keyStoreUrl);
      }

      if (storeUrl == null || storeUrl.isEmpty) {
        AppLogger.debug('❌ Store URL não encontrada. Não é possível renovar token.');
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

      AppLogger.debug('🔐 Solicitando novo token de conexão para: $storeUrl');
      final authResult = await authRepo.getToken(storeUrl);

      if (authResult.isLeft) {
        AppLogger.debug('❌ Falha ao renovar token: ${authResult.left}');
        _isRenewingToken = false;
        return;
      }

      final totemAuth = authResult.right;
      final newConnectionToken = totemAuth.connectionToken;
      
      AppLogger.debug('✅ Novo token de conexão obtido com sucesso');

      // Desconecta socket antigo se estiver conectado
      if (_socket.connected) {
        await _socket.disconnect();
      }

      // ✅ Reconecta com novo token
      await _reconnectWithNewToken(newConnectionToken);
      
      _isRenewingToken = false;
      AppLogger.debug('✅ Reconexão automática concluída com sucesso');
    } catch (e, stackTrace) {
      AppLogger.debug('❌ Erro ao renovar token de conexão: $e');
      AppLogger.debug('📍 StackTrace: $stackTrace');
      _isRenewingToken = false;
      
      // ✅ Retenta após delay (para casos de deploy ou rede instável)
      Future.delayed(const Duration(seconds: 5), () {
        if (!_socket.connected) {
          AppLogger.debug('🔄 Retentando renovação de token após delay...');
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

    AppLogger.debug('🔌 Reconectando com novo token: $uri');

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
      AppLogger.debug('✅ Socket.IO: Reconectado com novo token com sucesso!');
      _reconnectAttempts = 0;
      if (!_reconnectionCompleter!.isCompleted) {
        _reconnectionCompleter!.complete();
      }
    });

    _socket.on('connect_error', (error) {
      AppLogger.debug('❌ Socket.IO: Erro ao reconectar com novo token: $error');
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') || 
          errorString.contains('expired') || 
          errorString.contains('used connection token')) {
        AppLogger.debug('🔄 Novo token também inválido. Aguardando e tentando novamente...');
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
        AppLogger.debug('🔄 Token inválido durante reconexão. Renovando novamente...');
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
      AppLogger.debug('❌ Timeout ou erro ao reconectar: $e');
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
      AppLogger.debug('🎉 Estado inicial carregado recebido após reconexão!');
      // ✅ Reutiliza a mesma lógica do handler principal
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final bool isNewMenuFormat = payload.containsKey('data') && 
                                     payload['data'] is Map &&
                                     (payload['data'] as Map).containsKey('menu');
        if (isNewMenuFormat) {
          _processNewMenuFormat(payload);
        } else {
          _processOldMenuFormat(payload);
        }
      } catch (e, stackTrace) {
        AppLogger.error('❌ Erro ao processar initial_state após reconexão: $e');
        AppLogger.error('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('store_details_updated', (data) {
      AppLogger.debug('🏪 Dados da loja atualizados recebidos após reconexão');
      _processStoreUpdate(data);
    });

    // ✅ ADICIONADO: Listener para store_profile_updated (logo/banner) após reconexão
    _socket.on('store_profile_updated', (data) {
      AppLogger.debug('👤 [TOTEM] store_profile_updated recebido (após reconexão)');
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
        AppLogger.debug('❌ Erro ao processar store_profile_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ CORREÇÃO: Escuta 'products_updated' (com 'd') que é o evento emitido pelo backend
    _socket.on('products_updated', (data) {
      AppLogger.debug('📦 Produtos atualizados recebidos (após reconexão)');
      try {
        if (data is Map && data.containsKey('products')) {
          final List<dynamic> productsJson = data['products'] as List<dynamic>;
          final List<Product> products = productsJson
              .map((json) => Product.fromJson(json))
              .where((product) {
                // ✅ FILTRO: Ignora produtos com preço zero (pausados)
                final hasPrice = (product.price != null && product.price! > 0) ||
                    product.variantLinks.any((link) => 
                      link.variant.options.any((opt) => opt.resolvedPrice > 0));
                return hasPrice;
              })
              .toList();
          productsController.add(products);
          
          // ✅ Categorias são atualizadas via store_details_updated ou initial_state
          if (data.containsKey('categories')) {
            AppLogger.debug('✅ ${(data['categories'] as List).length} categorias recebidas');
          }
        } else if (data is List) {
          final List<Product> products = (data as List)
              .map((json) => Product.fromJson(json))
              .where((product) {
                // ✅ FILTRO: Ignora produtos com preço zero (pausados)
                final hasPrice = (product.price != null && product.price! > 0) ||
                    product.variantLinks.any((link) => 
                      link.variant.options.any((opt) => opt.resolvedPrice > 0));
                return hasPrice;
              })
              .toList();
          productsController.add(products);
        }
      } catch (e, stackTrace) {
        AppLogger.debug('❌ Erro ao processar products_updated: $e');
        AppLogger.debug('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('order_update', (data) {
      AppLogger.debug('🛒 Atualização de pedido recebida');
      final Order order = Order.fromJson(data);
      orderController.add(order);
    });
  }

  // ✅ NOVO: Processa estado inicial (extraído para evitar duplicação)
  // ✅ NOVO: Processa formato antigo de menu (compatibilidade)
  void _processOldMenuFormat(Map<String, dynamic> payload) {
    // Processa a loja
    if (payload['store'] != null) {
      AppLogger.debug('🏪 Processando dados da loja...');
      final storeData = payload['store'] as Map<String, dynamic>;
      AppLogger.debug('   ├─ Store raw data keys: ${storeData.keys.toList()}');
      
      // ✅ DEBUG: Verifica se payment_method_groups está presente
      if (storeData.containsKey('payment_method_groups')) {
        final groups = storeData['payment_method_groups'] as List?;
        AppLogger.debug('   ├─ ✅ payment_method_groups encontrado: ${groups?.length ?? 0} grupos');
        if (groups != null && groups.isNotEmpty) {
          for (var group in groups.take(3)) {
            final groupMap = group as Map<String, dynamic>;
            final methods = groupMap['methods'] as List?;
            AppLogger.debug('      └─ Grupo "${groupMap['name']}": ${methods?.length ?? 0} métodos');
          }
        }
      } else {
        AppLogger.debug('   ├─ ❌ payment_method_groups NÃO encontrado no JSON!');
      }

      final Store store = Store.fromJson(storeData);
      storeController.add(store);

      AppLogger.debug('✅ Loja processada:');
      AppLogger.debug('   ├─ Nome: ${store.name}');
      AppLogger.debug('   ├─ ID: ${store.id}');
      AppLogger.debug('   ├─ Grupos de pagamento: ${store.paymentMethodGroups.length}');
      AppLogger.debug('   └─ Categorias: ${store.categories.length}');
      
      // ✅ DEBUG: Verifica estratégia de preço de pizza
      if (store.store_operation_config != null) {
        AppLogger.debug('🍕 [PIZZA PRICING] Estratégia recebida: ${store.store_operation_config!.pizzaPricingStrategy}');
      } else {
        AppLogger.debug('⚠️ [PIZZA PRICING] store_operation_config é null');
      }
      
      // ✅ DEBUG: Lista grupos de pagamento processados
      for (var group in store.paymentMethodGroups) {
        AppLogger.debug('      └─ Pagamento: ${group.name} (${group.methods.length} métodos)');
      }

      for (var cat in store.categories) {
        AppLogger.debug('      └─ ${cat.name} (ID: ${cat.id}, priority: ${cat.priority})');
      }
    }

    // Processa produtos
    if (payload['products'] != null) {
      AppLogger.debug('📦 Processando produtos...');
      AppLogger.debug('   ├─ Tipo: ${payload['products'].runtimeType}');
      AppLogger.debug('   ├─ Quantidade: ${(payload['products'] as List).length}');

      final List<Product> products = (payload['products'] as List)
          .map((json) {
        AppLogger.debug('      ├─ Processando produto: ${json['name']} (ID: ${json['id']})');
        return Product.fromJson(json);
      })
          .where((product) {
        // ✅ FILTRO: Ignora produtos com preço zero (pausados)
        final hasPrice = (product.price != null && product.price! > 0) ||
            product.variantLinks.any((link) => 
              link.variant.options.any((opt) => opt.resolvedPrice > 0));
        if (!hasPrice) {
          AppLogger.debug('      ⏸️ Produto ignorado (preço zero): ${product.name}');
        }
        return hasPrice;
      })
          .toList();

      productsController.add(products);

      AppLogger.debug('✅ Produtos processados:');
      AppLogger.debug('   └─ Total: ${products.length}');

      if (products.length > 3) {
        AppLogger.debug('      └─ ... e mais ${products.length - 3} produtos');
      }
    } else {
      AppLogger.debug('⚠️ payload["products"] é NULL!');
    }

    // Processa banners
    if (payload['banners'] != null) {
      AppLogger.debug('🎨 Processando ${(payload['banners'] as List).length} banners...');
      final List<BannerModel> banners = (payload['banners'] as List)
          .map((json) => BannerModel.fromJson(json))
          .toList();
      bannersController.add(banners);
      AppLogger.debug('✅ Banners processados');
    }
  }

  // ✅ NOVO: Processa novo formato de menu (com data.menu)
  void _processNewMenuFormat(Map<String, dynamic> payload) {
    try {
      // ✅ CORREÇÃO: Primeiro processa o menu para obter categorias corretas
      // Depois aplica as categorias à Store de uma só vez
      // Usa tipos dinâmicos para evitar conflito de alias
      dynamic menuCategories;
      dynamic menuProducts;
      
      // Processa menu no novo formato PRIMEIRO
      if (payload.containsKey('data') && payload['data'] is Map) {
        final dataPayload = payload['data'] as Map<String, dynamic>;
        
        if (dataPayload.containsKey('menu')) {
          AppLogger.debug('📋 Processando menu no novo formato...');
          
          // Cria MenuResponse do payload
          final menuResponseData = {
            'code': payload['code'] ?? '00',
            'message': payload['message'],
            'timestamp': payload['timestamp'],
            'data': dataPayload,
          };
          
          final MenuResponse menuResponse = MenuResponse.fromJson(menuResponseData);
          AppLogger.debug('   ├─ Total de categorias no menu: ${menuResponse.data.menu.length}');
          
          // Converte usando o adapter
          final adapterResult = MenuAdapter.convertMenuResponse(menuResponse);
          
          menuCategories = adapterResult.categories;
          menuProducts = adapterResult.products;
          
          AppLogger.debug('═══════════════════════════════════════════════════════');
          AppLogger.debug('✅ [MENU ADAPTER] Menu convertido:');
          AppLogger.debug('   ├─ Categorias: ${adapterResult.categories.length}');
          AppLogger.debug('   ├─ Produtos: ${adapterResult.products.length}');
          
          // ✅ DEBUG: Mostra categorias convertidas
          for (var cat in adapterResult.categories) {
            AppLogger.debug('   📁 Categoria: "${cat.name}" (ID: ${cat.id}, type: ${cat.type})');
            AppLogger.debug('      └─ productLinks: ${cat.productLinks.length}');
            for (var link in cat.productLinks.take(3)) {
              AppLogger.debug('         └─ Link: productId=${link.productId}, catId=${link.categoryId}');
            }
          }
          
          // ✅ DEBUG: Mostra produtos convertidos
          for (var prod in adapterResult.products.take(5)) {
            AppLogger.debug('   📦 Produto: "${prod.name}" (ID: ${prod.id}, primaryCatId: ${prod.primaryCategoryId})');
            for (var link in prod.categoryLinks.take(2)) {
              AppLogger.debug('      └─ categoryLink: catId=${link.categoryId}');
            }
          }
          AppLogger.debug('═══════════════════════════════════════════════════════');
        }
      }

      // ✅ CORREÇÃO: Processa a loja COM as categorias corretas do menu
      if (payload['store'] != null) {
        AppLogger.debug('🏪 Processando dados da loja...');
        final storeData = payload['store'] as Map<String, dynamic>;
        Store store = Store.fromJson(storeData);
        
        // ✅ IMPORTANTE: Se temos categorias do menu, usa elas em vez das do store JSON
        // As categorias do menu já têm os productLinks corretos
        if (menuCategories != null && (menuCategories as List).isNotEmpty) {
          final categoriesList = menuCategories as List<models.Category>;
          AppLogger.debug('🔄 Substituindo categorias do JSON pelas do MenuAdapter (${categoriesList.length} categorias)');
          store = store.copyWith(categories: categoriesList);
        }
        
        storeController.add(store);
        AppLogger.debug('✅ Loja processada: ${store.name} com ${store.categories.length} categorias');
      }
      
      // ✅ Adiciona produtos ao controller (usa os do menu se disponíveis)
      if (menuProducts != null && (menuProducts as List).isNotEmpty) {
        final productsList = menuProducts as List<Product>;
        productsController.add(productsList);
        AppLogger.debug('✅ ${productsList.length} produtos do menu adicionados');
      }

      // Processa banners (se presente)
      if (payload['banners'] != null) {
        AppLogger.debug('🎨 Processando ${(payload['banners'] as List).length} banners...');
        final List<BannerModel> banners = (payload['banners'] as List)
            .map((json) => BannerModel.fromJson(json))
            .toList();
        bannersController.add(banners);
        AppLogger.debug('✅ Banners processados');
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ Erro ao processar novo formato de menu: $e');
      AppLogger.error('📍 StackTrace: $stackTrace');
      // ✅ Fallback: tenta processar como formato antigo
      AppLogger.debug('🔄 Tentando processar como formato antigo...');
      _processOldMenuFormat(payload);
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
        AppLogger.debug('✅ Loja atualizada');
      }
    } catch (e, stackTrace) {
      AppLogger.debug('❌ Erro ao processar store_details_updated: $e');
      AppLogger.debug('📍 StackTrace: $stackTrace');
    }
  }

  // ✅ NOVO: Método para reconectar manualmente
  Future<void> reconnect() async {
    if (_socket.connected) {
      AppLogger.debug('✅ Socket.IO: Já está conectado');
      return;
    }

    AppLogger.debug('🔡 Socket.IO: Tentando reconectar manualmente...');
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
      AppLogger.debug("❌ RealtimeRepository: Tentativa de vincular cliente com socket desconectado.");
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

  /// ✅ NOVO: Atualiza item com resposta granular (economiza banda).
  /// Retorna um mapa com: action, item (ou removed_item_id), e totais do carrinho.
  Future<CartGranularResponse> updateCartItemGranular(UpdateCartItemPayload payload) async {
    final completer = Completer<CartGranularResponse>();

    // Adiciona flag granular ao payload
    final granularPayload = {
      ...payload.toJson(),
      'granular': true,
    };

    _socket.emitWithAck('update_cart_item', granularPayload, ack: (data) {
      if (data['success'] == true && data['granular'] == true) {
        final response = CartGranularResponse.fromJson(data);
        completer.complete(response);
      } else if (data['success'] == true && data['cart'] != null) {
        // Fallback: backend não suporta granular (versão antiga)
        final cart = Cart.fromJson(data['cart']);
        completer.completeError(
          CartGranularFallbackException(cart),
        );
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
    // ✅ VALIDAÇÃO: Verifica se o socket está conectado
    if (!_socket.connected) {
      AppLogger.error('❌ [ORDER] Socket não está conectado. Tentando reconectar...', tag: 'CHECKOUT');
      throw Exception('Conexão perdida. Por favor, recarregue a página e tente novamente.');
    }

    final completer = Completer<Order>();
    bool ackReceived = false;
    bool orderReceived = false;

    AppLogger.debug('📤 [ORDER] Enviando pedido via Socket.IO...', tag: 'CHECKOUT');
    AppLogger.debug('📤 [ORDER] Payload: ${payload.toJson()}', tag: 'CHECKOUT');

    // ✅ LISTENER TEMPORÁRIO: Escuta evento order_created enquanto aguarda
    void Function(dynamic)? orderCreatedHandler;
    orderCreatedHandler = (data) {
      AppLogger.debug('📥 [ORDER] Evento order_created recebido (raw): $data', tag: 'CHECKOUT');
      
      if (orderReceived) {
        AppLogger.warning('⚠️ [ORDER] order_created já foi processado, ignorando duplicata', tag: 'CHECKOUT');
        return; // Evita processar múltiplas vezes
      }
      
      AppLogger.debug('📥 [ORDER] Processando evento order_created...', tag: 'CHECKOUT');
      
      try {
        if (data == null) {
          AppLogger.error('❌ [ORDER] order_created recebido com data null', tag: 'CHECKOUT');
          return;
        }
        
        // ✅ Tenta converter para Map se necessário
        Map<String, dynamic>? orderData;
        if (data is Map) {
          orderData = Map<String, dynamic>.from(data);
        } else {
          AppLogger.error('❌ [ORDER] order_created não é um Map: ${data.runtimeType}', tag: 'CHECKOUT');
          return;
        }
        
        AppLogger.debug('📥 [ORDER] order_created parseado: success=${orderData['success']}, has_order=${orderData.containsKey('order')}', tag: 'CHECKOUT');
        
        if (orderData['success'] == true && orderData['order'] != null) {
          final orderJson = orderData['order'] as Map<String, dynamic>;
          final order = Order.fromJson(orderJson);
          AppLogger.success('✅ [ORDER] Pedido criado com sucesso: #${order.id}', tag: 'CHECKOUT');
          orderReceived = true;
          _socket.off('order_created', orderCreatedHandler);
          completer.complete(order);
        } else {
          AppLogger.warning('⚠️ [ORDER] order_created sem order válido: $orderData', tag: 'CHECKOUT');
        }
      } catch (e, stackTrace) {
        AppLogger.error('❌ [ORDER] Erro ao processar order_created', error: e, stackTrace: stackTrace, tag: 'CHECKOUT');
        if (!completer.isCompleted) {
          _socket.off('order_created', orderCreatedHandler);
          completer.completeError(Exception('Erro ao processar pedido criado: $e'));
        }
      }
    };
    
    AppLogger.debug('👂 [ORDER] Registrando listener temporário para order_created', tag: 'CHECKOUT');
    _socket.on('order_created', orderCreatedHandler);
    
    // ✅ CORREÇÃO BUG #3: Listener para erros de criação de pedido
    void Function(dynamic)? orderErrorHandler;
    orderErrorHandler = (data) {
      AppLogger.warning('⚠️ [ORDER] Evento order_creation_error recebido: $data', tag: 'CHECKOUT');
      
      if (orderReceived || completer.isCompleted) {
        AppLogger.debug('⏭️ [ORDER] order_creation_error ignorado (pedido já processado)', tag: 'CHECKOUT');
        return;
      }
      
      try {
        final errorData = data is Map ? Map<String, dynamic>.from(data) : {};
        final errorMessage = errorData['error'] ?? 'Erro desconhecido ao criar pedido';
        
        orderReceived = true;
        _socket.off('order_created', orderCreatedHandler);
        _socket.off('order_creation_error', orderErrorHandler);
        completer.completeError(Exception(errorMessage));
      } catch (e) {
        AppLogger.error('❌ [ORDER] Erro ao processar order_creation_error: $e', tag: 'CHECKOUT');
      }
    };
    
    AppLogger.debug('👂 [ORDER] Registrando listener temporário para order_creation_error', tag: 'CHECKOUT');
    _socket.on('order_creation_error', orderErrorHandler);

    // Chama o NOVO evento do backend
    _socket.emitWithAck('create_order_from_cart', payload.toJson(), ack: (data) {
      ackReceived = true;
      AppLogger.debug('📥 [ORDER] Resposta ACK recebida do backend: $data', tag: 'CHECKOUT');
      
      // ✅ Backend retorna {"success": true, "status": "processing", "job_id": ...}
      // O pedido será enviado via evento order_created quando estiver pronto
      if (data != null && data['success'] == true) {
        if (data['order'] != null) {
          // ✅ Se o pedido já vier no ACK (caso raro de processamento instantâneo)
          try {
            final order = Order.fromJson(data['order']);
            AppLogger.success('✅ [ORDER] Pedido criado imediatamente: #${order.id}', tag: 'CHECKOUT');
            orderReceived = true;
            _socket.off('order_created', orderCreatedHandler);
            completer.complete(order);
          } catch (e, stackTrace) {
            AppLogger.error('❌ [ORDER] Erro ao processar pedido do ACK', error: e, stackTrace: stackTrace, tag: 'CHECKOUT');
            // Continua aguardando order_created
          }
        } else if (data['status'] == 'processing') {
          // ✅ Normal: pedido sendo processado em background, aguarda order_created
          AppLogger.info('⏳ [ORDER] Pedido sendo processado. Aguardando order_created...', tag: 'CHECKOUT');
          // Não completa o completer aqui, aguarda order_created
        } else {
          // Resposta inesperada
          final errorMsg = data['error'] ?? data['message'] ?? 'Resposta inesperada do servidor.';
          AppLogger.error('❌ [ORDER] Erro do backend: $errorMsg', tag: 'CHECKOUT');
          orderReceived = true;
          _socket.off('order_created', orderCreatedHandler);
          completer.completeError(Exception(errorMsg));
        }
      } else {
        final errorMsg = data?['error'] ?? data?['message'] ?? 'Ocorreu um erro desconhecido ao finalizar o pedido.';
        AppLogger.error('❌ [ORDER] Erro do backend: $errorMsg', tag: 'CHECKOUT');
        orderReceived = true;
        _socket.off('order_created', orderCreatedHandler);
        completer.completeError(Exception(errorMsg));
      }
    });

    // ✅ TIMEOUT: Se não receber resposta em 60 segundos, retorna erro
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        // ✅ CORREÇÃO: Remove ambos os listeners no timeout
        _socket.off('order_created', orderCreatedHandler);
        _socket.off('order_creation_error', orderErrorHandler);
        
        if (!ackReceived) {
          AppLogger.error('❌ [ORDER] Timeout ao aguardar ACK do servidor (60s)', tag: 'CHECKOUT');
          throw TimeoutException('O servidor não respondeu a tempo. Por favor, tente novamente.');
        }
        if (!orderReceived) {
          AppLogger.error('❌ [ORDER] Timeout ao aguardar order_created (60s)', tag: 'CHECKOUT');
          throw TimeoutException('O pedido está sendo processado, mas demorou mais que o esperado. Verifique seus pedidos.');
        }
        throw TimeoutException('Timeout ao processar pedido.');
      },
    );
  }



  // Future<Either<String, Order>> sendOrder(NewOrder order) async {
  //   try {
  //     final result = await _socket.emitWithAckAsync('send_order', order.toJson());
  //     AppLogger.debug('[SOCKET] Resposta recebida: $result');
  //
  //     if (result == null || result['success'] != true) {
  //       final errorMsg = result?['error'] ?? 'Erro desconhecido';
  //       AppLogger.debug('[SOCKET] Erro ao enviar pedido: $errorMsg');
  //       return Left(errorMsg);
  //     }
  //
  //     return Right(Order.fromJson(result['order']));
  //   } catch (e, s) {
  //     AppLogger.debug('Error sending order: $e\n$s');
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

  /// ✅ NOVO: Calcula frete via WebSocket (evita CORS)
  /// Retorna um Map com fee (em centavos), distance_km, rule_type, etc.
  Future<Map<String, dynamic>> calculateDeliveryFee({
    double? latitude,
    double? longitude,
    int? addressId,
    int subtotal = 0,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    
    AppLogger.debug('🚚 [DELIVERY_FEE] Calculando frete via WebSocket...');
    AppLogger.debug('   └─ Latitude: $latitude');
    AppLogger.debug('   └─ Longitude: $longitude');
    AppLogger.debug('   └─ AddressId: $addressId');
    AppLogger.debug('   └─ Subtotal: $subtotal');
    
    _socket.emitWithAck('calculate_delivery_fee', {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (addressId != null) 'address_id': addressId,
      'subtotal': subtotal,
    }, ack: (data) {
      AppLogger.debug('🚚 [DELIVERY_FEE] Resposta recebida: $data');
      
      if (data != null && data is Map) {
        final result = Map<String, dynamic>.from(data);
        
        if (result.containsKey('error') && result['error'] != null) {
          AppLogger.warning('⚠️ [DELIVERY_FEE] Erro: ${result['error']}');
        } else {
          AppLogger.debug('✅ [DELIVERY_FEE] Frete: ${result['fee']} centavos');
          AppLogger.debug('   └─ Distância: ${result['distance_km']} km');
          AppLogger.debug('   └─ Regra: ${result['rule_type']}');
        }
        
        completer.complete(result);
      } else {
        completer.complete({
          'error': 'Resposta inválida do servidor',
          'fee': 0,
        });
      }
    });
    
    return completer.future;
  }






}