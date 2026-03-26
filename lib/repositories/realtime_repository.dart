import 'dart:async';
import 'dart:convert';
import 'dart:html' as html; // ✅ WEB-ONLY: Visibility API
import 'dart:math' show Random;

import 'package:collection/collection.dart';
import 'package:totem/models/option_group.dart';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:totem/models/product.dart';
import 'package:totem/helpers/enums/product_status.dart';
import 'package:totem/models/store.dart';
import 'package:totem/models/category.dart' as models;
import 'package:totem/models/payment_method.dart';
import 'package:totem/models/image_model.dart';
import 'package:totem/models/store_hour.dart';
import 'package:totem/models/scheduled_pause.dart';
import 'package:totem/models/store_operation_config.dart';
import 'package:totem/models/coupon.dart';
import 'package:totem/models/delivery_fee_rule.dart';
import 'package:totem/models/variant.dart';
import 'package:totem/models/variant_option.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:totem/core/utils/app_logger.dart';

import '../core/di.dart';
import '../cubit/orders_cubit.dart';
import '../pages/address/cubits/address_cubit.dart';
import '../services/urgent_notification_service.dart';
import '../services/menu_visit_service.dart';
import '../services/realtime/web_reconnect_strategy.dart';
import '../services/realtime/heartbeat_manager.dart';
import '../core/realtime/event_deduplicator.dart';
import '../core/realtime/delta_sync_manager.dart';
import 'auth_repository.dart';
// ✅ Importa models e adapter do novo formato de menu
import '../models/menu/menu_response.dart';
import '../helpers/menu_adapter.dart';
import '../models/banners.dart';
import '../models/category.dart';
import '../models/coupon.dart';
import '../models/customer.dart';
import '../models/cart.dart';
import '../models/update_cart_payload.dart';
import '../models/create_order_payload.dart';
import '../models/notification.dart';
import '../models/order.dart';
import '../models/store.dart';

/// ✅ ENTERPRISE: Status de conexão WebSocket para a UI
enum WebSocketConnectionStatus {
  connected,
  connecting,
  disconnected,
  reconnecting,
}

class RealtimeRepository {
  RealtimeRepository() {
    _eventDeduplicator = EventDeduplicator();
    _deltaSyncManager = DeltaSyncManager(
      deduplicator: _eventDeduplicator,
      emitWithAck: _emitWithAckForDelta,
      onDeltaApply: _applyDeltaEvents,
    );
  }

  late IO.Socket _socket;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const int _baseReconnectDelay = 1000; // 1s
  static const int _maxReconnectDelay = 30000; // 30s

  // ✅ ENTERPRISE: Backoff para renovação de token
  int _tokenRenewalAttempts = 0;
  static const int _maxTokenRenewalAttempts = 15;
  static const int _baseTokenRenewalDelay = 2000; // 2s
  static const int _maxTokenRenewalDelay = 120000; // 2min (cap)
  final Random _random = Random();

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

  // ✅ DELTA SYNC: Deduplicação e recuperação de eventos
  late final EventDeduplicator _eventDeduplicator;
  late final DeltaSyncManager _deltaSyncManager;
  String? _currentStoreUuid; // Armazena store_uuid para delta sync

  // Constante para chave de armazenamento
  static const String _keyStoreUrl = 'store_url';

  /// ✅ ENTERPRISE: Stream de status de conexão WebSocket
  /// Usado pelo ConnectionStatusBanner para mostrar aviso visual
  final BehaviorSubject<WebSocketConnectionStatus> connectionStatusController =
      BehaviorSubject<WebSocketConnectionStatus>.seeded(
        WebSocketConnectionStatus.disconnected,
      );

  /// ✅ CRITICAL FIX: Stream que indica se o Socket está pronto para operações
  /// Emite true quando Socket está conectado E cliente está vinculado à sessão
  /// CartCubit e outros cubits devem aguardar isso antes de fazer requests
  final BehaviorSubject<bool> isSocketReadyController =
      BehaviorSubject<bool>.seeded(false);

  /// Helper getter para verificar se Socket está pronto
  bool get isSocketReady => isSocketReadyController.value;

  final BehaviorSubject<Store> storeController = BehaviorSubject<Store>();

  final BehaviorSubject<List<Product>> productsController =
      BehaviorSubject<List<Product>>();

  /// ✅ NOVO: Stream separado para catálogo de categorias
  /// Desacoplado do storeController para evitar rebuilds desnecessários
  final BehaviorSubject<List<models.Category>> categoriesController =
      BehaviorSubject<List<models.Category>>();

  /// ✅ FIX CASCATA: Debounce para eventos rápidos de categorias
  /// Colapsa múltiplos updates em < 300ms em uma única emissão
  Timer? _categoryDebounceTimer;
  List<models.Category>? _pendingCategories;

  /// Emite categorias com debounce de 300ms para evitar cascata de rebuilds
  void _debouncedCategoryEmit(List<models.Category> categories) {
    _pendingCategories = categories;
    _categoryDebounceTimer?.cancel();
    _categoryDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_pendingCategories != null) {
        categoriesController.add(_pendingCategories!);
        _pendingCategories = null;
      }
    });
  }

  final BehaviorSubject<List<BannerModel>> bannersController =
      BehaviorSubject<List<BannerModel>>();

  final BehaviorSubject<Order> orderController = BehaviorSubject<Order>();

  Map<String, dynamic> _buildSocketOptions(String connectionToken) {
    final options =
        IO.OptionBuilder()
            .setTransports(<String>['websocket'])
            .disableAutoConnect()
            .enableForceNew()
            .setReconnectionAttempts(_maxReconnectAttempts)
            .setReconnectionDelay(_baseReconnectDelay)
            .setReconnectionDelayMax(_maxReconnectDelay)
            .setRandomizationFactor(0.1)
            .build();

    options['auth'] = <String, dynamic>{'connection_token': connectionToken};
    return options;
  }

  Future<void> initialize(String connectionToken) async {
    // ✅ Salva o token atual e o store_url para renovação futura
    _currentConnectionToken = connectionToken;
    _storeUrl = await _secureStorage.read(key: _keyStoreUrl);

    final apiUrl = dotenv.env['API_URL'];

    // --- ✅ 2. MUDANÇA NA CONSTRUÇÃO DA URL ---
    // O parâmetro da query agora é `connection_token`.
    // Usamos setQuery para maior confiabilidade na atualização do token.
    connectionStatusController.add(WebSocketConnectionStatus.connecting);

    _socket = IO.io(apiUrl, _buildSocketOptions(connectionToken));

    // ✅ LISTENERS ESSENCIAIS (permanecem iguais)
    _socket.on('disconnect', (_) {
      AppLogger.w('⚠️ Socket desconectado');
      isSocketReadyController.add(false);
      connectionStatusController.add(WebSocketConnectionStatus.disconnected);
      _heartbeatManager?.stop();
    });

    _socket.on('connect', (_) async {
      AppLogger.d('✅ Socket.IO: Conectado com sucesso!');
      connectionStatusController.add(WebSocketConnectionStatus.connected);
      _reconnectAttempts = 0;

      // ✅ DELTA SYNC: Tenta delta sync antes do full reload (se é reconexão)
      if (_isReconnecting && _currentStoreUuid != null) {
        try {
          await _resumeOrFullSync();
        } catch (e) {
          AppLogger.w(
            '[Reconnect] Delta sync attempt failed: $e',
            tag: 'RECONNECT',
          );
        }
      }

      // ✅ ENTERPRISE: Re-vincula cliente após reconexão (se havia um vinculado antes)
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
          // ✅ CRITICAL: Socket está pronto após re-vincular cliente
          isSocketReadyController.add(true);
        } catch (e) {
          AppLogger.e('❌ Falha ao re-vincular cliente: $e', tag: 'REALTIME');
          // Socket conectou mas cliente não foi vinculado
          isSocketReadyController.add(false);
        }
      } else {
        // Socket conectou mas não há cliente para vincular ainda
        // isSocketReady permanece false até linkCustomerToSession ser chamado
        AppLogger.d(
          '⏳ Socket conectado, aguardando vinculação de cliente...',
          tag: 'REALTIME',
        );
      }

      // ✅ NOVO: Inicia monitoramento de heartbeat com WebReconnectStrategy
      _heartbeatManager?.stop();
      _heartbeatManager = HeartbeatManager(
        socket: _socket,
        strategy: createWebStrategy(), // ✅ NOVO: Web-specific strategy
        onConnectionDead: () {
          AppLogger.w(
            '💀 [Realtime] Heartbeat detectou conexão morta! Forçando renovação de token...',
          );
          _renewConnectionTokenAndReconnect();
        },
        onConnectionAlive: () {
          AppLogger.d('💚 [Realtime] Heartbeat restaurou conexão');
        },
        onBackgroundTooLong: () {
          AppLogger.d(
            '⚠️ [Realtime] Tab ficou hidden tempo demais — forçando reconnect',
          );
          _renewConnectionTokenAndReconnect();
        },
      );
      _heartbeatManager?.start();

      // ✅ NOVO: Configura listener para Visibility API (tab hidden/visible)
      _setupVisibilityListener();

      // ✅ NOVO: Inicializa MenuVisitService após conexão
      _initializeMenuVisitService();

      if (_reconnectionCompleter != null &&
          !_reconnectionCompleter!.isCompleted) {
        _reconnectionCompleter!.complete();
      }
    });

    _socket.on('connect_error', (error) {
      AppLogger.d('❌ Socket.IO: Erro de conexão: $error');
      isSocketReadyController.add(false);
      connectionStatusController.add(WebSocketConnectionStatus.reconnecting);

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
      }
    });

    // ✅ MELHOR TRATAMENTO DE RECONEXÃO
    _socket.on('reconnect_attempt', (_) {
      _reconnectAttempts++;
      connectionStatusController.add(WebSocketConnectionStatus.reconnecting);
      final exponentialDelay =
          _baseReconnectDelay * (1 << (_reconnectAttempts - 1).clamp(0, 5));
      final delay = exponentialDelay.clamp(0, _maxReconnectDelay);
      AppLogger.d(
        '🔄 Socket.IO: Tentativa de reconexão #$_reconnectAttempts (próxima em ${delay}ms)...',
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
      connectionStatusController.add(WebSocketConnectionStatus.disconnected);
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

        // ✅ DELTA SYNC: Captura store_uuid e server_seq para tracking
        final storeUuid = payload['store_uuid'] as String?;
        final serverSeq = (payload['server_seq'] as num?)?.toInt() ?? 0;
        if (storeUuid != null) {
          _currentStoreUuid = storeUuid;
          if (serverSeq > 0) {
            _deltaSyncManager.trackInitialState(
              storeUuid: storeUuid,
              serverSeq: serverSeq,
            );
            AppLogger.i(
              '[DeltaSync] Initial state tracked: store=$storeUuid, seq=$serverSeq',
              tag: 'DELTA_SYNC',
            );
          }
        }

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

    // ✅ CORREÇÃO: Nome do evento alinhado com backend (banners_updated)
    _socket.on('banners_updated', (data) {
      AppLogger.d('🎨 Banners atualizados recebidos');
      final List<BannerModel> banners =
          (data as List).map((json) => BannerModel.fromJson(json)).toList();
      bannersController.add(banners);
    });

    // ✅ LISTENER: Atualizações de loja (quando admin atualiza configurações)
    _socket.on('store_details_updated', (data) {
      _trackServerSeqFromEvent(data);
      _handleStoreUpdate(data);
    });

    // ✅ ENTERPRISE: Listeners granulares para atualizações específicas
    // Agora processa os eventos granulares para atualizar apenas a parte específica do Store
    _socket.on('payment_methods_updated', (data) {
      AppLogger.d('💳 [TOTEM] payment_methods_updated recebido');
      try {
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
        final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
        final Order order = Order.fromJson(payload);
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
      _trackServerSeqFromEvent(data);
      _handleGranularProductEvent(data, 'created');
    });

    _socket.on('product_updated', (data) {
      AppLogger.d('📦 [GRANULAR] Produto atualizado recebido');
      _trackServerSeqFromEvent(data);
      _handleGranularProductEvent(data, 'updated');
    });

    _socket.on('product_deleted', (data) {
      AppLogger.d('📦 [GRANULAR] Produto deletado recebido');
      _trackServerSeqFromEvent(data);
      _handleGranularProductEvent(data, 'deleted');
    });

    // --- CATEGORIAS ---
    _socket.on('category_created', (data) {
      AppLogger.d('📁 [GRANULAR] Categoria criada recebida');
      _trackServerSeqFromEvent(data);
      _handleGranularCategoryEvent(data, 'created');
    });

    _socket.on('category_updated', (data) {
      AppLogger.d('📁 [GRANULAR] Categoria atualizada recebida');
      _trackServerSeqFromEvent(data);
      _handleGranularCategoryEvent(data, 'updated');
    });

    _socket.on('category_deleted', (data) {
      AppLogger.d('📁 [GRANULAR] Categoria deletada recebida');
      _trackServerSeqFromEvent(data);
      _handleGranularCategoryEvent(data, 'deleted');
    });

    // --- VARIANTES (Complementos) ---
    _socket.on('variant_created', (data) {
      AppLogger.d('🧩 [GRANULAR] Variante criada recebida');
      _trackServerSeqFromEvent(data);
      _handleGranularVariantEvent(data, 'created');
    });

    _socket.on('variant_updated', (data) {
      AppLogger.d('🧩 [GRANULAR] Variante atualizada recebida');
      _trackServerSeqFromEvent(data);
      _handleGranularVariantEvent(data, 'updated');
    });

    _socket.on('variant_deleted', (data) {
      AppLogger.d('🧩 [GRANULAR] Variante deletada recebida');
      _trackServerSeqFromEvent(data);
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
          _convertToStringDynamicMap(data),
        );
      } catch (e) {
        AppLogger.e('❌ Erro ao processar address_created: $e');
      }
    });

    _socket.on('address_updated', (data) {
      AppLogger.d('🏠 [GRANULAR] Endereço atualizado recebido');
      try {
        getIt<AddressCubit>().onRealtimeAddressEvent(
          _convertToStringDynamicMap(data),
        );
      } catch (e) {
        AppLogger.e('❌ Erro ao processar address_updated: $e');
      }
    });

    _socket.on('address_deleted', (data) {
      AppLogger.d('🏠 [GRANULAR] Endereço deletado recebido');
      try {
        getIt<AddressCubit>().onRealtimeAddressEvent(
          _convertToStringDynamicMap(data),
        );
      } catch (e) {
        AppLogger.e('❌ Erro ao processar address_deleted: $e');
      }
    });

    // ✅ CORREÇÃO: Inicia a conexão em background, não aguarda
    // A conexão continua em background e o heartbeat monitora a saúde
    _socket.connect();
  }

  // ============================================================
  // ✅ ENTERPRISE: HANDLERS PARA EVENTOS GRANULARES
  // Esses métodos processam eventos individuais e atualizam
  // as listas locais de forma eficiente (adicionar, atualizar, remover)
  // ============================================================

  /// ✅ HELPER: Converte recursivamente um Map para Map<String, dynamic>
  /// ULTRA-ROBUSTO: Garante que o resultado seja um Map dart puro, sem proxies de JS
  /// ✅ HELPER: Converte valores recursivamente (para listas e maps aninhados)
  dynamic _convertValue(dynamic value) {
    if (value == null) return null;

    // Se já é um tipo primitivo Dart, retorna direto
    if (value is String || value is num || value is bool) {
      return value;
    }

    // Se é uma lista, converte cada item
    if (value is Iterable) {
      return value.map((item) => _convertValue(item)).toList();
    }

    // Se é um Map Dart ou objeto JS proxy, tenta converter para Map<String, dynamic>
    // Usamos uma técnica agressiva de conversão para evitar proxies JS no DDC
    return _convertToStringDynamicMap(value);
  }

  /// ✅ DEEP CONVERT: Converte qualquer objeto (incluindo JS Proxy) para
  /// Map<String, dynamic> puro do Dart via ponte JSON.
  /// IMPORTANTE: No DDC (Flutter Web), objetos JS passam `is Map<String, dynamic>`
  /// mas seus filhos NÃO são Maps puros. Por isso SEMPRE fazemos a ponte JSON.
  Map<String, dynamic> _deepConvertToJson(dynamic data) {
    if (data == null) return {};
    try {
      final encoded = jsonEncode(data);
      final decoded = jsonDecode(encoded);
      // ✅ FIX CRÍTICO: jsonDecode retorna tipos PUROS do Dart.
      // Em Flutter Web (DDC), sub-objetos JS Proxy sobrevivem ao jsonDecode
      // se o objeto raiz não for serializado completamente.
      // Solução: convertemos recursivamente o grafo inteiro.
      if (decoded is Map) {
        return _recursiveConvert(decoded) as Map<String, dynamic>;
      }
    } catch (e) {
      AppLogger.w('⚠️ Ponte JSON falhou para _deepConvertToJson: $e');
    }
    // Fallback: tenta conversão manual recursiva
    return _convertToStringDynamicMap(data);
  }

  /// ✅ Converte recursivamente toda a árvore de objetos para tipos Dart puros.
  /// Necessário em Flutter Web (DDC) onde jsonDecode pode retornar Maps cujos
  /// valores aninhados ainda são JS Proxy objects.
  dynamic _recursiveConvert(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((k, v) {
        result[k.toString()] = _recursiveConvert(v);
      });
      return result;
    } else if (value is List) {
      return value.map(_recursiveConvert).toList();
    }
    // Tipos primitivos (String, num, bool, null) são sempre puros
    return value;
  }

  /// ✅ Converte objetos JS Proxy para Map<String, dynamic> (conversão manual recursiva)
  /// Usado como fallback quando a ponte JSON falha.
  Map<String, dynamic> _convertToStringDynamicMap(dynamic data) {
    if (data == null) return {};

    // NOTA: NÃO fazemos shortcut com `is Map<String, dynamic>` aqui!
    // No DDC, JS Proxy passa esse teste mas filhos continuam como proxy.

    // Tenta ponte JSON primeiro
    try {
      final encoded = jsonEncode(data);
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ponte falhou, tenta conversão manual
    }

    final Map<String, dynamic> result = {};
    try {
      if (data is Map) {
        data.forEach((key, value) {
          result[key.toString()] = _convertValue(value);
        });
      } else {
        // Fallback final via interop dinâmico de chaves
        final dynamic dynData = data;
        try {
          final List? keys = dynData.keys as List?;
          if (keys != null) {
            for (final key in keys) {
              result[key.toString()] = _convertValue(dynData[key]);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.e('❌ Erro na conversão manual de Map: $e');
    }

    return result;
  }

  /// Handler para eventos granulares de produtos
  void _handleGranularProductEvent(dynamic data, String action) {
    try {
      // ✅ CORREÇÃO CRÍTICA: Converte o objeto JS proxy para um Map Dart puro
      // antes de qualquer operação, evitando NoSuchMethodError no DDC/Flutter Web
      final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
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
              var decoded = jsonDecode(jsonEncode(rawProductData));

              // Se for uma lista (ex: [{...}]), pega o primeiro item
              if (decoded is List && decoded.isNotEmpty) {
                decoded = decoded.first;
              }

              if (decoded is! Map) {
                AppLogger.e(
                  '❌ [GRANULAR] Payload decodificado não é um Map: $decoded',
                );
                break;
              }

              final Map<String, dynamic> productData =
                  Map<String, dynamic>.from(decoded);
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
              var decoded = jsonDecode(jsonEncode(rawProductDataUpdated));

              // Se for uma lista (ex: [{...}]), pega o primeiro item
              if (decoded is List && decoded.isNotEmpty) {
                decoded = decoded.first;
              }

              if (decoded is! Map) {
                AppLogger.e(
                  '❌ [GRANULAR] Payload decodificado não é um Map: $decoded',
                );
                break;
              }

              final Map<String, dynamic> productData =
                  Map<String, dynamic>.from(decoded);
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

              // ✅ CORREÇÃO: Verifica visibilidade do produto antes de adicionar/atualizar
              // 1. Status global: se não for ACTIVE, remove do cardápio
              // 2. CategoryLinks: se TODOS tiverem is_available=false, remove do cardápio
              final bool isGloballyActive =
                  updatedProduct.status == ProductStatus.ACTIVE;
              final bool hasAnyCategoryAvailable =
                  updatedProduct.categoryLinks.isEmpty ||
                  updatedProduct.categoryLinks.any((link) => link.isAvailable);
              final bool shouldBeVisible =
                  isGloballyActive && hasAnyCategoryAvailable;

              if (!shouldBeVisible) {
                // Produto pausado/inativo — remover da lista do totem
                if (existingIndex != -1) {
                  final removedProduct = currentProducts.removeAt(
                    existingIndex,
                  );
                  productsController.add(currentProducts);
                  AppLogger.d(
                    '⏸️ [GRANULAR] Produto ${removedProduct.name} removido do cardápio '
                    '(status: ${updatedProduct.status.name}, '
                    'links disponíveis: $hasAnyCategoryAvailable)',
                  );
                } else {
                  AppLogger.d(
                    '⏸️ [GRANULAR] Produto ${updatedProduct.name} ignorado '
                    '(não visível e não estava na lista)',
                  );
                }
              } else if (existingIndex != -1) {
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
      // ✅ DEEP CONVERT: Converte o objeto JS proxy para um Map Dart puro (recursivamente)
      final Map<String, dynamic> payload = _deepConvertToJson(data);
      final storeId = payload['store_id'] as int?;

      if (storeId != null &&
          storeController.hasValue &&
          storeController.value.id != storeId) {
        AppLogger.d(
          '⚠️ [GRANULAR] Evento de categoria para outra loja (ignorado)',
        );
        return;
      }

      // ✅ REFACTOR: Usa categoriesController como fonte de verdade (não storeController)
      final currentCategories = List<models.Category>.from(
        categoriesController.hasValue ? categoriesController.value : [],
      );

      switch (action) {
        case 'created':
          var rawCategoryDataCreated = payload['category'];

          if (rawCategoryDataCreated != null) {
            try {
              // Se vier como lista de 1 item, pega o primeiro
              if (rawCategoryDataCreated is List &&
                  rawCategoryDataCreated.isNotEmpty) {
                rawCategoryDataCreated = rawCategoryDataCreated.first;
              }

              // ✅ DEEP CONVERT: Garante que todo o grafo de objetos
              // seja Map/List/String/num/bool puros do Dart (sem JS Proxy)
              final Map<String, dynamic> categoryDataCreated =
                  _deepConvertToJson(rawCategoryDataCreated);

              if (categoryDataCreated.isEmpty) {
                AppLogger.e('❌ [GRANULAR] Categoria vazia após conversão');
                break;
              }

              var newCategory = models.Category.fromJson(categoryDataCreated);

              // ✅ FIX PIZZA: Reconstroi productOptionGroups se necessário
              newCategory = _rebuildProductOptionGroups(newCategory);

              final existingIndex = currentCategories.indexWhere(
                (c) => c.id == newCategory.id,
              );
              if (existingIndex == -1) {
                currentCategories.add(newCategory);
                // ✅ REFACTOR: Publica em categoriesController (não em storeController)
                _debouncedCategoryEmit(currentCategories);
                AppLogger.d(
                  '✅ [GRANULAR] Categoria ${newCategory.name} adicionada',
                );
              }
            } catch (e, stackTrace) {
              AppLogger.e(
                '❌ [GRANULAR] Erro ao processar categoria criada: $e',
              );
              AppLogger.e('📍 StackTrace: $stackTrace');
            }
          } else {
            AppLogger.d(
              '⚠️ [GRANULAR] Payload sem "category". Keys: ${payload.keys.toList()}',
            );
          }
          break;

        case 'updated':
          var rawCategoryData = payload['category'];

          if (rawCategoryData != null) {
            try {
              // Se vier como lista de 1 item, pega o primeiro
              if (rawCategoryData is List && rawCategoryData.isNotEmpty) {
                rawCategoryData = rawCategoryData.first;
              }

              // ✅ DEEP CONVERT: Garante que todo o grafo de objetos
              // seja Map/List/String/num/bool puros do Dart (sem JS Proxy)
              final Map<String, dynamic> categoryData = _deepConvertToJson(
                rawCategoryData,
              );

              if (categoryData.isEmpty) {
                AppLogger.e('❌ [GRANULAR] Categoria vazia após conversão');
                break;
              }

              var updatedCategory = models.Category.fromJson(categoryData);

              AppLogger.d(
                '🔍 [GRANULAR] Categoria: ${updatedCategory.name} (id: ${updatedCategory.id}), isActive: ${updatedCategory.isActive}',
              );

              // ✅ FIX: Se a categoria voltou ativa mas não estava na lista (re-ativação)
              // OU se está inativa → remove da lista (tratamento duplo de segurança)
              if (!updatedCategory.isActive) {
                final existingIdx = currentCategories.indexWhere(
                  (c) => c.id == updatedCategory.id,
                );
                if (existingIdx != -1) {
                  final removedCategory = currentCategories.removeAt(
                    existingIdx,
                  );
                  _debouncedCategoryEmit(currentCategories);
                  AppLogger.d(
                    '⏸️ [GRANULAR] Categoria ${removedCategory.name} removida (is_active=false via update)',
                  );
                } else {
                  AppLogger.d(
                    '⚠️ [GRANULAR] Categoria ${updatedCategory.name} inativa, não estava na lista',
                  );
                }
                break;
              }

              final existingIndex = currentCategories.indexWhere(
                (c) => c.id == updatedCategory.id,
              );
              if (existingIndex != -1) {
                final oldCategory = currentCategories[existingIndex];

                // ✅ SMART MERGE + FIX PIZZA:
                // O backend agora injeta product_option_groups no payload.
                // Se vier populado → já foi parseado em fromJson → usamos sem rebuild.
                // Se NÃO vier → tentamos reconstruir a partir de option_groups.
                // Se option_groups também não vier → preservamos do estado anterior.

                final bool optionGroupsInPayload = categoryData.containsKey(
                  'option_groups',
                );
                final bool pogInPayload =
                    categoryData.containsKey('product_option_groups') &&
                    categoryData['product_option_groups'] != null;

                if (!optionGroupsInPayload) {
                  // option_groups não veio → preserva os locais
                  updatedCategory = updatedCategory.copyWith(
                    optionGroups: oldCategory.optionGroups,
                  );
                }

                if (pogInPayload) {
                  // ✅ Backend enviou product_option_groups completo — dado autoritativo.
                  // fromJson já populou o campo, nada a fazer.
                  AppLogger.d(
                    '✅ [PIZZA] product_option_groups recebido do backend para ${updatedCategory.name}: '
                    '${updatedCategory.productOptionGroups?.length ?? 0} tamanhos',
                  );
                } else if (optionGroupsInPayload) {
                  // option_groups veio mas product_option_groups não → rebuild local forçado
                  AppLogger.d(
                    '🔧 [PIZZA] option_groups chegou sem product_option_groups → rebuild local forçado',
                  );
                  updatedCategory = _rebuildProductOptionGroups(
                    updatedCategory,
                    forceRebuild: true,
                  );
                } else {
                  // Nenhum dos dois veio → preserva do estado anterior
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
                // ✅ REFACTOR: Publica em categoriesController
                _debouncedCategoryEmit(currentCategories);
                AppLogger.d(
                  '✅ [GRANULAR] Categoria ${updatedCategory.name} atualizada '
                  '(pog_from_backend=$pogInPayload, og_in_payload=$optionGroupsInPayload)',
                );
              } else {
                // ✅ FIX PIZZA: Categoria não existia (foi removida anteriormente).
                // Se backend enviou product_option_groups → fromJson já preencheu.
                // Se não → tenta rebuild local.
                if (updatedCategory.productOptionGroups == null ||
                    updatedCategory.productOptionGroups!.isEmpty) {
                  updatedCategory = _rebuildProductOptionGroups(
                    updatedCategory,
                    forceRebuild: true,
                  );
                }

                currentCategories.add(updatedCategory);
                _debouncedCategoryEmit(currentCategories);
                AppLogger.d(
                  '✅ [GRANULAR] Categoria ${updatedCategory.name} adicionada via update '
                  '(pog=${updatedCategory.productOptionGroups?.length ?? 0} tamanhos)',
                );
              }
            } catch (e, stackTrace) {
              AppLogger.e('❌ [GRANULAR] Erro ao processar categoria: $e');
              AppLogger.e('📍 StackTrace: $stackTrace');
            }
          } else {
            AppLogger.d(
              '⚠️ [GRANULAR] Payload sem "category". Keys: ${payload.keys.toList()}',
            );
          }
          break;

        case 'deleted':
          final categoryId = payload['category_id'] as int?;
          if (categoryId != null) {
            final existingIndex = currentCategories.indexWhere(
              (c) => c.id == categoryId,
            );
            if (existingIndex != -1) {
              final removedCategory = currentCategories.removeAt(existingIndex);
              _debouncedCategoryEmit(currentCategories);
              AppLogger.d(
                '✅ [GRANULAR] Categoria ${removedCategory.name} removida (pausa/delete)',
              );
            } else {
              AppLogger.d(
                '⚠️ [GRANULAR] Categoria $categoryId não encontrada na lista local',
              );
            }

            // ✅ AUDITORIA P1-5: Remove produtos órfãos que pertenciam exclusivamente a esta categoria
            final deletedProductIds =
                (payload['deleted_product_ids'] as List?)
                    ?.map((e) => e as int)
                    .toSet();
            if (deletedProductIds != null &&
                deletedProductIds.isNotEmpty &&
                productsController.hasValue) {
              final currentProducts = List<Product>.from(
                productsController.value,
              );
              final beforeCount = currentProducts.length;
              currentProducts.removeWhere(
                (p) => deletedProductIds.contains(p.id),
              );
              if (currentProducts.length != beforeCount) {
                productsController.add(currentProducts);
                AppLogger.d(
                  '✅ [GRANULAR] ${beforeCount - currentProducts.length} produtos órfãos removidos (cascata category_deleted)',
                );
              }
            }
          } else {
            AppLogger.d('⚠️ [GRANULAR] Payload sem "category_id"');
          }
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ [GRANULAR] Erro ao processar evento de categoria: $e');
      AppLogger.e('📍 StackTrace: $stackTrace');
    }
  }

  /// ✅ Reconstroi o mapa productOptionGroups (necessário para Pizzas no Totem)
  /// O backend envia grupos globais, então mapeamos cada tamanho para suas escolhas.
  ///
  /// IMPORTANTE: A chave do mapa deve ser o OptionItem.linkedProductId (ou id) do grupo SIZE,
  /// pois é assim que o PizzaAdapter faz o lookup:
  ///   `final sizeProductId = size.linkedProductId ?? size.id;`
  ///
  /// ✅ FIX: Removida a guarda `productOptionGroups != null` — agora o rebuild é
  /// sempre forçado quando [forceRebuild] = true, permitindo sobrescrever um mapa
  /// stale quando novos option_groups chegam via evento granular.
  models.Category _rebuildProductOptionGroups(
    models.Category category, {
    bool forceRebuild = false,
  }) {
    if (!category.isCustomizable) {
      return category;
    }

    // ✅ Se o backend já enviou product_option_groups populado (via fromJson),
    // e não estamos forçando rebuild, confio no dado do servidor.
    if (category.productOptionGroups != null &&
        category.productOptionGroups!.isNotEmpty &&
        !forceRebuild) {
      AppLogger.d(
        '✅ [REBUILD] productOptionGroups já populado pelo backend para ${category.name} '
        '(${category.productOptionGroups!.length} tamanhos) — usando dado do servidor.',
      );
      return category;
    }

    if (category.optionGroups.isEmpty) {
      AppLogger.w(
        '⚠️ [REBUILD] Categoria ${category.name} é pizza mas optionGroups está vazio! '
        'Não é possível reconstruir productOptionGroups.',
      );
      return category;
    }

    // Pega todos os grupos que NÃO são de tamanhos (sabores, bordas, massas, etc)
    final nonSizeGroups =
        category.optionGroups
            .where((g) => g.groupType != OptionGroupType.size && g.isActive)
            .toList();

    if (nonSizeGroups.isEmpty) {
      AppLogger.w(
        '⚠️ [REBUILD] Categoria ${category.name}: nenhum grupo não-SIZE ativo encontrado.',
      );
      return category;
    }

    // Constrói o mapa sizeKey -> List<OptionGroup>
    // ✅ FIX CHAVES MÚLTIPLAS: Inclui TODAS as chaves possíveis para compatibilidade
    // com MenuAdapter (carga inicial) e category_updated (dados granulares)
    final Map<int, List<OptionGroup>> rebuiltMap = {};

    // ✅ ESTRATÉGIA 1: Usa os OptionItems do grupo SIZE como chave
    // O PizzaAdapter busca por size.linkedProductId ?? size.id
    final sizeGroup = category.optionGroups.firstWhereOrNull(
      (g) => g.groupType == OptionGroupType.size,
    );
    if (sizeGroup != null && sizeGroup.items.isNotEmpty) {
      for (final item in sizeGroup.items) {
        // Inclui AMBAS as chaves: linkedProductId E id
        if (item.linkedProductId != null) {
          rebuiltMap[item.linkedProductId!] = nonSizeGroups;
        }
        if (item.id != null) {
          rebuiltMap[item.id!] = nonSizeGroups;
        }
      }
    }

    // ✅ ESTRATÉGIA 2: Também inclui product_links como chaves adicionais
    // O MenuAdapter cria OptionItems SIZE com id=productId do menu,
    // e o product_link.productId corresponde a esse valor.
    for (final link in category.productLinks) {
      final pid = link.productId;
      if (pid != null && !rebuiltMap.containsKey(pid)) {
        rebuiltMap[pid] = nonSizeGroups;
      }
    }

    if (rebuiltMap.isNotEmpty) {
      AppLogger.d(
        '🔧 [REBUILD] productOptionGroups reconstruído localmente para ${category.name}: '
        'keys=${rebuiltMap.keys.toList()} (${rebuiltMap.length} tamanhos × ${nonSizeGroups.length} grupos)',
      );
      return category.copyWith(productOptionGroups: rebuiltMap);
    }

    AppLogger.e(
      '❌ [REBUILD] Falha ao reconstruir productOptionGroups para ${category.name}. '
      'sizeGroup=${sizeGroup?.items.length} items, nonSizeGroups=${nonSizeGroups.length}',
    );
    return category;
  }

  /// Handler para eventos granulares de variantes (complementos)
  /// ✅ BUG#3 FIX: Implementação real — atualiza produtos que usam a variante modificada
  void _handleGranularVariantEvent(dynamic data, String action) {
    try {
      // ✅ CORREÇÃO CRÍTICA: Converte o objeto JS proxy para um Map Dart puro
      final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
      final storeId = payload['store_id'] as int?;

      if (storeId != null &&
          storeController.hasValue &&
          storeController.value.id != storeId) {
        AppLogger.d(
          '⚠️ [GRANULAR] Evento de variante para outra loja (ignorado)',
        );
        return;
      }

      if (!productsController.hasValue) {
        AppLogger.d('⚠️ [GRANULAR] Lista de produtos não inicializada ainda');
        return;
      }

      AppLogger.d('🧩 [GRANULAR] Evento de variante processado: $action');

      switch (action) {
        case 'created':
          // Variante criada: não há produtos vinculados ainda, nada a atualizar
          AppLogger.d(
            '🧩 [GRANULAR] Variante criada — aguardando vínculo por produto_updated',
          );
          break;

        case 'updated':
          final variantRaw = payload['variant'];
          if (variantRaw == null) {
            AppLogger.d('⚠️ [GRANULAR] variant_updated sem campo "variant"');
            break;
          }

          try {
            // ✅ Sanitiza e parseia a variante
            final variantDecoded = jsonDecode(jsonEncode(variantRaw));
            if (variantDecoded is! Map) break;

            final variantData = Map<String, dynamic>.from(variantDecoded);
            final updatedVariant = Variant.fromJson(variantData);
            final updatedVariantId = updatedVariant.id;

            if (updatedVariantId == null) break;

            // ✅ Atualiza todos os produtos que referenciam esta variante
            final currentProducts = List<Product>.from(
              productsController.value,
            );
            bool changed = false;

            for (int i = 0; i < currentProducts.length; i++) {
              final product = currentProducts[i];
              final updatedLinks =
                  product.variantLinks.map((link) {
                    if (link.variant.id == updatedVariantId) {
                      return link.copyWith(variant: updatedVariant);
                    }
                    return link;
                  }).toList();

              // Verifica se houve alguma mudança
              final hasChanges = updatedLinks.any(
                (link) => link.variant.id == updatedVariantId,
              );

              if (hasChanges) {
                currentProducts[i] = product.copyWith(
                  variantLinks: updatedLinks,
                );
                changed = true;
                AppLogger.d(
                  '✅ [GRANULAR] Produto "${product.name}" atualizado com variante ${updatedVariant.name}',
                );
              }
            }

            if (changed) {
              productsController.add(currentProducts);
              AppLogger.d(
                '✅ [GRANULAR] variant_updated: produtos sincronizados com variante ${updatedVariant.name} (ID: $updatedVariantId)',
              );
            } else {
              AppLogger.d(
                '⚠️ [GRANULAR] variant_updated: nenhum produto usa a variante $updatedVariantId',
              );
            }
          } catch (e, stackTrace) {
            AppLogger.e('❌ [GRANULAR] Erro ao processar variant_updated: $e');
            AppLogger.e('📍 StackTrace: $stackTrace');
          }
          break;

        case 'deleted':
          final variantId = payload['variant_id'] as int?;
          if (variantId == null) {
            AppLogger.d('⚠️ [GRANULAR] variant_deleted sem campo "variant_id"');
            break;
          }

          // ✅ Remove o link da variante deletada de todos os produtos
          final currentProducts = List<Product>.from(productsController.value);
          bool changed = false;

          for (int i = 0; i < currentProducts.length; i++) {
            final product = currentProducts[i];
            final originalLength = product.variantLinks.length;
            final filteredLinks =
                product.variantLinks
                    .where((link) => link.variant.id != variantId)
                    .toList();

            if (filteredLinks.length != originalLength) {
              currentProducts[i] = product.copyWith(
                variantLinks: filteredLinks,
              );
              changed = true;
              AppLogger.d(
                '✅ [GRANULAR] Variante $variantId removida do produto "${product.name}"',
              );
            }
          }

          if (changed) {
            productsController.add(currentProducts);
            AppLogger.d(
              '✅ [GRANULAR] variant_deleted: variante $variantId removida dos produtos afetados',
            );
          } else {
            AppLogger.d(
              '⚠️ [GRANULAR] variant_deleted: nenhum produto usava a variante $variantId',
            );
          }
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ [GRANULAR] Erro ao processar evento de variante: $e');
      AppLogger.e('📍 StackTrace: $stackTrace');
    }
  }

  /// Handler para eventos granulares de opções de variante
  /// ✅ AUDITORIA P1-2: Implementação real — atualiza produtos que usam a variante modificada
  void _handleGranularVariantOptionEvent(dynamic data, String action) {
    try {
      final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
      final storeId = payload['store_id'] as int?;

      if (storeId != null &&
          storeController.hasValue &&
          storeController.value.id != storeId) {
        AppLogger.d(
          '⚠️ [GRANULAR] Evento de opção de variante para outra loja (ignorado)',
        );
        return;
      }

      if (!productsController.hasValue) {
        AppLogger.d('⚠️ [GRANULAR] Lista de produtos não inicializada ainda');
        return;
      }

      AppLogger.d(
        '🔘 [GRANULAR] Evento de opção de variante processado: $action',
      );

      final variantOptionRaw =
          payload['variant_option'] as Map<String, dynamic>?;
      final variantId =
          (variantOptionRaw?['variant_id'] as int?) ??
          (payload['variant_id'] as int?);

      switch (action) {
        case 'created':
          if (variantOptionRaw == null || variantId == null) {
            AppLogger.d(
              '⚠️ [GRANULAR] variant_option_created sem dados suficientes',
            );
            break;
          }
          try {
            final decoded = jsonDecode(jsonEncode(variantOptionRaw));
            if (decoded is! Map) break;
            final optionData = Map<String, dynamic>.from(decoded);
            final newOption = VariantOption.fromJson(optionData);

            final currentProducts = List<Product>.from(
              productsController.value,
            );
            bool changed = false;

            for (int i = 0; i < currentProducts.length; i++) {
              final product = currentProducts[i];
              final updatedLinks =
                  product.variantLinks.map((link) {
                    if (link.variant.id == variantId) {
                      final options = List<VariantOption>.from(
                        link.variant.options,
                      );
                      if (!options.any((o) => o.id == newOption.id)) {
                        options.add(newOption);
                        return link.copyWith(
                          variant: link.variant.copyWith(options: options),
                        );
                      }
                    }
                    return link;
                  }).toList();

              if (updatedLinks != product.variantLinks) {
                final hasChanges = updatedLinks.any(
                  (link) => link.variant.id == variantId,
                );
                if (hasChanges) {
                  currentProducts[i] = product.copyWith(
                    variantLinks: updatedLinks,
                  );
                  changed = true;
                }
              }
            }

            if (changed) {
              productsController.add(currentProducts);
              AppLogger.d(
                '✅ [GRANULAR] variant_option_created: opção ${newOption.resolvedName} adicionada à variante $variantId',
              );
            }
          } catch (e, st) {
            AppLogger.e(
              '❌ [GRANULAR] Erro ao processar variant_option_created: $e',
            );
            AppLogger.e('📍 StackTrace: $st');
          }
          break;

        case 'updated':
          if (variantOptionRaw == null || variantId == null) {
            AppLogger.d(
              '⚠️ [GRANULAR] variant_option_updated sem dados suficientes',
            );
            break;
          }
          try {
            final decoded = jsonDecode(jsonEncode(variantOptionRaw));
            if (decoded is! Map) break;
            final optionData = Map<String, dynamic>.from(decoded);
            final updatedOption = VariantOption.fromJson(optionData);

            final currentProducts = List<Product>.from(
              productsController.value,
            );
            bool changed = false;

            for (int i = 0; i < currentProducts.length; i++) {
              final product = currentProducts[i];
              final updatedLinks =
                  product.variantLinks.map((link) {
                    if (link.variant.id == variantId) {
                      final options = List<VariantOption>.from(
                        link.variant.options,
                      );
                      final optIdx = options.indexWhere(
                        (o) => o.id == updatedOption.id,
                      );
                      if (optIdx != -1) {
                        options[optIdx] = updatedOption;
                        return link.copyWith(
                          variant: link.variant.copyWith(options: options),
                        );
                      }
                    }
                    return link;
                  }).toList();

              final hasChanges = updatedLinks.any(
                (link) =>
                    link.variant.id == variantId &&
                    link.variant.options.any((o) => o.id == updatedOption.id),
              );

              if (hasChanges) {
                currentProducts[i] = product.copyWith(
                  variantLinks: updatedLinks,
                );
                changed = true;
              }
            }

            if (changed) {
              productsController.add(currentProducts);
              AppLogger.d(
                '✅ [GRANULAR] variant_option_updated: opção ${updatedOption.resolvedName} atualizada na variante $variantId',
              );
            }
          } catch (e, st) {
            AppLogger.e(
              '❌ [GRANULAR] Erro ao processar variant_option_updated: $e',
            );
            AppLogger.e('📍 StackTrace: $st');
          }
          break;

        case 'deleted':
          final optionId =
              (variantOptionRaw?['id'] as int?) ??
              (payload['option_id'] as int?) ??
              (payload['item_id'] as int?);
          if (optionId == null || variantId == null) {
            AppLogger.d(
              '⚠️ [GRANULAR] variant_option_deleted sem option_id ou variant_id',
            );
            break;
          }

          final currentProducts = List<Product>.from(productsController.value);
          bool changed = false;

          for (int i = 0; i < currentProducts.length; i++) {
            final product = currentProducts[i];
            final updatedLinks =
                product.variantLinks.map((link) {
                  if (link.variant.id == variantId) {
                    final options = List<VariantOption>.from(
                      link.variant.options,
                    );
                    final originalLength = options.length;
                    options.removeWhere((o) => o.id == optionId);
                    if (options.length != originalLength) {
                      return link.copyWith(
                        variant: link.variant.copyWith(options: options),
                      );
                    }
                  }
                  return link;
                }).toList();

            final hadVariant = product.variantLinks.any(
              (link) => link.variant.id == variantId,
            );
            if (hadVariant) {
              currentProducts[i] = product.copyWith(variantLinks: updatedLinks);
              changed = true;
            }
          }

          if (changed) {
            productsController.add(currentProducts);
            AppLogger.d(
              '✅ [GRANULAR] variant_option_deleted: opção $optionId removida da variante $variantId',
            );
          }
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        '❌ [GRANULAR] Erro ao processar evento de opção de variante: $e',
      );
      AppLogger.e('📍 StackTrace: $stackTrace');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ DELTA SYNC: Métodos de suporte
  // ═══════════════════════════════════════════════════════════════

  /// Extrai server_seq de um evento e atualiza o cursor do DeltaSyncManager.
  /// Chamado por cada listener de evento granular para manter o tracking.
  void _trackServerSeqFromEvent(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> payload =
          data is Map<String, dynamic>
              ? data
              : _convertToStringDynamicMap(data);

      final serverSeq = (payload['server_seq'] as num?)?.toInt() ?? 0;
      if (serverSeq > 0 && _currentStoreUuid != null) {
        _deltaSyncManager.trackEvent(
          storeUuid: _currentStoreUuid!,
          serverSeq: serverSeq,
        );
      }
    } catch (_) {
      // Silently ignore — tracking is best-effort
    }
  }

  /// Wrapper de emitWithAck para o DeltaSyncManager usar.
  /// Converte o callback-based emitWithAck do socket_io_client para Future-based.
  Future<dynamic> _emitWithAckForDelta(
    String event,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final completer = Completer<dynamic>();

    _socket.emitWithAck(
      event,
      data,
      ack: (response) {
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      },
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        return null; // DeltaSyncManager trata null como falha
      },
    );
  }

  /// ✅ DELTA SYNC: Aplica delta events recebidos do backend.
  /// Despacha cada evento para o handler correto baseado no event_type.
  void _applyDeltaEvents(
    String storeUuid,
    List<Map<String, dynamic>> deltaEvents,
  ) {
    AppLogger.i(
      '[DeltaSync] Applying ${deltaEvents.length} delta events for store $storeUuid',
      tag: 'DELTA_SYNC',
    );

    for (final event in deltaEvents) {
      try {
        final eventType = event['event_type'] as String? ?? '';
        final payload = event['payload'] as Map<String, dynamic>? ?? event;

        switch (eventType) {
          case 'store_details_updated':
            _handleStoreUpdate(payload);
            break;
          case 'product_created':
            _handleGranularProductEvent(payload, 'created');
            break;
          case 'product_updated':
            _handleGranularProductEvent(payload, 'updated');
            break;
          case 'product_deleted':
            _handleGranularProductEvent(payload, 'deleted');
            break;
          case 'category_created':
            _handleGranularCategoryEvent(payload, 'created');
            break;
          case 'category_updated':
            _handleGranularCategoryEvent(payload, 'updated');
            break;
          case 'category_deleted':
            _handleGranularCategoryEvent(payload, 'deleted');
            break;
          case 'variant_created':
            _handleGranularVariantEvent(payload, 'created');
            break;
          case 'variant_updated':
            _handleGranularVariantEvent(payload, 'updated');
            break;
          case 'variant_deleted':
            _handleGranularVariantEvent(payload, 'deleted');
            break;
          default:
            AppLogger.d('[DeltaSync] Unhandled delta event_type: $eventType');
        }
      } catch (e) {
        AppLogger.e(
          '[DeltaSync] Error applying delta event: $e',
          tag: 'DELTA_SYNC',
        );
      }
    }
  }

  /// ✅ ENTERPRISE: 3-layer reconnect (Delta Sync → Resume Light → Full Sync)
  ///
  /// Fluxo de 3 camadas:
  /// 1. DELTA SYNC: Tenta recuperar apenas eventos perdidos (mais leve)
  /// 2. RESUME LIGHT: Se delta indisponível, reconecta com token preservando dados
  /// 3. FULL SYNC: Se tudo falhar, faz reconexão completa
  Future<void> _resumeOrFullSync() async {
    final storeUuid = _currentStoreUuid;

    // ✅ LAYER 1: Delta sync (fastest path - only missed events)
    if (storeUuid != null && _deltaSyncManager.hasState(storeUuid)) {
      try {
        AppLogger.i(
          '[Reconnect] Layer 1: Attempting delta sync for store $storeUuid '
          '(seq=${_deltaSyncManager.getState(storeUuid)?.lastServerSeq})',
          tag: 'RECONNECT',
        );

        final result = await _deltaSyncManager.requestDelta(
          storeUuid: storeUuid,
          timeout: const Duration(seconds: 8),
        );

        if (result.success && !result.fullSyncRequired) {
          AppLogger.s(
            '[Reconnect] Delta sync succeeded: $result',
            tag: 'RECONNECT',
          );
          return; // ✅ Dados recuperados via delta — sem necessidade de full reload
        }

        AppLogger.i(
          '[Reconnect] Delta sync requires full sync (result: $result). '
          'Falling back to Layer 2...',
          tag: 'RECONNECT',
        );
      } catch (e) {
        AppLogger.w(
          '[Reconnect] Delta sync failed: $e. Falling back to Layer 2...',
          tag: 'RECONNECT',
        );
      }
    }

    // ✅ LAYER 2: Resume Light (medium path — preserve existing data, just reconnect)
    // No Totem, a reconexão via _reconnectWithNewToken já preserva os BehaviorSubjects.
    // O backend envia initial_state_loaded automaticamente ao conectar.
    // Se chegarmos aqui, a reconexão normal já está em andamento.
    AppLogger.i(
      '[Reconnect] Layer 2: Resume with preserved data (initial_state_loaded will refresh)',
      tag: 'RECONNECT',
    );
  }

  /// Getter público para o DeltaSyncManager (usado por testes e DI)
  DeltaSyncManager get deltaSyncManager => _deltaSyncManager;

  void dispose() {
    // Para os timers de ping e pong timeout
    _heartbeatManager?.stop();
    // ✅ FIX: Cancela timer de debounce para evitar emit após dispose
    _categoryDebounceTimer?.cancel();
    _categoryDebounceTimer = null;
    _pendingCategories = null;
    // ✅ DELTA SYNC: Limpa estado de sync
    _deltaSyncManager.clear();
    connectionStatusController.add(WebSocketConnectionStatus.disconnected);
    connectionStatusController.close();
    storeController.close();
    productsController.close();
    categoriesController.close();
    bannersController.close();
    orderController.close();
    _socket.disconnect();
  }

  /// ✅ ENTERPRISE: Calcula delay com exponential backoff + jitter
  /// Evita thundering herd quando múltiplos dispositivos reconectam simultaneamente
  int _calculateBackoffDelay() {
    // Exponential: 2s, 4s, 8s, 16s, 32s, 64s, 120s (cap)
    final exponentialDelay =
        _baseTokenRenewalDelay * (1 << _tokenRenewalAttempts.clamp(0, 6));
    final cappedDelay = exponentialDelay.clamp(0, _maxTokenRenewalDelay);

    // ✅ Jitter: ±30% para evitar thundering herd
    final jitterFactor = (_random.nextDouble() - 0.5) * 0.6; // -30% a +30%
    final jitter = (cappedDelay * jitterFactor).toInt();
    return (cappedDelay + jitter).clamp(
      _baseTokenRenewalDelay,
      _maxTokenRenewalDelay,
    );
  }

  // ✅ NOVO: Renova token de conexão e reconecta automaticamente
  Future<void> _renewConnectionTokenAndReconnect() async {
    // Evita múltiplas renovações simultâneas
    if (_isRenewingToken) {
      AppLogger.d('⏳ Renovação de token já em andamento, aguardando...');
      return;
    }

    // ✅ ENTERPRISE: Verifica limite de tentativas com backoff
    _tokenRenewalAttempts++;
    if (_tokenRenewalAttempts > _maxTokenRenewalAttempts) {
      AppLogger.e(
        '❌ Máximo de tentativas de renovação atingido ($_maxTokenRenewalAttempts). Parando reconexão.',
      );
      connectionStatusController.add(WebSocketConnectionStatus.disconnected);
      return;
    }

    _isRenewingToken = true;
    connectionStatusController.add(WebSocketConnectionStatus.reconnecting);
    AppLogger.d(
      '🔄 Renovação de token (tentativa $_tokenRenewalAttempts/$_maxTokenRenewalAttempts)...',
    );

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
        connectionStatusController.add(WebSocketConnectionStatus.disconnected);
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
        _scheduleTokenRenewalRetry();
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

      _tokenRenewalAttempts = 0; // ✅ Reset ao conectar com sucesso
      AppLogger.d('✅ Reconexão automática concluída com sucesso');
    } catch (e, stackTrace) {
      AppLogger.d('❌ Erro ao renovar token: $e\n$stackTrace');
      _scheduleTokenRenewalRetry();
    } finally {
      _isRenewingToken = false; // ✅ Sempre reseta, independente do caminho
    }
  }

  /// ✅ ENTERPRISE: Agenda retry de renovação com exponential backoff + jitter
  void _scheduleTokenRenewalRetry() {
    if (_tokenRenewalAttempts >= _maxTokenRenewalAttempts) {
      AppLogger.e('❌ Máximo de tentativas atingido. Reconexão encerrada.');
      connectionStatusController.add(WebSocketConnectionStatus.disconnected);
      return;
    }

    final delay = _calculateBackoffDelay();
    AppLogger.d(
      '🔄 Próxima tentativa em ${delay}ms '
      '(tentativa $_tokenRenewalAttempts/$_maxTokenRenewalAttempts)',
    );

    Future.delayed(Duration(milliseconds: delay), () {
      if (!_socket.connected) {
        _renewConnectionTokenAndReconnect();
      }
    });
  }

  // ✅ ENTERPRISE: Reconecta com novo token preservando dados existentes
  // Flag para indicar que estamos em reconexão (não deve zerar UI)
  bool _isReconnecting = false;

  Future<void> _reconnectWithNewToken(String newConnectionToken) async {
    _currentConnectionToken = newConnectionToken;
    _reconnectionCompleter = Completer<void>();
    _isReconnecting = true; // ✅ SMART RECONNECT: Preserva dados

    AppLogger.i(
      '🔄 [SMART_RECONNECT] Reconectando com dados preservados...',
      tag: 'REALTIME',
    );

    // Desconecta socket antigo
    try {
      _socket.clearListeners();
      _socket.disconnect();
      _socket.dispose();
    } catch (e) {
      AppLogger.d('⚠️ Erro ao limpar socket anterior: $e');
    }

    // ✅ NÃO reseta isSocketReadyController para false!
    // Os dados existentes nos BehaviorSubjects permanecem válidos
    // A UI não deve mostrar loading durante reconexão

    await initialize(newConnectionToken);

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
      // ✅ ENTERPRISE: Usa backoff em vez de delay fixo
      _scheduleTokenRenewalRetry();
    } finally {
      _isReconnecting = false;
    }
  }

  // ✅ SMART RECONNECT: Processa formato antigo com merge inteligente
  void _processOldMenuFormat(Map<String, dynamic> payload) {
    // Processa a loja (apenas configs, sem categorias)
    if (keyExists(payload, 'store')) {
      AppLogger.d('🏢 Processando dados da loja...');
      final storeData = payload['store'] as Map<String, dynamic>;
      final Store store = Store.fromJson(storeData);

      // ✅ AUDIT FIX: Sempre emite — o StoreCubit faz dedup expandido
      storeController.add(store);
      AppLogger.d('✅ Loja processada: ${store.name} (ID: ${store.id})');
    }

    // ✅ REFACTOR: Categorias agora vão para categoriesController (separado do store)
    if (keyExists(payload, 'categories')) {
      AppLogger.d('📁 Processando categorias...');
      final List<dynamic> categoriesJson =
          payload['categories'] as List<dynamic>;
      final List<models.Category> categories =
          categoriesJson
              .map(
                (json) =>
                    models.Category.fromJson(json as Map<String, dynamic>),
              )
              .toList();

      // ✅ AUDIT FIX: Sempre emite — length-only diff era insuficiente
      // (ignorava mudanças de nome/preço/disponibilidade dentro das categorias)
      categoriesController.add(categories);
      AppLogger.d(
        '✅ ${categories.length} categorias publicadas no categoriesController',
      );
    } else if (keyExists(payload, 'store')) {
      // Fallback: categorias vêm dentro do objeto store
      final storeData = payload['store'] as Map<String, dynamic>;
      if (storeData['categories'] != null) {
        final List<models.Category> cats =
            (storeData['categories'] as List)
                .map(
                  (json) =>
                      models.Category.fromJson(json as Map<String, dynamic>),
                )
                .toList();
        if (cats.isNotEmpty) {
          categoriesController.add(cats);
          AppLogger.d(
            '✅ ${cats.length} categorias do store publicadas no categoriesController',
          );
        }
      }
    }

    // Processa produtos
    if (keyExists(payload, 'products')) {
      AppLogger.d('📦 Processando produtos...');
      final List<Product> products =
          (payload['products'] as List).map((json) {
            return Product.fromJson(json as Map<String, dynamic>);
          }).toList();

      // ✅ AUDIT FIX: Sempre emite — length-only diff era insuficiente
      // (ignorava mudanças de preço/nome/disponibilidade dentro dos produtos)
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

  void _processNewMenuFormat(Map<String, dynamic> payload) {
    try {
      dynamic menuCategories;
      dynamic menuProducts;

      // Processa menu no novo formato PRIMEIRO
      if (payload.containsKey('data') && payload['data'] is Map) {
        final dataPayload = payload['data'] as Map<String, dynamic>;

        if (dataPayload.containsKey('menu')) {
          AppLogger.d('📋 Processando menu no novo formato...');

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

          final adapterResult = MenuAdapter.convertMenuResponse(menuResponse);
          menuCategories = adapterResult.categories;
          menuProducts = adapterResult.products;

          AppLogger.d(
            '✅ [MENU ADAPTER] Menu convertido: ${adapterResult.categories.length} cats, ${adapterResult.products.length} prods',
          );
        }
      }

      // Processa a loja (apenas configs, sem categorias embutidas)
      if (payload['store'] != null) {
        AppLogger.d('🏢 Processando dados da loja...');
        final Store store = Store.fromJson(
          payload['store'] as Map<String, dynamic>,
        );

        // ✅ AUDIT FIX: Sempre emite — o StoreCubit faz dedup expandido
        storeController.add(store);
        AppLogger.d('✅ Loja publicada: ${store.name}');
      }

      // ✅ REFACTOR: Publica categorias no stream separado
      if (menuCategories != null) {
        try {
          final List<models.Category> categoriesList = [];
          if (menuCategories is List<models.Category>) {
            categoriesList.addAll(menuCategories);
          } else if (menuCategories is List) {
            categoriesList.addAll(menuCategories.cast<models.Category>());
          }
          if (categoriesList.isNotEmpty) {
            // ✅ AUDIT FIX: Sempre emite — length-only diff era insuficiente
            categoriesController.add(categoriesList);
            AppLogger.d(
              '✅ ${categoriesList.length} categorias publicadas no categoriesController',
            );
          } else {
            AppLogger.w('⚠️ Lista de categorias do MenuAdapter está VAZIA.');
          }
        } catch (e) {
          AppLogger.e('❌ Erro ao publicar categorias: $e');
        }
      }

      // Publica produtos
      if (menuProducts != null && (menuProducts as List).isNotEmpty) {
        // ✅ AUDIT FIX: Sempre emite — length-only diff era insuficiente
        final productsList = menuProducts as List<Product>;
        productsController.add(productsList);
        AppLogger.d('✅ ${productsList.length} produtos do menu adicionados');
      }

      // Processa banners
      if (payload['banners'] != null) {
        final List<BannerModel> banners =
            (payload['banners'] as List)
                .map((json) => BannerModel.fromJson(json))
                .toList();
        bannersController.add(banners);
        AppLogger.d('✅ Banners processados: ${banners.length}');
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ ERRO CRÍTICO no _processNewMenuFormat: $e');
      AppLogger.e('📍 StackTrace: $stackTrace');

      // Fallback: tenta formato antigo se não tem categorias ainda
      if (!categoriesController.hasValue ||
          categoriesController.value.isEmpty) {
        AppLogger.d('🔄 Fallback: Tentando formato antigo...');
        _processOldMenuFormat(payload);
      } else {
        AppLogger.w('⚠️ Erro no processamento, mantendo dados atuais.');
      }
    }
  }

  // ✅ AUDIT FIX: Processa atualização da loja com MERGE inteligente
  // Preserva listas operacionais existentes quando o incoming tem listas vazias
  // (evita sobrescrever hours/payments/deliveryRules com [] do fromJson default)
  void _handleStoreUpdate(dynamic data) {
    try {
      final Map<String, dynamic> payload = _convertToStringDynamicMap(data);
      if (payload['store'] != null) {
        final storeData = payload['store'] as Map<String, dynamic>;
        final Store incomingStore = Store.fromJson(storeData);

        if (storeController.hasValue) {
          final existing = storeController.value;
          // Merge: campos de perfil sempre do incoming, listas operacionais
          // só sobrescreve se incoming tem dados (evita [] default do fromJson)
          final mergedStore = existing.copyWith(
            id: incomingStore.id ?? existing.id,
            name:
                incomingStore.name.isNotEmpty
                    ? incomingStore.name
                    : existing.name,
            urlSlug:
                incomingStore.urlSlug.isNotEmpty
                    ? incomingStore.urlSlug
                    : existing.urlSlug,
            phone:
                incomingStore.phone.isNotEmpty
                    ? incomingStore.phone
                    : existing.phone,
            zip_code: incomingStore.zip_code ?? existing.zip_code,
            street: incomingStore.street ?? existing.street,
            number: incomingStore.number ?? existing.number,
            neighborhood: incomingStore.neighborhood ?? existing.neighborhood,
            complement: incomingStore.complement ?? existing.complement,
            reference: incomingStore.reference ?? existing.reference,
            city: incomingStore.city ?? existing.city,
            state: incomingStore.state ?? existing.state,
            description: incomingStore.description ?? existing.description,
            instagram: incomingStore.instagram ?? existing.instagram,
            facebook: incomingStore.facebook ?? existing.facebook,
            tiktok: incomingStore.tiktok ?? existing.tiktok,
            image: incomingStore.image ?? existing.image,
            banner: incomingStore.banner ?? existing.banner,
            // Listas operacionais: só sobrescreve se incoming tem dados reais
            paymentMethodGroups:
                incomingStore.paymentMethodGroups.isNotEmpty
                    ? incomingStore.paymentMethodGroups
                    : existing.paymentMethodGroups,
            hours:
                incomingStore.hours.isNotEmpty
                    ? incomingStore.hours
                    : existing.hours,
            store_operation_config:
                incomingStore.store_operation_config ??
                existing.store_operation_config,
            ratingsSummary:
                incomingStore.ratingsSummary ?? existing.ratingsSummary,
            cities:
                incomingStore.cities.isNotEmpty
                    ? incomingStore.cities
                    : existing.cities,
            scheduledPauses:
                incomingStore.scheduledPauses.isNotEmpty
                    ? incomingStore.scheduledPauses
                    : existing.scheduledPauses,
            coupons:
                incomingStore.coupons.isNotEmpty
                    ? incomingStore.coupons
                    : existing.coupons,
            deliveryFeeRules:
                incomingStore.deliveryFeeRules.isNotEmpty
                    ? incomingStore.deliveryFeeRules
                    : existing.deliveryFeeRules,
            latitude: incomingStore.latitude ?? existing.latitude,
            longitude: incomingStore.longitude ?? existing.longitude,
            deliveryRadiusKm:
                incomingStore.deliveryRadiusKm ?? existing.deliveryRadiusKm,
            locale: incomingStore.locale ?? existing.locale,
            currencyCode: incomingStore.currencyCode ?? existing.currencyCode,
            timezone: incomingStore.timezone ?? existing.timezone,
            fiscalActive: incomingStore.fiscalActive,
          );
          storeController.add(mergedStore);
          AppLogger.d('✅ Loja atualizada (merge): ${mergedStore.name}');
        } else {
          storeController.add(incomingStore);
          AppLogger.d('✅ Loja atualizada (first load): ${incomingStore.name}');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.d('❌ Erro ao processar store_details_updated: $e');
      AppLogger.d('📍 StackTrace: $stackTrace');
    }
  }

  // ✅ Handler unificado para atualização de catálogo
  void _handleProductsUpdated(dynamic data) {
    AppLogger.d('📦 [_handleProductsUpdated] Processando catálogo...');
    try {
      if (data is Map && data.containsKey('products')) {
        final List<dynamic> productsJson = data['products'] as List<dynamic>;
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

        // ✅ REFACTOR: Categorias vão para categoriesController (não mais na Store)
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
          categoriesController.add(categories);
          AppLogger.d(
            '   └─ ✅ ${categories.length} categorias publicadas no categoriesController',
          );
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
          // ✅ CRITICAL: Socket está pronto após vincular cliente
          isSocketReadyController.add(true);
          AppLogger.success(
            '✅ Cliente vinculado à sessão. Socket pronto para operações!',
            tag: 'REALTIME',
          );
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
    bool orderReceived = false;

    AppLogger.d('📤 [ORDER] Enviando pedido via Socket.IO...', tag: 'CHECKOUT');
    AppLogger.d('📤 [ORDER] Payload: ${payload.toJson()}', tag: 'CHECKOUT');

    void Function(dynamic)? orderCreatedHandler;
    void Function(dynamic)? orderErrorHandler;

    void cleanup() {
      _socket.off('order_created', orderCreatedHandler);
      _socket.off('order_creation_error', orderErrorHandler);
    }

    // ✅ LISTENER TEMPORÁRIO: Escuta evento order_created enquanto aguarda
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
          cleanup();
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
        cleanup();
        if (!completer.isCompleted) {
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
        cleanup();
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

    try {
      // Chama o NOVO evento do backend
      _socket.emitWithAck(
        'create_order_from_cart',
        payload.toJson(),
        ack: (data) {
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
                cleanup();
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
              cleanup();
              completer.completeError(Exception(errorMsg));
            }
          } else {
            final errorMsg =
                data?['error'] ??
                data?['message'] ??
                'Ocorreu um erro desconhecido ao finalizar o pedido.';
            AppLogger.e(
              '❌ [ORDER] Erro do backend: $errorMsg',
              tag: 'CHECKOUT',
            );
            orderReceived = true;
            cleanup();
            completer.completeError(Exception(errorMsg));
          }
        },
      );

      return completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          cleanup();
          throw TimeoutException('Timeout ao processar pedido.');
        },
      );
    } catch (e) {
      cleanup();
      rethrow;
    }
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

  // ✅ NOVO: Configura listener para mudanças de visibilidade da tab
  void _setupVisibilityListener() {
    try {
      html.document.onVisibilityChange.listen((event) {
        final isHidden = html.document.hidden ?? false;

        if (isHidden) {
          AppLogger.d('🌙 [Visibility] Tab HIDDEN');
          _heartbeatManager?.notifyTabHidden();
        } else {
          AppLogger.d('☀️ [Visibility] Tab VISIBLE');
          _heartbeatManager?.notifyTabVisible();

          // Se tab ficou hidden tempo demais, tenta delta sync antes de full reconnect
          if (_heartbeatManager?.wasBackgroundTooLong ?? false) {
            Future.delayed(const Duration(seconds: 2), () async {
              if (_socket.connected &&
                  _currentStoreUuid != null &&
                  _deltaSyncManager.hasState(_currentStoreUuid!)) {
                // ✅ DELTA SYNC: Socket ainda vivo → tenta recuperar apenas eventos perdidos
                AppLogger.i(
                  '[Visibility] Tab retornou — tentando delta sync antes de full reconnect',
                  tag: 'RECONNECT',
                );
                try {
                  final result = await _deltaSyncManager.requestDelta(
                    storeUuid: _currentStoreUuid!,
                    timeout: const Duration(seconds: 6),
                  );
                  if (result.success && !result.fullSyncRequired) {
                    AppLogger.s(
                      '[Visibility] Delta sync succeeded after tab return: $result',
                      tag: 'RECONNECT',
                    );
                    return; // ✅ Dados recuperados sem reconectar
                  }
                } catch (e) {
                  AppLogger.w(
                    '[Visibility] Delta sync failed: $e',
                    tag: 'RECONNECT',
                  );
                }
              }
              // Fallback: full reconnect
              AppLogger.d(
                '⚠️ [Visibility] Tab ficou hidden tempo demais — forçando reconnect',
              );
              _renewConnectionTokenAndReconnect();
            });
          }
        }
      });
      AppLogger.d('✅ [Realtime] Visibility API listener configurado');
    } catch (e) {
      AppLogger.e('❌ [Realtime] Erro ao configurar Visibility API: $e');
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
