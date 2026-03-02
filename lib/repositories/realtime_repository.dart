import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:totem/core/utils/app_logger.dart';

import '../models/banners.dart';
import '../models/cart.dart';
import '../models/create_order_payload.dart';
import '../models/order.dart';
import '../models/update_cart_payload.dart';
import '../models/notification.dart';
import '../services/urgent_notification_service.dart';
import 'auth_repository.dart';
// ✅ Importa models e adapter do novo formato de menu
import '../models/menu/menu_response.dart';
import '../helpers/menu_adapter.dart';
import '../core/di.dart';
import '../cubit/orders_cubit.dart';
import '../pages/address/cubits/address_cubit.dart';
import '../services/realtime/heartbeat_manager.dart';
import '../services/menu_visit_service.dart';

class RealtimeRepository {
  RealtimeRepository();

  late IO.Socket _socket;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const int _baseReconnectDelay = 1000; // 1s
  static const int _maxReconnectDelay = 30000; // 30s

  // Gerenciamento de token de conexão
  // ignore: unused_field
  String? _currentConnectionToken; // armazenado para diagnóstico
  bool _isRenewingToken = false;
  Completer<void>? _reconnectionCompleter;
  String? _storeUrl; // Armazena store_url para renovação de token
  HeartbeatManager? _heartbeatManager;
  int?
  _lastLinkedCustomerId; // ✅ NOVO: Armazena o último ID vinculado para re-link na reconexão

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Constante para chave de armazenamento
  static const String _keyStoreUrl = 'store_url';

  final BehaviorSubject<Store> storeController = BehaviorSubject<Store>();

  final BehaviorSubject<List<Product>> productsController =
      BehaviorSubject<List<Product>>();

  final BehaviorSubject<List<BannerModel>> bannersController =
      BehaviorSubject<List<BannerModel>>();

  final BehaviorSubject<Order> orderController = BehaviorSubject<Order>();

  Future<void> initialize(String connectionToken) async {
    final completer = Completer<void>();

    // ✅ Salva o token atual e o store_url para renovação futura
    _currentConnectionToken = connectionToken;
    _storeUrl = await _secureStorage.read(key: _keyStoreUrl);

    final apiUrl = dotenv.env['API_URL'];

    // --- ✅ 2. MUDANÇA NA CONSTRUÇÃO DA URL ---
    // O parâmetro da query agora é `connection_token`.
    // Usamos setQuery para maior confiabilidade na atualização do token.
    _socket = IO.io(
      apiUrl,
      IO.OptionBuilder()
          .setTransports(<String>[
            'websocket',
            'polling',
          ]) // ✅ Fallback para polling se WebSocket falhar
          .disableAutoConnect()
          .enableForceNew() // ✅ ESSENCIAL: Garante que um novo socket seja criado com os novos parâmetros
          .setQuery({'connection_token': connectionToken})
          // ✅ ENTERPRISE: Melhor lógica de reconexão
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(_baseReconnectDelay)
          .setReconnectionDelayMax(_maxReconnectDelay)
          .setRandomizationFactor(
            0.1,
          ) // ✅ Adiciona variação aleatória para evitar thundering herd
          .build(),
    );

    // ✅ LISTENERS ESSENCIAIS (permanecem iguais)
    _socket.on('connect', (_) async {
      AppLogger.d('✅ Socket.IO: Conectado com sucesso!');

      // ✅ NOVO: Re-vincula o cliente se já estávamos autenticados
      if (_lastLinkedCustomerId != null) {
        AppLogger.i(
          '🔄 Re-vinculando cliente $_lastLinkedCustomerId à nova sessão...',
          tag: 'REALTIME',
        );
        try {
          await linkCustomerToSession(_lastLinkedCustomerId!);
          AppLogger.success(
            '✅ Cliente re-vinculado com sucesso!',
            tag: 'REALTIME',
          );
        } catch (e) {
          AppLogger.e(
            '❌ Falha ao re-vincular cliente na reconexão: $e',
            tag: 'REALTIME',
          );
        }
      }

      // ✅ NOVO: Inicia monitoramento de heartbeat
      _heartbeatManager?.stop();
      _heartbeatManager = HeartbeatManager(
        socket: _socket,
        onConnectionDead: () {
          AppLogger.w(
            '💀 [Realtime] Heartbeat detectou conexão morta! Forçando renovação de token...',
          );
          _renewConnectionTokenAndReconnect();
        },
      );
      _heartbeatManager?.start();

      if (!completer.isCompleted) completer.complete();

      // ✅ NOVO: Inicializa MenuVisitService após conexão
      _initializeMenuVisitService();
    });

    _socket.on('connect_error', (error) {
      AppLogger.d('❌ Socket.IO: Erro de conexão: $error');

      // ✅ NOVO: Detecta erro de token inválido e renova automaticamente
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') ||
          errorString.contains('expired') ||
          errorString.contains('used connection token') ||
          errorString.contains('connection token')) {
        AppLogger.d(
          '🔄 Token de conexão inválido/expirado. Iniciando renovação automática...',
        );
        _renewConnectionTokenAndReconnect();
      } else if (!completer.isCompleted) {
        completer.completeError('Erro ao conectar: $error');
      }
    });

    // ✅ MELHOR TRATAMENTO DE RECONEXÃO
    _socket.on('reconnect_attempt', (_) {
      _reconnectAttempts++;
      final exponentialDelay =
          _baseReconnectDelay * (1 << (_reconnectAttempts - 1).clamp(0, 5));
      final delay = exponentialDelay.clamp(0, _maxReconnectDelay);
      AppLogger.d(
        '???? Socket.IO: Tentativa de reconexão #$_reconnectAttempts (próxima em ${delay}ms)...',
      );
    });

    _socket.on('reconnect', (_) {
      _reconnectAttempts = 0; // ✅ Reset ao reconectar com sucesso
      AppLogger.d('???? Socket.IO: Reconectado com sucesso!');
      // Aqui você pode recarregar estado da aplicação se necessário
    });

    _socket.on('reconnect_error', (error) {
      AppLogger.d('❌ Socket.IO: Erro ao reconectar: $error');
      // ✅ NOVO: Detecta erro de token inválido durante reconexão
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') ||
          errorString.contains('expired') ||
          errorString.contains('used connection token')) {
        AppLogger.d('🔄 Token inválido durante reconexão. Renovando token...');
        _renewConnectionTokenAndReconnect();
      }
    });

    _socket.on('reconnect_failed', (_) {
      AppLogger.d('❌ Socket.IO: Falha ao reconectar após máximo de tentativas');
      // ✅ NOVO: Tenta renovar token e reconectar quando todas as tentativas falharem
      AppLogger.d('🔄 Tentando renovar token de conexão e reconectar...');
      _renewConnectionTokenAndReconnect();
    });

    // ✅ NOVO: Listener para notificações urgentes
    _socket.on('urgent_notifications', (data) {
      AppLogger.d('🚨 Notificações urgentes recebidas!');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final List notificationsData = payload['notifications'] as List;

        final List<NotificationItem> notifications =
            notificationsData
                .map(
                  (json) =>
                      NotificationItem.fromJson(json as Map<String, dynamic>),
                )
                .toList();

        AppLogger.d(
          '📢 Processando ${notifications.length} notificações urgentes',
        );

        // Processa notificações urgentes
        final urgentService = UrgentNotificationService();
        urgentService.processUrgentNotifications(notifications);
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar notificações urgentes: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('initial_state_loaded', (data) {
      AppLogger.d('🎉 Estado inicial carregado recebido!');
      AppLogger.d('📊 Tipo de dados recebidos: ${data.runtimeType}');

      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;

        AppLogger.d('🔑 Chaves do payload: ${payload.keys.toList()}');

        // ✅ NOVO: Detecta formato do menu (novo ou antigo)
        final bool isNewMenuFormat =
            payload.containsKey('data') &&
            payload['data'] is Map &&
            (payload['data'] as Map).containsKey('menu');

        if (isNewMenuFormat) {
          AppLogger.d('📋 Novo formato de menu detectado (com data.menu)');

          // ✅ DEBUG: Imprime estrutura do menu recebido
          final dataPayload = payload['data'] as Map<String, dynamic>;
          final menuList = dataPayload['menu'] as List<dynamic>? ?? [];
          AppLogger.d(
            '═══════════════════════════════════════════════════════',
          );
          AppLogger.d(
            '🔍 [DEBUG MENU] Total de categorias no menu: ${menuList.length}',
          );
          for (var i = 0; i < menuList.length; i++) {
            final cat = menuList[i] as Map<String, dynamic>;
            final catCode = cat['code'];
            final catName = cat['name'];
            final catTemplate = cat['template'];
            final itens = cat['itens'] as List<dynamic>? ?? [];
            AppLogger.d(
              '   📁 [$i] Categoria: "$catName" (code: $catCode, template: $catTemplate)',
            );
            AppLogger.d('      └─ Itens: ${itens.length}');
            for (var j = 0; j < itens.length && j < 3; j++) {
              final item = itens[j] as Map<String, dynamic>;
              AppLogger.d(
                '         └─ Item[$j]: id=${item['id']}, code=${item['code']}, desc="${item['description']}"',
              );
            }
            if (itens.length > 3) {
              AppLogger.d('         └─ ... e mais ${itens.length - 3} itens');
            }
          }
          AppLogger.d(
            '═══════════════════════════════════════════════════════',
          );

          _processNewMenuFormat(payload);
        } else {
          AppLogger.d(
            '📋 Formato antigo de menu detectado (com products/categories separados)',
          );
          _processOldMenuFormat(payload);
        }

        AppLogger.d('🎉 Estado inicial carregado com sucesso!');
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar initial_state_loaded: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ P1: EVENTOS DE DADOS DO BACKEND com suporte a delta updates
    // ✅ CORREÇÃO: Escuta 'products_updated' (plural) ou 'product_updated' (singular se for full payload)
    _socket.on('products_updated', (data) => _handleProductsUpdated(data));

    // ✅ SUPORTE A REFACTURE: Alguns ambientes mandam tudo por 'product_updated'
    _socket.on('product_updated', (data) {
      if (data is Map && data.containsKey('products')) {
        AppLogger.d(
          '📦 [COMPAT] Full catalog received via product_updated (singular)',
        );
        _handleProductsUpdated(data);
      } else {
        AppLogger.d('📦 [GRANULAR] Produto atualizado recebido');
        _handleGranularProductEvent(data, 'updated');
      }
    });

    // ✅ CORREÇÃO: Nome do evento alinhado com backend (banners_updated)
    _socket.on('banners_updated', (data) {
      AppLogger.d('🎨 Banners atualizados recebidos');
      final List<BannerModel> banners =
          (data as List).map((json) => BannerModel.fromJson(json)).toList();
      bannersController.add(banners);
    });

    // ✅ LISTENER: Atualizações de loja (quando admin atualiza configurações)
    _socket.on('store_details_updated', (data) => _handleStoreUpdate(data));

    // ✅ ENTERPRISE: Listeners granulares para atualizações específicas
    // Agora processa os eventos granulares para atualizar apenas a parte específica do Store
    _socket.on('payment_methods_updated', (data) {
      AppLogger.d('💳 [TOTEM] payment_methods_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        // Pega o store atual
        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.d(
            '⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)',
          );
          return;
        }

        // Parse dos payment_method_groups
        final paymentMethodGroups =
            (payload['payment_method_groups'] as List<dynamic>?)
                ?.map(
                  (e) => PaymentMethodGroup.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [];

        // Atualiza apenas os métodos de pagamento
        final updatedStore = currentStore.copyWith(
          paymentMethodGroups: paymentMethodGroups,
        );

        storeController.add(updatedStore);
        AppLogger.d(
          '✅ [TOTEM] Métodos de pagamento atualizados (${paymentMethodGroups.length} grupos)',
        );
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar payment_methods_updated: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ NOVO: Listener específico para delivery_fee_rules_updated
    _socket.on('delivery_fee_rules_updated', (data) {
      AppLogger.d('🚚 [TOTEM] delivery_fee_rules_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.d(
            '⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)',
          );
          return;
        }

        // Parse das regras de frete
        final deliveryFeeRules =
            (payload['delivery_fee_rules'] as List<dynamic>?)
                ?.map(
                  (e) => DeliveryFeeRule.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [];

        // Atualiza apenas as regras de frete
        final updatedStore = currentStore.copyWith(
          deliveryFeeRules: deliveryFeeRules,
        );

        storeController.add(updatedStore);
        AppLogger.d(
          '✅ [TOTEM] Regras de frete atualizadas (${deliveryFeeRules.length} regras)',
        );
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar delivery_fee_rules_updated: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('store_hours_updated', (data) {
      AppLogger.d('🕐 [TOTEM] store_hours_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.d(
            '⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)',
          );
          return;
        }

        // Parse dos hours
        final hours =
            (payload['hours'] as List<dynamic>?)
                ?.map((e) => StoreHour.fromJson(e))
                .toList() ??
            [];

        // Atualiza apenas os horários
        final updatedStore = currentStore.copyWith(hours: hours);

        storeController.add(updatedStore);
        AppLogger.d(
          '✅ [TOTEM] Horários atualizados (${hours.length} horários)',
        );
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar store_hours_updated: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('scheduled_pauses_updated', (data) {
      AppLogger.d('⏸️ [TOTEM] scheduled_pauses_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.d(
            '⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)',
          );
          return;
        }

        // Parse das pausas
        final pauses =
            (payload['pauses'] as List<dynamic>?)
                ?.map((e) => ScheduledPause.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        // Atualiza apenas as pausas
        final updatedStore = currentStore.copyWith(scheduledPauses: pauses);

        storeController.add(updatedStore);
        AppLogger.d(
          '✅ [TOTEM] Pausas agendadas atualizadas (${pauses.length} pausas)',
        );
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar scheduled_pauses_updated: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('operation_config_updated', (data) {
      AppLogger.d('⚙️ [TOTEM] operation_config_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.d(
            '⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)',
          );
          return;
        }

        // Parse da operation_config
        final operationConfig =
            payload['operation_config'] != null
                ? StoreOperationConfig.fromJson(
                  payload['operation_config'] as Map<String, dynamic>,
                )
                : null;

        // Atualiza apenas a configuração operacional
        final updatedStore = currentStore.copyWith(
          store_operation_config: operationConfig,
        );

        storeController.add(updatedStore);
        AppLogger.d('✅ [TOTEM] Configuração operacional atualizada');
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar operation_config_updated: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ PAUSA PROGRAMADA: Listener para mudanças de status da loja
    _socket.on('store_status_changed', (data) {
      AppLogger.d('⏸️ [TOTEM] store_status_changed recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.d(
            '⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)',
          );
          return;
        }

        final isOpen = payload['is_open'] as bool? ?? true;
        final reason = payload['reason'] as String?;
        final pausedUntilStr = payload['paused_until'] as String?;

        DateTime? pausedUntil;
        if (pausedUntilStr != null) {
          pausedUntil = DateTime.tryParse(pausedUntilStr);
        }

        AppLogger.d(
          '   └─ is_open: $isOpen, reason: $reason, paused_until: $pausedUntilStr',
        );

        // Atualiza o operation_config com o novo status
        final currentConfig = currentStore.store_operation_config;
        if (currentConfig != null) {
          final updatedConfig = currentConfig.copyWith(
            isStoreOpen: isOpen,
            pausedUntil:
                isOpen ? null : pausedUntil, // Se abrir, limpa pausedUntil
          );

          final updatedStore = currentStore.copyWith(
            store_operation_config: updatedConfig,
          );

          storeController.add(updatedStore);

          if (isOpen) {
            AppLogger.d('✅ [TOTEM] Loja REABERTA (reason: $reason)');
          } else {
            AppLogger.d(
              '⏸️ [TOTEM] Loja PAUSADA até $pausedUntilStr (reason: $reason)',
            );
          }
        }
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar store_status_changed: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('store_profile_updated', (data) {
      AppLogger.d('👤 [TOTEM] store_profile_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.d(
            '⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)',
          );
          return;
        }

        final profile = payload['profile'] as Map<String, dynamic>?;
        if (profile == null) return;

        // ✅ CORREÇÃO: Atualiza logo e banner quando image_path ou banner_path são fornecidos
        // O backend já envia as URLs completas em image_path e banner_path
        ImageModel? updatedImage;
        ImageModel? updatedBanner;

        if (profile['image_path'] != null &&
            (profile['image_path'] as String).isNotEmpty) {
          updatedImage = ImageModel(url: profile['image_path'] as String);
          AppLogger.d('   └─ Logo atualizada: ${profile['image_path']}');
        }

        if (profile['banner_path'] != null &&
            (profile['banner_path'] as String).isNotEmpty) {
          updatedBanner = ImageModel(url: profile['banner_path'] as String);
          AppLogger.d('   └─ Banner atualizado: ${profile['banner_path']}');
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
        AppLogger.d(
          '✅ [TOTEM] Perfil da loja atualizado (incluindo logo e banner)',
        );
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar store_profile_updated: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('coupons_updated', (data) {
      AppLogger.d('🎫 [TOTEM] coupons_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.d(
            '⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)',
          );
          return;
        }

        // Parse dos cupons
        final coupons =
            (payload['coupons'] as List<dynamic>?)
                ?.map((e) => Coupon.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        // Atualiza apenas os cupons
        final updatedStore = currentStore.copyWith(coupons: coupons);
        storeController.add(updatedStore);
        AppLogger.d('✅ [TOTEM] Cupons atualizados (${coupons.length} cupons)');
      } catch (e, stackTrace) {
        AppLogger.d('❌ Erro ao processar coupons_updated: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('store_internationalization_updated', (data) {
      AppLogger.d('🌐 [TOTEM] store_internationalization_updated recebido');
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final storeId = payload['store_id'] as int?;
        if (storeId == null) return;

        final currentStore = storeController.value;
        if (currentStore.id != storeId) {
          AppLogger.d(
            '⚠️ Store ID não corresponde (atual: ${currentStore.id}, evento: $storeId)',
          );
          return;
        }

        final internationalization =
            payload['internationalization'] as Map<String, dynamic>?;
        if (internationalization == null) return;

        // Atualiza apenas os campos de internacionalização
        final updatedStore = currentStore.copyWith(
          locale: internationalization['locale'] ?? currentStore.locale,
          currencyCode:
              internationalization['currency_code'] ??
              currentStore.currencyCode,
          timezone: internationalization['timezone'] ?? currentStore.timezone,
        );

        storeController.add(updatedStore);
        AppLogger.d(
          '✅ [TOTEM] Internacionalização atualizada (locale: ${updatedStore.locale}, currency: ${updatedStore.currencyCode}, timezone: ${updatedStore.timezone})',
        );
      } catch (e, stackTrace) {
        AppLogger.d(
          '❌ Erro ao processar store_internationalization_updated: $e',
        );
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ CORREÇÃO: Nome alinhado com o backend que emite 'order_updated'
    _socket.on('order_updated', (data) {
      AppLogger.d('🛒 Atualização de pedido recebida');
      try {
        final Order order = Order.fromJson(data);
        orderController.add(order);

        // ✅ ATUALIZA CUBIT: Garante que o estado global de pedidos do cliente seja atualizado
        getIt<OrdersCubit>().onRealtimeOrderUpdate(order);
      } catch (e) {
        AppLogger.e('❌ Erro ao processar order_updated: $e');
      }
    });

    // ============================================================
    // ✅ ENTERPRISE: LISTENERS GRANULARES PARA ATUALIZAÇÕES EM TEMPO REAL
    // Esses listeners recebem apenas o item específico que foi modificado,
    // reduzindo drasticamente o payload e melhorando a performance.
    // ============================================================

    // --- PRODUTOS ---
    _socket.on('product_created', (data) {
      AppLogger.d('📦 [GRANULAR] Produto criado recebido');
      _handleGranularProductEvent(data, 'created');
    });

    _socket.on('product_updated', (data) {
      AppLogger.d('📦 [GRANULAR] Produto atualizado recebido');
      _handleGranularProductEvent(data, 'updated');
    });

    _socket.on('product_deleted', (data) {
      AppLogger.d('📦 [GRANULAR] Produto deletado recebido');
      _handleGranularProductEvent(data, 'deleted');
    });

    // --- CATEGORIAS ---
    _socket.on('category_created', (data) {
      AppLogger.d('📁 [GRANULAR] Categoria criada recebida');
      _handleGranularCategoryEvent(data, 'created');
    });

    _socket.on('category_updated', (data) {
      AppLogger.d('📁 [GRANULAR] Categoria atualizada recebida');
      _handleGranularCategoryEvent(data, 'updated');
    });

    _socket.on('category_deleted', (data) {
      AppLogger.d('📁 [GRANULAR] Categoria deletada recebida');
      _handleGranularCategoryEvent(data, 'deleted');
    });

    // --- VARIANTES (Complementos) ---
    _socket.on('variant_created', (data) {
      AppLogger.d('🧩 [GRANULAR] Variante criada recebida');
      _handleGranularVariantEvent(data, 'created');
    });

    _socket.on('variant_updated', (data) {
      AppLogger.d('🧩 [GRANULAR] Variante atualizada recebida');
      _handleGranularVariantEvent(data, 'updated');
    });

    _socket.on('variant_deleted', (data) {
      AppLogger.d('🧩 [GRANULAR] Variante deletada recebida');
      _handleGranularVariantEvent(data, 'deleted');
    });

    // --- OPÇÕES DE VARIANTE ---
    _socket.on('variant_option_created', (data) {
      AppLogger.d('🔘 [GRANULAR] Opção de variante criada recebida');
      _handleGranularVariantOptionEvent(data, 'created');
    });

    _socket.on('variant_option_updated', (data) {
      AppLogger.d('🔘 [GRANULAR] Opção de variante atualizada recebida');
      _handleGranularVariantOptionEvent(data, 'updated');
    });

    _socket.on('variant_option_deleted', (data) {
      AppLogger.d('🔘 [GRANULAR] Opção de variante deletada recebida');
      _handleGranularVariantOptionEvent(data, 'deleted');
    });

    // --- ENDEREÇOS ---
    _socket.on('address_created', (data) {
      AppLogger.d('🏠 [GRANULAR] Endereço criado recebido');
      try {
        getIt<AddressCubit>().onRealtimeAddressEvent(
          data as Map<String, dynamic>,
        );
      } catch (e) {
        AppLogger.e('❌ Erro ao processar address_created: $e');
      }
    });

    _socket.on('address_updated', (data) {
      AppLogger.d('🏠 [GRANULAR] Endereço atualizado recebido');
      try {
        getIt<AddressCubit>().onRealtimeAddressEvent(
          data as Map<String, dynamic>,
        );
      } catch (e) {
        AppLogger.e('❌ Erro ao processar address_updated: $e');
      }
    });

    _socket.on('address_deleted', (data) {
      AppLogger.d('🏠 [GRANULAR] Endereço deletado recebido');
      try {
        getIt<AddressCubit>().onRealtimeAddressEvent(
          data as Map<String, dynamic>,
        );
      } catch (e) {
        AppLogger.e('❌ Erro ao processar address_deleted: $e');
      }
    });

    _socket.connect();

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Timeout ao conectar ao servidor');
      },
    );
  }

  // ============================================================
  // ✅ ENTERPRISE: HANDLERS PARA EVENTOS GRANULARES
  // Esses métodos processam eventos individuais e atualizam
  // as listas locais de forma eficiente (adicionar, atualizar, remover)
  // ============================================================

  /// ✅ HELPER: Converte recursivamente um Map para Map<String, dynamic>
  /// ULTRA-ROBUSTO: Garante que o resultado seja um Map dart puro, sem proxies de JS
  Map<String, dynamic> _convertToStringDynamicMap(dynamic data) {
    if (data == null) return {};

    final Map<String, dynamic> result = {};
    try {
      // Tenta tratar como Map genérico
      if (data is Map) {
        for (final key in data.keys) {
          if (key != null) {
            result[key.toString()] = _convertValue(data[key]);
          }
        }
      } else {
        // Tenta fallback para interop dinâmico se tiver keys
        try {
          final dynamic dynData = data;
          if (dynData.keys != null) {
            for (final key in dynData.keys) {
              result[key.toString()] = _convertValue(dynData[key]);
            }
          }
        } catch (_) {
          // Ignora se não for possível iterar
        }
      }
    } catch (e) {
      AppLogger.e('❌ Erro fatal ao converter Map (JS Interop): $e');
    }
    return result;
  }

  /// ✅ HELPER: Converte valores recursivamente (para listas e maps aninhados)
  dynamic _convertValue(dynamic value) {
    if (value == null) return null;

    // Tipos primitivos retornam direto
    if (value is String || value is num || value is bool) {
      return value;
    }

    // Tratamento de lista
    if (value is List) {
      return value.map((item) => _convertValue(item)).toList();
    }

    // Se chegou aqui, assume que é um objeto/mapa e tenta converter
    // Isso captura objetos JS que não passam no teste 'is Map' mas têm estrutura
    return _convertToStringDynamicMap(value);
  }

  /// Handler para eventos granulares de produtos
  void _handleGranularProductEvent(dynamic data, String action) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      final storeId = payload['store_id'] as int?;

      // Verifica se o evento é para a loja atual
      if (storeId != null &&
          storeController.hasValue &&
          storeController.value.id != storeId) {
        AppLogger.d(
          '⚠️ [GRANULAR] Evento de produto para outra loja (ignorado)',
        );
        return;
      }

      if (!productsController.hasValue) {
        AppLogger.d('⚠️ [GRANULAR] Lista de produtos não inicializada ainda');
        return;
      }

      final currentProducts = List<Product>.from(productsController.value);

      switch (action) {
        case 'created':
          // ✅ CORREÇÃO: Backend envia 'product', não 'item'
          final rawProductData = payload['product'];

          if (rawProductData != null) {
            try {
              // ✅ NUCLEAR OPTION: Serializa e deserializa para garantir Map Dart puro
              // Isso remove qualquer vestígio de Proxy JS que causa crash no DDC
              final Map<String, dynamic> productData = jsonDecode(
                jsonEncode(rawProductData),
              );
              final newProduct = Product.fromJson(productData);

              // Verifica se já existe (para evitar duplicatas)
              final existingIndex = currentProducts.indexWhere(
                (p) => p.id == newProduct.id,
              );
              if (existingIndex == -1) {
                currentProducts.add(newProduct);
                productsController.add(currentProducts);
                AppLogger.d(
                  '✅ [GRANULAR] Produto ${newProduct.name} adicionado à lista',
                );
              } else {
                AppLogger.d(
                  '⚠️ [GRANULAR] Produto ${newProduct.id} já existe, ignorando criação',
                );
              }
            } catch (e, stackTrace) {
              AppLogger.e(
                '❌ [GRANULAR] Erro ao converter/processar produto criado: $e',
              );
              AppLogger.e('📍 StackTrace: $stackTrace');
            }
          } else {
            AppLogger.d(
              '⚠️ [GRANULAR] Payload sem campo "product" para criação',
            );
          }
          break;

        case 'updated':
          // ✅ CORREÇÃO: Backend envia 'product', não 'item'
          final rawProductDataUpdated = payload['product'];

          if (rawProductDataUpdated != null) {
            try {
              // ✅ NUCLEAR OPTION: Serializa e deserializa para garantir Map Dart puro
              final Map<String, dynamic> productData = jsonDecode(
                jsonEncode(rawProductDataUpdated),
              );
              var updatedProduct = Product.fromJson(productData);

              final existingIndex = currentProducts.indexWhere(
                (p) => p.id == updatedProduct.id,
              );

              // ✅ SMART MERGE PARA PRODUTOS
              // Se o produto já existe, preservamos campos complexos caso não venham no payload
              if (existingIndex != -1) {
                final oldProduct = currentProducts[existingIndex];

                if (!productData.containsKey('prices')) {
                  updatedProduct = updatedProduct.copyWith(
                    prices: oldProduct.prices,
                  );
                }
                if (!productData.containsKey('variant_links')) {
                  updatedProduct = updatedProduct.copyWith(
                    variantLinks: oldProduct.variantLinks,
                  );
                }
                if (!productData.containsKey('category_links')) {
                  updatedProduct = updatedProduct.copyWith(
                    categoryLinks: oldProduct.categoryLinks,
                  );
                }
                if (!productData.containsKey('gallery_images') &&
                    !productData.containsKey('images')) {
                  updatedProduct = updatedProduct.copyWith(
                    images: oldProduct.images,
                  );
                }
                // Preserva linked_product_id se não vier (crítico para pizzas)
                if (!productData.containsKey('linked_product_id')) {
                  updatedProduct = updatedProduct.copyWith(
                    linkedProductId: oldProduct.linkedProductId,
                  );
                }

                AppLogger.d(
                  '✅ [GRANULAR] Merge inteligente aplicado ao produto ${updatedProduct.name}',
                );
              }

              // ✅ CORREÇÃO: Usa o produto atualizado diretamente (o backend já filtra se deve ou não aparecer)
              if (existingIndex != -1) {
                currentProducts[existingIndex] = updatedProduct;
                productsController.add(currentProducts);
                AppLogger.d(
                  '✅ [GRANULAR] Produto ${updatedProduct.name} atualizado na lista',
                );
              } else {
                // Produto não existe, adiciona
                currentProducts.add(updatedProduct);
                productsController.add(currentProducts);
                AppLogger.d(
                  '✅ [GRANULAR] Produto ${updatedProduct.name} adicionado (update para novo)',
                );
              }
            } catch (e, stackTrace) {
              AppLogger.e(
                '❌ [GRANULAR] Erro ao converter/processar produto atualizado: $e',
              );
              AppLogger.e('📍 StackTrace: $stackTrace');
            }
          } else {
            AppLogger.d(
              '⚠️ [GRANULAR] Payload sem campo "product" para atualização',
            );
          }
          break;

        case 'deleted':
          // ✅ CORREÇÃO: Backend envia 'product_id', não 'item_id'
          final productId = payload['product_id'] as int?;
          if (productId != null) {
            final existingIndex = currentProducts.indexWhere(
              (p) => p.id == productId,
            );
            if (existingIndex != -1) {
              final removedProduct = currentProducts.removeAt(existingIndex);
              productsController.add(currentProducts);
              AppLogger.d(
                '✅ [GRANULAR] Produto ${removedProduct.name} removido da lista',
              );
            } else {
              AppLogger.d(
                '⚠️ [GRANULAR] Produto $productId não encontrado para remoção',
              );
            }
          } else {
            AppLogger.d(
              '⚠️ [GRANULAR] Payload sem campo "product_id" para deleção',
            );
          }
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ [GRANULAR] Erro ao processar evento de produto: $e');
      AppLogger.e('📍 StackTrace: $stackTrace');
    }
  }

  /// Handler para eventos granulares de categorias
  void _handleGranularCategoryEvent(dynamic data, String action) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      final storeId = payload['store_id'] as int?;

      if (!storeController.hasValue) {
        AppLogger.d('⚠️ [GRANULAR] Store não inicializada ainda');
        return;
      }

      final currentStore = storeController.value;
      if (storeId != null && currentStore.id != storeId) {
        AppLogger.d(
          '⚠️ [GRANULAR] Evento de categoria para outra loja (ignorado)',
        );
        return;
      }

      final currentCategories = List<models.Category>.from(
        currentStore.categories,
      );

      switch (action) {
        case 'created':
          // ✅ CORREÇÃO: Backend envia 'category', não 'item'
          final rawCategoryDataCreated = payload['category'];
          AppLogger.d(
            '🔍 [GRANULAR] Payload criação: ${payload.keys.toList()}',
          );

          if (rawCategoryDataCreated != null) {
            try {
              // ✅ NUCLEAR OPTION: Sanitização via JSON
              final Map<String, dynamic> categoryDataCreated = jsonDecode(
                jsonEncode(rawCategoryDataCreated),
              );
              final newCategory = models.Category.fromJson(categoryDataCreated);
              final existingIndex = currentCategories.indexWhere(
                (c) => c.id == newCategory.id,
              );
              if (existingIndex == -1) {
                currentCategories.add(newCategory);
                final updatedStore = currentStore.copyWith(
                  categories: currentCategories,
                );
                storeController.add(updatedStore);
                AppLogger.d(
                  '✅ [GRANULAR] Categoria ${newCategory.name} adicionada',
                );
              }
            } catch (e, stackTrace) {
              AppLogger.e(
                '❌ [GRANULAR] Erro ao converter/processar categoria criada: $e',
              );
              AppLogger.e('📍 StackTrace: $stackTrace');
            }
          } else {
            AppLogger.d(
              '⚠️ [GRANULAR] Payload sem campo "category" válido para criação. Keys: ${payload.keys.toList()}',
            );
          }
          break;

        case 'updated':
          // ✅ CORREÇÃO: Backend envia 'category', não 'item'
          final rawCategoryData = payload['category'];

          if (rawCategoryData != null) {
            try {
              // ✅ NUCLEAR OPTION
              final Map<String, dynamic> categoryData = jsonDecode(
                jsonEncode(rawCategoryData),
              );
              var updatedCategory = models.Category.fromJson(categoryData);

              final existingIndex = currentCategories.indexWhere(
                (c) => c.id == updatedCategory.id,
              );
              if (existingIndex != -1) {
                final oldCategory = currentCategories[existingIndex];

                // ✅ SMART MERGE: Preserva campos complexos se não vierem no payload
                // Isso evita que updates parciais (ex: só mudou o nome) apaguem as opções/preços
                if (!categoryData.containsKey('option_groups')) {
                  updatedCategory = updatedCategory.copyWith(
                    optionGroups: oldCategory.optionGroups,
                  );
                }
                if (!categoryData.containsKey('product_option_groups')) {
                  updatedCategory = updatedCategory.copyWith(
                    productOptionGroups: oldCategory.productOptionGroups,
                  );
                }
                if (!categoryData.containsKey('product_links')) {
                  updatedCategory = updatedCategory.copyWith(
                    productLinks: oldCategory.productLinks,
                  );
                }

                currentCategories[existingIndex] = updatedCategory;
                final updatedStore = currentStore.copyWith(
                  categories: currentCategories,
                );
                storeController.add(updatedStore);
                AppLogger.d(
                  '✅ [GRANULAR] Categoria ${updatedCategory.name} atualizada (com merge inteligente)',
                );
              } else {
                currentCategories.add(updatedCategory);
                final updatedStore = currentStore.copyWith(
                  categories: currentCategories,
                );
                storeController.add(updatedStore);
                AppLogger.d(
                  '✅ [GRANULAR] Categoria ${updatedCategory.name} adicionada (update para nova)',
                );
              }
            } catch (e, stackTrace) {
              AppLogger.e(
                '❌ [GRANULAR] Erro ao converter/processar categoria: $e',
              );
              AppLogger.e('📍 StackTrace: $stackTrace');
            }
          } else {
            AppLogger.d(
              '⚠️ [GRANULAR] Payload sem campo \"category\" válido para atualização. Payload keys: ${payload.keys.toList()}',
            );
          }
          break;

        case 'deleted':
          // ✅ CORREÇÃO: Backend envia 'category_id', não 'item_id'
          final categoryId = payload['category_id'] as int?;
          if (categoryId != null) {
            final existingIndex = currentCategories.indexWhere(
              (c) => c.id == categoryId,
            );
            if (existingIndex != -1) {
              final removedCategory = currentCategories.removeAt(existingIndex);
              final updatedStore = currentStore.copyWith(
                categories: currentCategories,
              );
              storeController.add(updatedStore);
              AppLogger.d(
                '✅ [GRANULAR] Categoria ${removedCategory.name} removida',
              );
            }
          } else {
            AppLogger.d(
              '⚠️ [GRANULAR] Payload sem campo "category_id" para deleção',
            );
          }
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ [GRANULAR] Erro ao processar evento de categoria: $e');
      AppLogger.e('📍 StackTrace: $stackTrace');
    }
  }

  /// Handler para eventos granulares de variantes (complementos)
  /// Nota: Variantes são associadas a produtos, então precisamos atualizar os produtos
  void _handleGranularVariantEvent(dynamic data, String action) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      final storeId = payload['store_id'] as int?;

      if (storeId != null &&
          storeController.hasValue &&
          storeController.value.id != storeId) {
        AppLogger.d(
          '⚠️ [GRANULAR] Evento de variante para outra loja (ignorado)',
        );
        return;
      }

      // ✅ CORREÇÃO: Backend envia 'variant', não 'item'
      AppLogger.d('🧩 [GRANULAR] Evento de variante processado: $action');

      // Variantes afetam produtos, então precisamos recarregar os produtos afetados
      // Por enquanto, logamos o evento. Em uma implementação futura, podemos
      // atualizar apenas os produtos específicos que usam essa variante
      final variantData = payload['variant'] as Map<String, dynamic>?;
      final variantId = payload['variant_id'] as int?;

      if (variantData != null) {
        AppLogger.d(
          '🧩 [GRANULAR] Variante recebida: ${variantData['id'] ?? variantId}',
        );
        // TODO: Implementar atualização granular de produtos que usam esta variante
        // Por enquanto, o evento é processado mas não atualiza produtos automaticamente
        // Isso pode ser implementado se necessário no futuro
      } else if (variantId != null && action == 'deleted') {
        AppLogger.d('🧩 [GRANULAR] Variante $variantId deletada');
      } else {
        AppLogger.d(
          '⚠️ [GRANULAR] Payload sem campo "variant" ou "variant_id"',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ [GRANULAR] Erro ao processar evento de variante: $e');
      AppLogger.e('📍 StackTrace: $stackTrace');
    }
  }

  /// Handler para eventos granulares de opções de variante
  void _handleGranularVariantOptionEvent(dynamic data, String action) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      final storeId = payload['store_id'] as int?;

      if (storeId != null &&
          storeController.hasValue &&
          storeController.value.id != storeId) {
        AppLogger.d(
          '⚠️ [GRANULAR] Evento de opção de variante para outra loja (ignorado)',
        );
        return;
      }

      // ✅ CORREÇÃO: Backend envia 'variant_option', não 'item'
      AppLogger.d(
        '🔘 [GRANULAR] Evento de opção de variante processado: $action',
      );

      // Opções de variante afetam produtos através de suas variantes
      final variantOptionData =
          payload['variant_option'] as Map<String, dynamic>?;
      final variantId = payload['variant_id'] as int?;

      if (variantOptionData != null) {
        AppLogger.d(
          '🔘 [GRANULAR] Opção de variante recebida: ${variantOptionData['id']} (variante: ${variantOptionData['variant_id'] ?? variantId})',
        );
        // TODO: Implementar atualização granular de produtos que usam esta opção
      } else if (variantId != null && action == 'deleted') {
        final optionId = payload['item_id'] as int?;
        AppLogger.d(
          '🔘 [GRANULAR] Opção de variante $optionId deletada (variante: $variantId)',
        );
      } else {
        AppLogger.d(
          '⚠️ [GRANULAR] Payload sem campo "variant_option" ou "variant_id"',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        '❌ [GRANULAR] Erro ao processar evento de opção de variante: $e',
      );
      AppLogger.e('📍 StackTrace: $stackTrace');
    }
  }

  void dispose() {
    _heartbeatManager?.stop();
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
      AppLogger.d('⏳ Renovação de token já em andamento, aguardando...');
      return;
    }

    _isRenewingToken = true;
    AppLogger.d('🔄 Iniciando renovação automática de token de conexão...');

    try {
      // Obtém o store_url salvo ou do ambiente
      String? storeUrl = _storeUrl;
      if (storeUrl == null || storeUrl.isEmpty) {
        storeUrl = await _secureStorage.read(key: _keyStoreUrl);
      }

      if (storeUrl == null || storeUrl.isEmpty) {
        AppLogger.d(
          '❌ Store URL não encontrada. Não é possível renovar token.',
        );
        _isRenewingToken = false;
        return;
      }

      // ✅ Cria AuthRepository temporário para buscar novo token
      // Configura Dio com base URL correta (sem interceptors para evitar loop)
      final apiUrl = dotenv.env['API_URL'];
      final dioForRenewal = Dio(
        BaseOptions(
          baseUrl: '$apiUrl/app',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      final authRepo = AuthRepository(dioForRenewal, _secureStorage);

      AppLogger.d('🔐 Solicitando novo token de conexão para: $storeUrl');
      final authResult = await authRepo.getToken(storeUrl);

      if (authResult.isLeft) {
        AppLogger.d('❌ Falha ao renovar token: ${authResult.left}');
        _isRenewingToken = false;
        return;
      }

      final totemAuth = authResult.right;
      final newConnectionToken = totemAuth.connectionToken;

      AppLogger.d('✅ Novo token de conexão obtido com sucesso');

      // Desconecta socket antigo se estiver conectado
      if (_socket.connected) {
        _heartbeatManager?.stop();
        _socket.disconnect();
      }

      // ✅ Reconecta com novo token
      await _reconnectWithNewToken(newConnectionToken);

      _isRenewingToken = false;
      AppLogger.d('✅ Reconexão automática concluída com sucesso');
    } catch (e, stackTrace) {
      AppLogger.d('❌ Erro ao renovar token de conexão: $e');
      AppLogger.d('📍 StackTrace: $stackTrace');
      _isRenewingToken = false;

      // ✅ Retenta após delay (para casos de deploy ou rede instável)
      Future.delayed(const Duration(seconds: 5), () {
        if (!_socket.connected) {
          AppLogger.d('🔄 Retentando renovação de token após delay...');
          _renewConnectionTokenAndReconnect();
        }
      });
    }
  }

  // ✅ NOVO: Reconecta com novo token de conexão
  Future<void> _reconnectWithNewToken(String newConnectionToken) async {
    _currentConnectionToken = newConnectionToken;
    _reconnectionCompleter = Completer<void>();

    // Desconecta socket antigo
    try {
      _socket.clearListeners();
      _socket.disconnect();
      _socket.dispose();
    } catch (e) {
      AppLogger.d('⚠️ Erro ao limpar socket anterior: $e');
    }

    final apiUrl = dotenv.env['API_URL'] ?? '';

    // Cria novo socket com novo token
    _socket = IO.io(
      apiUrl,
      IO.OptionBuilder()
          .setTransports(<String>['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew() // ✅ ESSENCIAL para reconectar com novo token
          .setQuery({'connection_token': newConnectionToken})
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(_baseReconnectDelay)
          .setReconnectionDelayMax(_maxReconnectDelay)
          .setRandomizationFactor(0.1)
          .build(),
    );

    // ✅ Reconfigura listeners essenciais
    _socket.on('connect', (_) {
      AppLogger.d('✅ Socket.IO: Reconectado com novo token com sucesso!');
      _reconnectAttempts = 0;

      // ✅ NOVO: Inicia monitoramento de heartbeat após reconexão
      _heartbeatManager?.stop();
      _heartbeatManager = HeartbeatManager(
        socket: _socket,
        onConnectionDead: () {
          AppLogger.w(
            '💀 [Realtime] Heartbeat detectou conexão morta após reconexão! Tentando novamente...',
          );
          _renewConnectionTokenAndReconnect();
        },
      );
      _heartbeatManager?.start();

      if (!_reconnectionCompleter!.isCompleted) {
        _reconnectionCompleter!.complete();
      }
    });

    _socket.on('connect_error', (error) {
      AppLogger.d('❌ Socket.IO: Erro ao reconectar com novo token: $error');
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('invalid') ||
          errorString.contains('expired') ||
          errorString.contains('used connection token')) {
        AppLogger.d(
          '🔄 Novo token também inválido. Aguardando e tentando novamente...',
        );
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
        AppLogger.d(
          '🔄 Token inválido durante reconexão. Renovando novamente...',
        );
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
      AppLogger.d('❌ Timeout ou erro ao reconectar: $e');
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
      AppLogger.d('🎉 Estado inicial carregado recebido após reconexão!');
      // ✅ Reutiliza a mesma lógica do handler principal
      try {
        final Map<String, dynamic> payload = data as Map<String, dynamic>;
        final bool isNewMenuFormat =
            payload.containsKey('data') &&
            payload['data'] is Map &&
            (payload['data'] as Map).containsKey('menu');
        if (isNewMenuFormat) {
          _processNewMenuFormat(payload);
        } else {
          _processOldMenuFormat(payload);
        }
      } catch (e, stackTrace) {
        AppLogger.e('❌ Erro ao processar initial_state após reconexão: $e');
        AppLogger.e('📍 StackTrace: $stackTrace');
      }
    });

    _socket.on('store_details_updated', (data) {
      AppLogger.d('🏪 Dados da loja atualizados recebidos após reconexão');
      _handleStoreUpdate(data);
    });

    // ✅ ADICIONADO: Listener para store_profile_updated (logo/banner) após reconexão
    _socket.on('store_profile_updated', (data) {
      AppLogger.d('👤 [TOTEM] store_profile_updated recebido (após reconexão)');
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

        if (profile['image_path'] != null &&
            (profile['image_path'] as String).isNotEmpty) {
          updatedImage = ImageModel(url: profile['image_path'] as String);
        }

        if (profile['banner_path'] != null &&
            (profile['banner_path'] as String).isNotEmpty) {
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
        AppLogger.d('❌ Erro ao processar store_profile_updated: $e');
        AppLogger.d('📍 StackTrace: $stackTrace');
      }
    });

    // ✅ CORREÇÃO: Usa o handler unificado
    _socket.on('products_updated', (data) => _handleProductsUpdated(data));

    _socket.on('order_update', (data) {
      AppLogger.d('🛒 Atualização de pedido recebida');
      final Order order = Order.fromJson(data);
      orderController.add(order);
    });
  }

  // ✅ Processa formato antigo de menu (compatibilidade com payload sem data.menu)
  void _processOldMenuFormat(Map<String, dynamic> payload) {
    // Processa a loja
    if (keyExists(payload, 'store')) {
      AppLogger.d('🏪 Processando dados da loja...');
      final storeData = payload['store'] as Map<String, dynamic>;
      AppLogger.d('   ├─ Store raw data keys: ${storeData.keys.toList()}');

      Store store = Store.fromJson(storeData);

      // ✅ CORREÇÃO: Se categorias vierem no top-level (comum no Admin refatorado), anexa à Store
      if (keyExists(payload, 'categories')) {
        final List<dynamic> categoriesJson =
            payload['categories'] as List<dynamic>;
        final List<models.Category> categories =
            categoriesJson
                .map(
                  (json) =>
                      models.Category.fromJson(json as Map<String, dynamic>),
                )
                .toList();

        store = store.copyWith(categories: categories);
        AppLogger.d(
          '   ├─ ✅ Categorias anexadas do top-level: ${categories.length}',
        );
      }

      storeController.add(store);

      AppLogger.d('✅ Loja processada:');
      AppLogger.d('   ├─ Nome: ${store.name}');
      AppLogger.d('   ├─ ID: ${store.id}');
      AppLogger.d('   └─ Categorias: ${store.categories.length}');
    }

    // Processa produtos
    if (keyExists(payload, 'products')) {
      AppLogger.d('📦 Processando produtos...');
      final List<Product> products =
          (payload['products'] as List).map((json) {
            return Product.fromJson(json as Map<String, dynamic>);
          }).toList();

      productsController.add(products);
      AppLogger.d('✅ Produtos processados: ${products.length}');
    }

    // Processa banners
    if (keyExists(payload, 'banners')) {
      AppLogger.d('🎨 Processando banners...');
      final List<BannerModel> banners =
          (payload['banners'] as List)
              .map((json) => BannerModel.fromJson(json as Map<String, dynamic>))
              .toList();
      bannersController.add(banners);
      AppLogger.d('✅ Banners processados');
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
          AppLogger.d('📋 Processando menu no novo formato...');

          // Cria MenuResponse do payload
          final menuResponseData = {
            'code': payload['code'] ?? '00',
            'message': payload['message'],
            'timestamp': payload['timestamp'],
            'data': dataPayload,
          };

          final MenuResponse menuResponse = MenuResponse.fromJson(
            menuResponseData,
          );
          AppLogger.d(
            '   ├─ Total de categorias no menu: ${menuResponse.data.menu.length}',
          );

          // Converte usando o adapter
          final adapterResult = MenuAdapter.convertMenuResponse(menuResponse);

          menuCategories = adapterResult.categories;
          menuProducts = adapterResult.products;

          AppLogger.d(
            '═══════════════════════════════════════════════════════',
          );
          AppLogger.d('✅ [MENU ADAPTER] Menu convertido:');
          AppLogger.d('   ├─ Categorias: ${adapterResult.categories.length}');
          AppLogger.d('   ├─ Produtos: ${adapterResult.products.length}');

          // ✅ DEBUG: Mostra categorias convertidas
          for (var cat in adapterResult.categories) {
            AppLogger.d(
              '   📁 Categoria: "${cat.name}" (ID: ${cat.id}, type: ${cat.type})',
            );
            AppLogger.d('      └─ productLinks: ${cat.productLinks.length}');
            for (var link in cat.productLinks.take(3)) {
              AppLogger.d(
                '         └─ Link: productId=${link.productId}, catId=${link.categoryId}',
              );
            }
          }

          // ✅ DEBUG: Mostra produtos convertidos
          for (var prod in adapterResult.products.take(5)) {
            AppLogger.d(
              '   📦 Produto: "${prod.name}" (ID: ${prod.id}, primaryCatId: ${prod.primaryCategoryId})',
            );
            for (var link in prod.categoryLinks.take(2)) {
              AppLogger.d('      └─ categoryLink: catId=${link.categoryId}');
            }
          }
          AppLogger.d(
            '═══════════════════════════════════════════════════════',
          );
        }
      }

      // ✅ CORREÇÃO: Processa a loja COM as categorias corretas do menu
      if (payload['store'] != null) {
        AppLogger.d('🏪 Processando dados da loja...');
        final storeData = payload['store'] as Map<String, dynamic>;

        // Garante que as categorias não sejam perdidas se o backend mandou lista vazia no objeto store
        Store store = Store.fromJson(storeData);
        AppLogger.d(
          '   ├─ Categorias no store JSON: ${store.categories.length}',
        );

        // ✅ IMPORTANTE: Se temos categorias do menu, usa elas em vez das do store JSON
        // As categorias do menu já têm os productLinks corretos
        if (menuCategories != null) {
          try {
            final List<models.Category> categoriesList = [];
            if (menuCategories is List<models.Category>) {
              categoriesList.addAll(menuCategories);
            } else if (menuCategories is List) {
              categoriesList.addAll(menuCategories.cast<models.Category>());
            }

            if (categoriesList.isNotEmpty) {
              AppLogger.d(
                '🔄 Substituindo categorias do JSON pelas do MenuAdapter (${categoriesList.length} categorias)',
              );
              store = store.copyWith(categories: categoriesList);
            } else {
              AppLogger.w('⚠️ Lista de categorias do MenuAdapter está VAZIA.');
            }
          } catch (e) {
            AppLogger.e('❌ Erro ao converter categorias do adapter: $e');
          }
        }

        storeController.add(store);
        AppLogger.d(
          '✅ Loja processada e enviada ao controller: ${store.name} com ${store.categories.length} categorias',
        );
      }

      // ✅ Adiciona produtos ao controller (usa os do menu se disponíveis)
      if (menuProducts != null && (menuProducts as List).isNotEmpty) {
        final productsList = menuProducts as List<Product>;
        productsController.add(productsList);
        AppLogger.d('✅ ${productsList.length} produtos do menu adicionados');
      }

      // Processa banners (se presente)
      if (payload['banners'] != null) {
        AppLogger.d(
          '🎨 Processando ${(payload['banners'] as List).length} banners...',
        );
        final List<BannerModel> banners =
            (payload['banners'] as List)
                .map((json) => BannerModel.fromJson(json))
                .toList();
        bannersController.add(banners);
        AppLogger.d('✅ Banners processados');
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ ERRO CRÍTICO no _processNewMenuFormat: $e');
      AppLogger.e('📍 StackTrace: $stackTrace');

      // ✅ Fallback inteligente: Só tenta o formato antigo se não conseguimos processar nada
      if (!storeController.hasValue ||
          storeController.value.categories.isEmpty) {
        AppLogger.d(
          '🔄 Fallback: Tentando processar como formato antigo pois o menu está vazio...',
        );
        _processOldMenuFormat(payload);
      } else {
        AppLogger.w(
          '⚠️ Erro no processamento, mas mantendo dados atuais para evitar menu vazio.',
        );
      }
    }
  }

  // ✅ NOVO: Processa atualização da loja (extraído)
  void _handleStoreUpdate(dynamic data) {
    try {
      final Map<String, dynamic> payload = data as Map<String, dynamic>;
      if (payload['store'] != null) {
        final storeData = payload['store'] as Map<String, dynamic>;
        final Store updatedStoreData = Store.fromJson(storeData);

        // ✅ CORREÇÃO: Preserva categorias se não vierem no update (excluídas por performance no backend)
        Store finalStore = updatedStoreData;
        if (storeController.hasValue) {
          final currentStore = storeController.value;
          // Se o payload não contém a chave categories ou ela é null, mantém as anteriores
          if (!storeData.containsKey('categories') ||
              storeData['categories'] == null ||
              (storeData['categories'] as List).isEmpty) {
            finalStore = updatedStoreData.copyWith(
              categories: currentStore.categories,
            );
            AppLogger.d(
              '   ├─ Preservando ${currentStore.categories.length} categorias atuais (OMITIDAS NO PUSH)',
            );
          }
        }

        storeController.add(finalStore);
        AppLogger.d('✅ Loja atualizada: ${finalStore.name}');
      }
    } catch (e, stackTrace) {
      AppLogger.d('❌ Erro ao processar store_details_updated: $e');
      AppLogger.d('📍 StackTrace: $stackTrace');
    }
  }

  // ✅ NOVO: Handler unificado para atualização de catálogo
  void _handleProductsUpdated(dynamic data) {
    AppLogger.d('📦 [_handleProductsUpdated] Processando catálogo...');
    try {
      if (data is Map && data.containsKey('products')) {
        final List<dynamic> productsJson = data['products'] as List<dynamic>;

        // Atualiza Produtos
        final List<Product> products =
            productsJson
                .map((json) {
                  try {
                    return Product.fromJson(json as Map<String, dynamic>);
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<Product>()
                .toList();
        productsController.add(products);
        AppLogger.d('   ├─ ✅ ${products.length} produtos atualizados');

        // Atualiza Categorias na Store
        if (data.containsKey('categories')) {
          final List<dynamic> categoriesJson =
              data['categories'] as List<dynamic>;
          final List<models.Category> categories =
              categoriesJson
                  .map((json) {
                    try {
                      return models.Category.fromJson(
                        json as Map<String, dynamic>,
                      );
                    } catch (e) {
                      return null;
                    }
                  })
                  .whereType<models.Category>()
                  .toList();

          if (storeController.hasValue) {
            final currentStore = storeController.value;
            final updatedStore = currentStore.copyWith(categories: categories);
            storeController.add(updatedStore);
            AppLogger.d(
              '   └─ ✅ ${categories.length} categorias atualizadas na Store',
            );
          } else {
            AppLogger.w(
              '   └─ ⚠️ Store não disponível para atualizar categorias',
            );
          }
        }
      } else if (data is List) {
        // Compatibilidade legado
        final List<Product> products =
            data
                .map((json) => Product.fromJson(json as Map<String, dynamic>))
                .toList();
        productsController.add(products);
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ Erro ao processar catálogo: $e');
      AppLogger.d('📍 StackTrace: $stackTrace');
    }
  }

  // ✅ NOVO: Método para reconectar manualmente
  Future<void> reconnect() async {
    if (_socket.connected) {
      AppLogger.d('✅ Socket.IO: Já está conectado');
      return;
    }

    AppLogger.d('🔡 Socket.IO: Tentando reconectar manualmente...');
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
    _lastLinkedCustomerId = customerId; // ✅ Salva para reconexões

    // Adiciona uma verificação extra para garantir que o socket está conectado
    if (!_socket.connected) {
      AppLogger.d(
        "❌ RealtimeRepository: Tentativa de vincular cliente com socket desconectado.",
      );
      completer.completeError(Exception('Socket não está conectado.'));
      return completer.future;
    }

    _socket.emitWithAck(
      'link_customer_to_session',
      {'customer_id': customerId},
      ack: (data) {
        if (data != null && data['success'] == true) {
          completer.complete();
        } else {
          completer.completeError(
            Exception(data?['error'] ?? 'Erro ao vincular cliente.'),
          );
        }
      },
    );

    return completer.future;
  }

  void clearCustomer() {
    _lastLinkedCustomerId = null;
  }

  Future<Cart> getOrCreateCart() async {
    final completer = Completer<Cart>();

    // Usamos emitWithAck para esperar uma resposta do servidor.
    _socket.emitWithAck(
      'get_or_create_cart',
      {},
      ack: (data) {
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
      },
    );

    return completer.future;
  }

  Future<Cart> applyCoupon(String code) async {
    final completer = Completer<Cart>();
    _socket.emitWithAck(
      'apply_coupon_to_cart',
      {'coupon_code': code},
      ack: (data) {
        if (data['success'] == true && data['cart'] != null) {
          completer.complete(Cart.fromJson(data['cart']));
        } else {
          completer.completeError(
            Exception(data['error'] ?? 'Erro ao aplicar cupom.'),
          );
        }
      },
    );
    return completer.future;
  }

  Future<Cart> removeCoupon() async {
    final completer = Completer<Cart>();
    _socket.emitWithAck(
      'remove_coupon_from_cart',
      {},
      ack: (data) {
        if (data['success'] == true && data['cart'] != null) {
          completer.complete(Cart.fromJson(data['cart']));
        } else {
          completer.completeError(
            Exception(data['error'] ?? 'Erro ao remover cupom.'),
          );
        }
      },
    );
    return completer.future;
  }

  /// Adiciona, atualiza ou remove um item do carrinho.
  Future<Cart> updateCartItem(UpdateCartItemPayload payload) async {
    final completer = Completer<Cart>();

    _socket.emitWithAck(
      'update_cart_item',
      payload.toJson(),
      ack: (data) {
        if (data['success'] == true && data['cart'] != null) {
          final cart = Cart.fromJson(data['cart']);
          completer.complete(cart);
        } else {
          completer.completeError(
            Exception(data['error'] ?? 'Erro ao atualizar item no carrinho.'),
          );
        }
      },
    );

    return completer.future;
  }

  /// ✅ NOVO: Atualiza item com resposta granular (economiza banda).
  /// Retorna um mapa com: action, item (ou removed_item_id), e totais do carrinho.
  Future<CartGranularResponse> updateCartItemGranular(
    UpdateCartItemPayload payload,
  ) async {
    final completer = Completer<CartGranularResponse>();

    // Adiciona flag granular ao payload
    final granularPayload = {...payload.toJson(), 'granular': true};

    _socket.emitWithAck(
      'update_cart_item',
      granularPayload,
      ack: (data) {
        if (data['success'] == true && data['granular'] == true) {
          final response = CartGranularResponse.fromJson(data);
          completer.complete(response);
        } else if (data['success'] == true && data['cart'] != null) {
          // Fallback: backend não suporta granular (versão antiga)
          final cart = Cart.fromJson(data['cart']);
          completer.completeError(CartGranularFallbackException(cart));
        } else {
          completer.completeError(
            Exception(data['error'] ?? 'Erro ao atualizar item no carrinho.'),
          );
        }
      },
    );

    return completer.future;
  }

  /// Remove todos os itens do carrinho.
  Future<Cart> clearCart() async {
    final completer = Completer<Cart>();

    _socket.emitWithAck(
      'clear_cart',
      {},
      ack: (data) {
        if (data['success'] == true && data['cart'] != null) {
          final cart = Cart.fromJson(data['cart']);
          completer.complete(cart);
        } else {
          completer.completeError(
            Exception(data['error'] ?? 'Erro ao limpar o carrinho.'),
          );
        }
      },
    );

    return completer.future;
  }

  Future<Order> sendOrder(CreateOrderPayload payload) async {
    // ✅ VALIDAÇÃO: Verifica se o socket está conectado
    if (!_socket.connected) {
      AppLogger.e(
        '❌ [ORDER] Socket não está conectado. Tentando reconectar...',
        tag: 'CHECKOUT',
      );
      throw Exception(
        'Conexão perdida. Por favor, recarregue a página e tente novamente.',
      );
    }

    final completer = Completer<Order>();
    bool ackReceived = false;
    bool orderReceived = false;

    AppLogger.d('📤 [ORDER] Enviando pedido via Socket.IO...', tag: 'CHECKOUT');
    AppLogger.d('📤 [ORDER] Payload: ${payload.toJson()}', tag: 'CHECKOUT');

    // ✅ LISTENER TEMPORÁRIO: Escuta evento order_created enquanto aguarda
    void Function(dynamic)? orderCreatedHandler;
    orderCreatedHandler = (data) {
      AppLogger.d(
        '📥 [ORDER] Evento order_created recebido (raw): $data',
        tag: 'CHECKOUT',
      );

      if (orderReceived) {
        AppLogger.w(
          '⚠️ [ORDER] order_created já foi processado, ignorando duplicata',
          tag: 'CHECKOUT',
        );
        return; // Evita processar múltiplas vezes
      }

      AppLogger.d(
        '📥 [ORDER] Processando evento order_created...',
        tag: 'CHECKOUT',
      );

      try {
        if (data == null) {
          AppLogger.e(
            '❌ [ORDER] order_created recebido com data null',
            tag: 'CHECKOUT',
          );
          return;
        }

        // ✅ Tenta converter para Map se necessário
        Map<String, dynamic>? orderData;
        if (data is Map) {
          orderData = Map<String, dynamic>.from(data);
        } else {
          AppLogger.e(
            '❌ [ORDER] order_created não é um Map: ${data.runtimeType}',
            tag: 'CHECKOUT',
          );
          return;
        }

        AppLogger.d(
          '📥 [ORDER] order_created parseado: success=${orderData['success']}, has_order=${orderData.containsKey('order')}',
          tag: 'CHECKOUT',
        );

        if (orderData['success'] == true && orderData['order'] != null) {
          final orderJson = orderData['order'] as Map<String, dynamic>;
          final order = Order.fromJson(orderJson);
          AppLogger.i(
            '✅ [ORDER] Pedido criado com sucesso: #${order.id}',
            tag: 'CHECKOUT',
          );
          orderReceived = true;
          _socket.off('order_created', orderCreatedHandler);
          completer.complete(order);
        } else {
          AppLogger.w(
            '⚠️ [ORDER] order_created sem order válido: $orderData',
            tag: 'CHECKOUT',
          );
        }
      } catch (e, stackTrace) {
        AppLogger.e(
          '❌ [ORDER] Erro ao processar order_created',
          error: e,
          stackTrace: stackTrace,
          tag: 'CHECKOUT',
        );
        if (!completer.isCompleted) {
          _socket.off('order_created', orderCreatedHandler);
          completer.completeError(
            Exception('Erro ao processar pedido criado: $e'),
          );
        }
      }
    };

    AppLogger.d(
      '👂 [ORDER] Registrando listener temporário para order_created',
      tag: 'CHECKOUT',
    );
    _socket.on('order_created', orderCreatedHandler);

    // ✅ CORREÇÃO BUG #3: Listener para erros de criação de pedido
    void Function(dynamic)? orderErrorHandler;
    orderErrorHandler = (data) {
      AppLogger.w(
        '⚠️ [ORDER] Evento order_creation_error recebido: $data',
        tag: 'CHECKOUT',
      );

      if (orderReceived || completer.isCompleted) {
        AppLogger.d(
          '⏭️ [ORDER] order_creation_error ignorado (pedido já processado)',
          tag: 'CHECKOUT',
        );
        return;
      }

      try {
        final errorData = data is Map ? Map<String, dynamic>.from(data) : {};
        final errorMessage =
            errorData['error'] ?? 'Erro desconhecido ao criar pedido';

        orderReceived = true;
        _socket.off('order_created', orderCreatedHandler);
        _socket.off('order_creation_error', orderErrorHandler);
        completer.completeError(Exception(errorMessage));
      } catch (e) {
        AppLogger.e(
          '❌ [ORDER] Erro ao processar order_creation_error: $e',
          tag: 'CHECKOUT',
        );
      }
    };

    AppLogger.d(
      '👂 [ORDER] Registrando listener temporário para order_creation_error',
      tag: 'CHECKOUT',
    );
    _socket.on('order_creation_error', orderErrorHandler);

    // Chama o NOVO evento do backend
    _socket.emitWithAck(
      'create_order_from_cart',
      payload.toJson(),
      ack: (data) {
        ackReceived = true;
        AppLogger.d(
          '📥 [ORDER] Resposta ACK recebida do backend: $data',
          tag: 'CHECKOUT',
        );

        // ✅ Backend retorna {"success": true, "status": "processing", "job_id": ...}
        // O pedido será enviado via evento order_created quando estiver pronto
        if (data != null && data['success'] == true) {
          if (data['order'] != null) {
            // ✅ Se o pedido já vier no ACK (caso raro de processamento instantâneo)
            try {
              final order = Order.fromJson(data['order']);
              AppLogger.i(
                '✅ [ORDER] Pedido criado imediatamente: #${order.id}',
                tag: 'CHECKOUT',
              );
              orderReceived = true;
              _socket.off('order_created', orderCreatedHandler);
              completer.complete(order);
            } catch (e, stackTrace) {
              AppLogger.e(
                '❌ [ORDER] Erro ao processar pedido do ACK',
                error: e,
                stackTrace: stackTrace,
                tag: 'CHECKOUT',
              );
              // Continua aguardando order_created
            }
          } else if (data['status'] == 'processing') {
            // ✅ Normal: pedido sendo processado em background, aguarda order_created
            AppLogger.i(
              '⏳ [ORDER] Pedido sendo processado. Aguardando order_created...',
              tag: 'CHECKOUT',
            );
            // Não completa o completer aqui, aguarda order_created
          } else {
            // Resposta inesperada
            final errorMsg =
                data['error'] ??
                data['message'] ??
                'Resposta inesperada do servidor.';
            AppLogger.e(
              '❌ [ORDER] Erro do backend: $errorMsg',
              tag: 'CHECKOUT',
            );
            orderReceived = true;
            _socket.off('order_created', orderCreatedHandler);
            completer.completeError(Exception(errorMsg));
          }
        } else {
          final errorMsg =
              data?['error'] ??
              data?['message'] ??
              'Ocorreu um erro desconhecido ao finalizar o pedido.';
          AppLogger.e('❌ [ORDER] Erro do backend: $errorMsg', tag: 'CHECKOUT');
          orderReceived = true;
          _socket.off('order_created', orderCreatedHandler);
          completer.completeError(Exception(errorMsg));
        }
      },
    );

    // ✅ TIMEOUT: Se não receber resposta em 60 segundos, retorna erro
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        // ✅ CORREÇÃO: Remove ambos os listeners no timeout
        _socket.off('order_created', orderCreatedHandler);
        _socket.off('order_creation_error', orderErrorHandler);

        if (!ackReceived) {
          AppLogger.e(
            '❌ [ORDER] Timeout ao aguardar ACK do servidor (60s)',
            tag: 'CHECKOUT',
          );
          throw TimeoutException(
            'O servidor não respondeu a tempo. Por favor, tente novamente.',
          );
        }
        if (!orderReceived) {
          AppLogger.e(
            '❌ [ORDER] Timeout ao aguardar order_created (60s)',
            tag: 'CHECKOUT',
          );
          throw TimeoutException(
            'O pedido está sendo processado, mas demorou mais que o esperado. Verifique seus pedidos.',
          );
        }
        throw TimeoutException('Timeout ao processar pedido.');
      },
    );
  }

  // Future<Either<String, Order>> sendOrder(NewOrder order) async {
  //   try {
  //     final result = await _socket.emitWithAckAsync('send_order', order.toJson());
  //     AppLogger.d('[SOCKET] Resposta recebida: $result');
  //
  //     if (result == null || result['success'] != true) {
  //       final errorMsg = result?['error'] ?? 'Erro desconhecido';
  //       AppLogger.d('[SOCKET] Erro ao enviar pedido: $errorMsg');
  //       return Left(errorMsg);
  //     }
  //
  //     return Right(Order.fromJson(result['order']));
  //   } catch (e, s) {
  //     AppLogger.d('Error sending order: $e\n$s');
  //     return Left('Erro ao enviar pedido');
  //   }
  // }

  /// Lista todos os cupons disponíveis.
  Future<List<Coupon>> listCoupons() async {
    final completer = Completer<List<Coupon>>();

    _socket.emitWithAck(
      'list_coupons',
      {},
      ack: (data) {
        if (data['error'] == null && data['coupons'] != null) {
          try {
            final coupons =
                (data['coupons'] as List)
                    .map((json) => Coupon.fromJson(json))
                    .toList();
            completer.complete(coupons);
          } catch (e) {
            completer.completeError(
              Exception('Erro ao processar a lista de cupons.'),
            );
          }
        } else {
          completer.completeError(
            Exception(data['error'] ?? 'Erro ao buscar cupons.'),
          );
        }
      },
    );

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

    AppLogger.d('🚚 [DELIVERY_FEE] Calculando frete via WebSocket...');
    AppLogger.d('   └─ Latitude: $latitude');
    AppLogger.d('   └─ Longitude: $longitude');
    AppLogger.d('   └─ AddressId: $addressId');
    AppLogger.d('   └─ Subtotal: $subtotal');

    _socket.emitWithAck(
      'calculate_delivery_fee',
      {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (addressId != null) 'address_id': addressId,
        'subtotal': subtotal,
      },
      ack: (data) {
        AppLogger.d('🚚 [DELIVERY_FEE] Resposta recebida: $data');

        if (data != null && data is Map) {
          final result = Map<String, dynamic>.from(data);

          if (result.containsKey('error') && result['error'] != null) {
            AppLogger.w('⚠️ [DELIVERY_FEE] Erro: ${result['error']}');
          } else {
            AppLogger.d('✅ [DELIVERY_FEE] Frete: ${result['fee']} centavos');
            AppLogger.d('   └─ Distância: ${result['distance_km']} km');
            AppLogger.d('   └─ Regra: ${result['rule_type']}');
          }

          completer.complete(result);
        } else {
          completer.complete({
            'error': 'Resposta inválida do servidor',
            'fee': 0,
          });
        }
      },
    );

    return completer.future;
  }

  // ... (código existente)

  Future<Map<String, dynamic>> applyPromotions({
    required int subtotal,
    required int deliveryFee,
  }) async {
    if (!storeController.hasValue) {
      throw Exception('Loja não carregada');
    }

    final storeId = storeController.value.id;
    // Remove /socket.io se estiver na URL base
    String baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';
    baseUrl = baseUrl.replaceAll('/socket.io', '').replaceAll('/ws', '');
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    final dio = Dio(BaseOptions(baseUrl: baseUrl));

    try {
      AppLogger.i(
        '🚀 Calculando promoções: subtotal=$subtotal, fee=$deliveryFee',
        tag: 'PROMO',
      );

      final response = await dio.post(
        '/app/promotions/apply',
        data: {
          'store_id': storeId,
          'subtotal': subtotal,
          'delivery_fee': deliveryFee,
        },
      );

      return response.data;
    } catch (e) {
      AppLogger.e('❌ Erro ao calcular promoções: $e', tag: 'PROMO');
      // Retorna objeto vazio em caso de erro para não bloquear o fluxo
      return {
        'total_order_discount': 0,
        'total_delivery_discount': 0,
        'final_subtotal': subtotal,
        'final_delivery_fee': deliveryFee,
        'final_total': subtotal + deliveryFee,
        'promotions_applied': [],
        'message': null,
      };
    }
  }

  // ✅ NOVO: Inicializa MenuVisitService
  void _initializeMenuVisitService() {
    try {
      MenuVisitService().initialize(_socket);
      AppLogger.d('✅ [Realtime] MenuVisitService inicializado');
    } catch (e) {
      AppLogger.e('❌ [Realtime] Erro ao inicializar MenuVisitService: $e');
    }
  }

  // ✅ NOVO: Método público para registrar visita ao menu
  Future<bool> recordMenuVisit({
    String? customSource,
    String? referrer,
    Map<String, dynamic>? utmParameters,
  }) async {
    try {
      return await MenuVisitService().recordMenuVisit(
        customSource: customSource,
        referrer: referrer,
        utmParameters: utmParameters,
      );
    } catch (e) {
      AppLogger.e('❌ [Realtime] Erro ao registrar visita: $e');
      return false;
    }
  }

  // ✅ NOVO: Método público para obter informações da sessão
  Map<String, String?> getMenuVisitSessionInfo() {
    return MenuVisitService().getSessionInfo();
  }

  // ✅ Utilitário para verificar chave em payload
  bool keyExists(dynamic data, String key) {
    if (data is Map && data.containsKey(key) && data[key] != null) {
      return true;
    }
    return false;
  }
} // Fim da classe
