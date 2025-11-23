import 'dart:math' as math;
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:equatable/equatable.dart';

import '../../../models/customer_address.dart';
import '../../../models/delivery_type.dart';
import '../../../models/store.dart';
import '../../../repositories/delivery_repository.dart';
import '../../../core/di.dart';

part 'delivery_fee_state.dart';

class DeliveryFeeCubit extends Cubit<DeliveryFeeState> {
  final DeliveryFeeRepository? _repository;

  DeliveryFeeCubit({DeliveryFeeRepository? repository}) 
      : _repository = repository ?? getIt<DeliveryFeeRepository>(),
        super(const DeliveryFeeInitial());

  // ✅ INICIALIZA COM TIPO PADRÃO DA LOJA
  void initializeWithStore(Store? store) {
    // Tipo padrão removido - sempre inicia com delivery
    if (state is DeliveryFeeInitial) {
      emit(const DeliveryFeeInitial(deliveryType: DeliveryType.delivery));
    }
  }

  // ✅ LÓGICA DE ATUALIZAÇÃO DE TIPO CORRIGIDA E MAIS ROBUSTA
  void updateDeliveryType(DeliveryType newType) {
    // Se o estado atual já foi calculado (Loaded), cria uma nova cópia com o novo tipo.
    if (state is DeliveryFeeLoaded) {
      final loadedState = state as DeliveryFeeLoaded;
      emit(loadedState.copyWith(deliveryType: newType));
    }
    // Se o estado for qualquer outro (Initial, Loading, Error),
    // emite um novo estado `Initial` com o tipo de entrega atualizado.
    else {
      emit(DeliveryFeeInitial(deliveryType: newType));
    }
  }

  Future<void> calculate({
    required CustomerAddress? address,
    required Store store,
    required double cartSubtotal,
  }) async {
    // Pega o tipo de entrega atual do estado, qualquer que seja ele.
    final currentDeliveryType = state.deliveryType;

    // Se o tipo de entrega for retirada, o frete é sempre zero.
    if (currentDeliveryType == DeliveryType.pickup) {
      emit(const DeliveryFeeLoaded(
        deliveryFee: 0,
        isFree: true,
        deliveryType: DeliveryType.pickup,
      ));
      return;
    }

    // Se não for retirada, mas não tiver endereço, requer um endereço.
    if (address == null) {
      emit(DeliveryFeeRequiresAddress(deliveryType: currentDeliveryType));
      return;
    }

    emit(DeliveryFeeLoading(deliveryType: currentDeliveryType));

    // ✅ CRÍTICO: Verificar tipo de frete ativo para validar dados necessários
    // ✅ ATUALIZADO: Removida validação de bairros cadastrados - agora usa apenas coordenadas
    final requiresCoordinates = store.deliveryFeeRules.any(
      (r) => r.isActive && (r.ruleType == 'per_km' || r.ruleType == 'radius'),
    );

    // ✅ CRÍTICO: Validar coordenadas quando frete é por km/raio
    // ✅ ATUALIZADO: Agora sempre requer coordenadas para calcular frete (alinhado com Admin/Backend)
    if (address.latitude == null || address.longitude == null) {
      emit(DeliveryFeeError(
        'É necessário permitir acesso à localização para calcular o frete.',
        deliveryType: currentDeliveryType,
      ));
      return;
    }

    // ✅ ENTERPRISE: Tenta usar o novo sistema de cálculo primeiro
    double? calculatedFee;
    bool eligibleForFreeDelivery = false;
    String? errorMessage;

    // ✅ VALIDAÇÃO: Verifica se tem coordenadas ou address_id
    if (address.latitude != null && address.longitude != null || address.id != null) {
      try {
        final subtotalInCents = (cartSubtotal * 100).toInt();
        final result = await _repository?.calculateDeliveryFee(
          addressId: address.id,
          latitude: address.latitude,
          longitude: address.longitude,
          subtotal: subtotalInCents,
        );

        if (result != null) {
          if (result['error'] != null) {
            // ✅ TRATAMENTO DE ERRO: Se houver erro, captura mensagem específica
            errorMessage = result['error'] as String?;
            print('⚠️ Erro ao calcular frete: $errorMessage');
            
            // ✅ CRÍTICO: Tratamento específico para diferentes tipos de erro
            final lowerError = errorMessage?.toLowerCase() ?? '';
            
            // Erro de "não entrega" ou "fora da área"
            if (lowerError.contains('não entrega') || 
                lowerError.contains('fora da área') ||
                lowerError.contains('fora do raio') ||
                lowerError.contains('fora da área de entrega')) {
              emit(DeliveryFeeError(
                errorMessage ?? 'Endereço fora da área de entrega',
                deliveryType: currentDeliveryType,
              ));
              return;
            }
            
            // ✅ NOVO: Erro específico de bairro não cadastrado
            if (lowerError.contains('bairro') && lowerError.contains('não está cadastrado')) {
              emit(DeliveryFeeError(
                errorMessage ?? 'Bairro não está cadastrado na loja. Entre em contato com o estabelecimento.',
                deliveryType: currentDeliveryType,
              ));
              return;
            }
            
            // ✅ NOVO: Erro de coordenadas não configuradas
            if (lowerError.contains('não tem coordenadas') || 
                lowerError.contains('coordenadas configuradas')) {
              emit(DeliveryFeeError(
                errorMessage ?? 'Loja não tem coordenadas configuradas. Entre em contato com o suporte.',
                deliveryType: currentDeliveryType,
              ));
              return;
            }
            
            // Para outros erros, tenta fallback
            calculatedFee = null;
          } else {
            // ✅ SUCESSO: Obtém valores do resultado
            final feeValue = result['fee'];
            if (feeValue != null) {
              // ✅ CONVERSÃO: Converte de centavos para reais (já vem em centavos do backend)
              if (feeValue is int) {
                calculatedFee = feeValue / 100.0;
              } else if (feeValue is double) {
                // Se já vier em reais (backward compatibility)
                calculatedFee = feeValue;
              } else if (feeValue is num) {
                calculatedFee = feeValue.toDouble() / 100.0;
              } else {
                calculatedFee = 0.0;
              }
            } else {
              calculatedFee = 0.0;
            }
            
            // ✅ VALIDAÇÃO: Garante que fee não é negativo
            if (calculatedFee != null && calculatedFee! < 0) {
              calculatedFee = 0.0;
            }
            
            eligibleForFreeDelivery = result['eligible_for_free_delivery'] as bool? ?? false;
            
            // ✅ VALIDAÇÃO: Se elegível para frete grátis, força fee = 0
            if (eligibleForFreeDelivery) {
              calculatedFee = 0.0;
            }
          }
        } else {
          // ✅ TRATAMENTO: Se result é null, pode ser que não há entrega
          print('⚠️ Resultado do cálculo de frete é null - tentando fallback');
          calculatedFee = null;
        }
      } catch (e) {
        // ✅ TRATAMENTO DE EXCEÇÃO: Loga erro e usa fallback
        print('❌ Exceção ao calcular frete: $e');
        calculatedFee = null;
      }
    }

    // ✅ FALLBACK: Se o novo sistema não retornou, verifica se é erro de "não entrega"
    if (calculatedFee == null) {
      // ✅ CRÍTICO: Verifica se há regras novas configuradas
      final hasNewRules = store.deliveryFeeRules.any((r) => r.isActive);
      
      // ✅ VALIDAÇÃO: Se há erro específico de "não entrega" ou "bairro não cadastrado", emite erro
      if (errorMessage != null) {
        final lowerError = errorMessage.toLowerCase();
        if (lowerError.contains('fora da área') || 
            lowerError.contains('não entrega') ||
            lowerError.contains('fora do raio') ||
            lowerError.contains('bairro') && lowerError.contains('não está cadastrado') ||
            lowerError.contains('não tem coordenadas')) {
          emit(DeliveryFeeError(
            errorMessage,
            deliveryType: currentDeliveryType,
          ));
          return;
        }
      }
      
      // ✅ CRÍTICO: Só usa fallback legado se realmente não há regras novas
      if (hasNewRules) {
        // Se há regras novas mas cálculo falhou, mostra erro claro
        emit(DeliveryFeeError(
          errorMessage ?? 'Não foi possível calcular o frete. Verifique se o endereço está completo e tente novamente.',
          deliveryType: currentDeliveryType,
        ));
        return;
      }
      
      // ✅ FALLBACK: Usa sistema antigo (legado) apenas se não há regras novas
      final config = store.store_operation_config;
      final double baseFee = _calculateBaseFee(address, store);
      
      // ✅ Verifica se está fora do raio de entrega
      if (baseFee == double.infinity) {
        emit(DeliveryFeeError(
          'Endereço fora da área de entrega da loja',
          deliveryType: currentDeliveryType,
        ));
        return;
      }

      final freeShippingThreshold = config?.freeDeliveryThreshold ?? 0;

      if (freeShippingThreshold > 0 && cartSubtotal >= freeShippingThreshold) {
        emit(DeliveryFeeLoaded(
          deliveryFee: 0,
          isFree: true,
          deliveryType: currentDeliveryType,
        ));
        return;
      }

      emit(DeliveryFeeLoaded(
        deliveryFee: baseFee,
        isFree: baseFee == 0,
        deliveryType: currentDeliveryType,
      ));
      return;
    }

    // ✅ Usa o resultado do novo sistema
    if (eligibleForFreeDelivery) {
      emit(DeliveryFeeLoaded(
        deliveryFee: 0,
        isFree: true,
        deliveryType: currentDeliveryType,
      ));
      return;
    }

    emit(DeliveryFeeLoaded(
      deliveryFee: calculatedFee,
      isFree: calculatedFee == 0,
      deliveryType: currentDeliveryType,
    ));
  }

  // A função de cálculo base permanece a mesma.
  double _calculateBaseFee(CustomerAddress address, Store store) {
    // ✅ VALIDAÇÃO: Verifica se está dentro do raio de entrega
    if (store.latitude != null && store.longitude != null &&
        address.latitude != null && address.longitude != null) {
      final isWithinRadius = _isWithinDeliveryRadius(
        storeLat: store.latitude!,
        storeLon: store.longitude!,
        deliveryRadiusKm: store.deliveryRadiusKm,
        customerLat: address.latitude!,
        customerLon: address.longitude!,
      );

      if (!isWithinRadius) {
        // Se estiver fora do raio, retorna um valor muito alto para indicar indisponibilidade
        // Isso será tratado no estado para mostrar mensagem apropriada
        return double.infinity;
      }
    }

    final scope = store.store_operation_config?.deliveryScope ?? 'city';

    if (scope == 'neighborhood') {
      final city = store.cities.firstWhereOrNull((c) => c.id == address.cityId);
      final neighborhood = city?.neighborhoods.firstWhereOrNull((n) => n.id == address.neighborhoodId);
      if (neighborhood != null && neighborhood.isActive && !neighborhood.freeDelivery) {
        return (neighborhood.deliveryFee);
      }
    } else { // 'city'
      final city = store.cities.firstWhereOrNull((c) => c.id == address.cityId);
      if (city != null && city.isActive) {
        return (city.deliveryFee.toDouble());
      }
    }
    return 0.0;
  }

  bool _isWithinDeliveryRadius({
    required double storeLat,
    required double storeLon,
    required double? deliveryRadiusKm,
    required double customerLat,
    required double customerLon,
  }) {
    if (deliveryRadiusKm == null || deliveryRadiusKm <= 0) {
      // Se não há raio definido, assume que está dentro (fallback)
      return true;
    }

    final distance = _calculateDistance(
      lat1: storeLat,
      lon1: storeLon,
      lat2: customerLat,
      lon2: customerLon,
    );

    return distance <= deliveryRadiusKm;
  }

  // Fórmula Haversine para calcular distância em km
  double _calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadiusKm * c;

    return distance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}