import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:totem/models/order.dart';
import 'package:totem/repositories/realtime_repository.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/core/utils/app_logger.dart';
import 'package:totem/core/exceptions/app_exception.dart';
import '../../models/create_order_payload.dart';
import '../../models/delivery_type.dart';
import '../../models/store.dart';
import '../../services/store_status_service.dart';
import '../../services/geolocation_service.dart';
import '../cart/cart_cubit.dart';
import '../cart/cart_state.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this.realtimeRepository,
    required this.customerRepository,
  }) : super(const CheckoutState()) {
    _initAppVersion();
  }

  final RealtimeRepository realtimeRepository;
  final CustomerRepository customerRepository;
  String _appVersion = '1.0.0';

  Future<void> _initAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (e) {
      AppLogger.error('Erro ao obter versão do app: $e', tag: 'CHECKOUT');
    }
  }

  void initialize(Store store, {DeliveryType? deliveryType}) {
    AppLogger.debug(
      'Inicializando métodos de pagamento - Store: ${store.id}, Grupos: ${store.paymentMethodGroups.length}',
      tag: 'CHECKOUT',
    );
    
    // Log detalhado apenas em debug
    for (final group in store.paymentMethodGroups) {
      AppLogger.debug(
        'Grupo: ${group.name} (${group.methods.length} métodos)',
        tag: 'CHECKOUT',
      );
    }
    
    // Filtra métodos ativos e disponíveis para o tipo de entrega
    final availableMethods = store.paymentMethodGroups
        .expand((group) => group.methods)
        .where((method) {
          final activation = method.activation;
          if (activation == null || !activation.isActive) {
            return false;
          }
          
          // Se não tiver tipo de entrega definido, mostra todos os métodos ativos
          if (deliveryType == null) {
            return true;
          }
          
          // Filtra por tipo de entrega
          if (deliveryType == DeliveryType.delivery && !activation.isForDelivery) {
            return false;
          }
          if (deliveryType == DeliveryType.pickup && !activation.isForPickup) {
            return false;
          }
          
          return true;
        })
        .toList();
    
    AppLogger.debug('Total de métodos disponíveis: ${availableMethods.length}', tag: 'CHECKOUT');
    
    if (availableMethods.isEmpty) {
      AppLogger.warning(
        'Nenhum método de pagamento disponível para ${deliveryType?.name ?? "todos os tipos"}',
        tag: 'CHECKOUT',
      );
      emit(state.copyWith(selectedPaymentMethod: null));
      return;
    }
    
    // Tenta encontrar um método OFFLINE/CASH, se não encontrar, pega o primeiro disponível
    final defaultMethod = availableMethods.firstWhere(
      (m) => m.method_type == 'OFFLINE' || m.method_type == 'CASH',
      orElse: () => availableMethods.first,
    );
    
    AppLogger.success('Método selecionado: ${defaultMethod.name}', tag: 'CHECKOUT');
    emit(state.copyWith(selectedPaymentMethod: defaultMethod));
  }
  
  /// ✅ Atualiza método de pagamento quando tipo de entrega muda
  void updateForDeliveryType(Store store, DeliveryType deliveryType) {
    initialize(store, deliveryType: deliveryType);
  }

  void updatePaymentMethod(PlatformPaymentMethod newMethod) {
    if (newMethod.method_type != 'CASH') {
      emit(state.copyWith(selectedPaymentMethod: newMethod, changeFor: 0));
    } else {
      emit(state.copyWith(selectedPaymentMethod: newMethod));
    }
  }

  void updateChange(double? amount) {
    emit(state.copyWith(changeFor: amount ?? 0));
  }

  void setObservation(String text) {
    emit(state.copyWith(observation: text));
  }

  void updateNeedsChange(bool needs) {
    emit(state.copyWith(
        needsChange: needs, changeFor: needs ? state.changeFor : null));
  }

  void updateChangeFor(double? amount) {
    emit(state.copyWith(changeFor: amount));
  }

  void updateScheduling(bool isScheduled, DateTime? scheduledFor) {
    emit(state.copyWith(isScheduled: isScheduled, scheduledFor: scheduledFor));
  }

  Future<void> placeOrder({
    required AuthState authState,
    required CartState cartState,
    required AddressState addressState,
    required DeliveryFeeState feeState,
    required Store? store,
  }) async {
    // ✅ PROTEÇÃO: Evita execução simultânea (duplo clique)
    if (state.status == CheckoutStatus.loading) {
      AppLogger.warning('⚠️ [CHECKOUT] placeOrder() já está em execução, ignorando chamada duplicada', tag: 'CHECKOUT');
      return;
    }
    
    AppLogger.info('🚀 [CHECKOUT] placeOrder() chamado', tag: 'CHECKOUT');
    emit(state.copyWith(status: CheckoutStatus.loading));

    // ✅ VALIDAÇÃO: Verifica se deliveryType não é null
    if (feeState.deliveryType == null) {
      AppLogger.error('❌ [CHECKOUT] deliveryType é null no início', tag: 'CHECKOUT');
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: "Tipo de entrega não selecionado. Por favor, selecione uma opção.",
      ));
      return;
    }

    // ✅ VALIDAÇÃO: Verifica se pode fazer checkout
    if (store != null) {
      final deliveryType = feeState.deliveryType!.name; // ✅ Agora é seguro usar ! pois validamos acima
      AppLogger.debug('🔍 [CHECKOUT] Verificando status da loja: deliveryType=$deliveryType', tag: 'CHECKOUT');
      final status = StoreStatusService.canCheckout(store, deliveryType);
      if (!status.canReceiveOrders) {
        AppLogger.warning('⚠️ [CHECKOUT] Loja não pode receber pedidos: ${StoreStatusService.getFriendlyMessage(status)}', tag: 'CHECKOUT');
        emit(state.copyWith(
          status: CheckoutStatus.error,
          errorMessage: StoreStatusService.getFriendlyMessage(status),
        ));
        return;
      }
      AppLogger.debug('✅ [CHECKOUT] Loja pode receber pedidos', tag: 'CHECKOUT');
    } else {
      AppLogger.warning('⚠️ [CHECKOUT] Store é null', tag: 'CHECKOUT');
    }

    // ✅ CORREÇÃO APLICADA AQUI
    // Acessa a taxa de entrega de forma segura, tratando todos os tipos de estado.
    int deliveryFeeInCents = 0;
    if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
      deliveryFeeInCents = (feeState.deliveryFee * 100).toInt();
    }

    final cart = cartState.cart;
    final customer = authState.customer;
    if (customer == null) {
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: "Cliente não autenticado."));
      return;
    }
    if (cart.items.isEmpty) {
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: "Seu carrinho está vazio."));
      return;
    }
    if (state.selectedPaymentMethod == null) {
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: "Selecione uma forma de pagamento."));
      return;
    }

    // ✅ NOVO: Validação de pedido mínimo (apenas para delivery)
    if (store != null && feeState.deliveryType == DeliveryType.delivery) {
      final minOrder = store.getMinOrderForDelivery();
      if (minOrder > 0) {
        // Calcula total do pedido (subtotal + frete + taxa de pagamento)
        int deliveryFeeInCents = 0;
        if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
          deliveryFeeInCents = (feeState.deliveryFee * 100).toInt();
        }
        
        double paymentFee = 0.0;
        if (state.selectedPaymentMethod != null && state.selectedPaymentMethod!.activation != null) {
          final subtotalInReais = cartState.cart.subtotal / 100.0;
          paymentFee = state.selectedPaymentMethod!.activation!.calculateFee(subtotalInReais);
        }
        
        final totalInReais = (cartState.cart.total / 100.0) + (deliveryFeeInCents / 100.0) + paymentFee;
        
        if (totalInReais < minOrder) {
          emit(state.copyWith(
            status: CheckoutStatus.error,
            errorMessage: "O valor mínimo para entrega é de R\$ ${minOrder.toStringAsFixed(2).replaceAll('.', ',')}. Valor atual: R\$ ${totalInReais.toStringAsFixed(2).replaceAll('.', ',')}",
          ));
          return;
        }
      }
    }

    try {
      // ✅ SEGURANÇA: Obtém coordenadas GPS reais do cliente - REMOVIDO PARA EVITAR POPUP
      // O endereço selecionado já possui coordenadas confiáveis o suficiente.
      double? customerLat;
      double? customerLng;
      
      // Mantemos a logica de usar o endereço selecionado se disponível
      if (feeState.deliveryType == DeliveryType.delivery && addressState.selectedAddress != null) {
          customerLat = addressState.selectedAddress!.latitude;
          customerLng = addressState.selectedAddress!.longitude;
      }

      // Extrai dados de pagamento online se for método online
      String? mercadopagoPaymentId;
      String? paymentType;
      
      if (state.selectedPaymentMethod!.method_type == 'ONLINE') {
        final details = state.selectedPaymentMethod!.activation?.details ?? {};
        mercadopagoPaymentId = details['mercadopago_payment_id'] as String?;
        paymentType = 'online';
      } else {
        paymentType = 'delivery';
      }

      // ✅ VALIDAÇÃO: Verifica se deliveryType não é null
      if (feeState.deliveryType == null) {
        AppLogger.error('❌ [CHECKOUT] deliveryType é null', tag: 'CHECKOUT');
        emit(state.copyWith(
          status: CheckoutStatus.error,
          errorMessage: "Tipo de entrega não selecionado. Por favor, selecione uma opção.",
        ));
        return;
      }

      final payload = CreateOrderPayload(
        paymentMethodId: state.selectedPaymentMethod!.id,
        deliveryType: feeState.deliveryType!.name, // ✅ Agora é seguro usar ! pois validamos acima
        addressId: addressState.selectedAddress?.id,
        observation: state.observation,
        needsChange: state.needsChange,
        changeFor: state.changeFor,
        deliveryFee: deliveryFeeInCents,
        isScheduled: state.isScheduled,
        scheduledFor: state.scheduledFor?.toIso8601String(),
        customerLatitude: customerLat,
        customerLongitude: customerLng,
        mercadopagoPaymentId: mercadopagoPaymentId,
        paymentType: paymentType,
        // ✅ ALINHAMENTO iFOOD: Origem do pedido
        platform: _getPlatform(),
        appName: 'Totem',
        appVersion: _appVersion,
        salesChannel: 'TOTEM',
      );

      AppLogger.info('Enviando pedido...', tag: 'CHECKOUT');
      final order = await realtimeRepository.sendOrder(payload);
      AppLogger.success('Pedido criado com sucesso: #${order.id}', tag: 'CHECKOUT');

      emit(state.copyWith(status: CheckoutStatus.success, finalOrder: order));
      
    } on CartException catch (e) {
      AppLogger.error('Erro no carrinho: ${e.message}', error: e, tag: 'CHECKOUT');
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: e.message,
      ));
    } on PaymentException catch (e) {
      AppLogger.error('Erro no pagamento: ${e.message}', error: e, tag: 'CHECKOUT');
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: e.message,
      ));
    } on NetworkException catch (e) {
      AppLogger.error('Erro de rede: ${e.message}', error: e, tag: 'CHECKOUT');
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: 'Erro de conexão. Verifique sua internet e tente novamente.',
      ));
    } on ServerException catch (e) {
      AppLogger.error('Erro do servidor: ${e.message}', error: e, tag: 'CHECKOUT');
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: e.message,
      ));
    } catch (e, stackTrace) {
      AppLogger.error(
        'Erro inesperado ao criar pedido',
        error: e,
        stackTrace: stackTrace,
        tag: 'CHECKOUT',
      );
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: _parseErrorMessage(e.toString()),
      ));
    }
  }
  
  /// Extrai mensagem amigável de erros genéricos
  String _parseErrorMessage(String error) {
    // Remove prefixos comuns de exceção
    var message = error
        .replaceAll('Exception: ', '')
        .replaceAll('Error: ', '')
        .replaceAll('SocketException: ', 'Erro de conexão: ');
    
    // Traduz mensagens comuns
    if (message.contains('SocketException') || message.contains('connection')) {
      return 'Erro de conexão. Verifique sua internet.';
    }
    if (message.contains('timeout')) {
      return 'A operação demorou muito. Tente novamente.';
    }
    
    // Limita tamanho da mensagem
    if (message.length > 100) {
      return 'Ocorreu um erro. Tente novamente.';
    }
    
    return message;
  }
  
  /// ✅ ALINHAMENTO iFOOD: Detecta plataforma do dispositivo
  String _getPlatform() {
    // Usa import condicional para detectar plataforma
    try {
      // ignore: library_prefixes
      const bool isWeb = bool.fromEnvironment('dart.library.html');
      if (isWeb) return 'WEB';
      
      // Para mobile, verifica via dart:io
      // TODO: Adicionar detecção via TargetPlatform quando necessário
      return 'ANDROID'; // Padrão para Totem (geralmente Android)
    } catch (_) {
      return 'WEB';
    }
  }
}