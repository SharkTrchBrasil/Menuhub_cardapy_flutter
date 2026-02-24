import 'dart:math' as math;
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:equatable/equatable.dart';

import '../../../models/customer_address.dart';
import '../../../models/delivery_type.dart';
import '../../../models/store.dart';
import '../../../repositories/delivery_repository.dart';
import '../../../repositories/realtime_repository.dart';
import '../../../core/di.dart';
import '../../../core/utils/app_logger.dart';

part 'delivery_fee_state.dart';

class DeliveryFeeCubit extends Cubit<DeliveryFeeState> {
  final DeliveryFeeRepository? _repository;
  final RealtimeRepository? _realtimeRepository;

  // ✅ CORREÇÃO BUG #2: Flag para evitar cálculos simultâneos (loop infinito)
  bool _isCalculating = false;
  // ✅ Cache para evitar recálculos desnecessários
  String? _lastCalculationKey;

  DeliveryFeeCubit({
    DeliveryFeeRepository? repository,
    RealtimeRepository? realtimeRepository,
  }) : _repository = repository ?? getIt<DeliveryFeeRepository>(),
       _realtimeRepository = realtimeRepository ?? getIt<RealtimeRepository>(),
       super(const DeliveryFeeInitial());

  // ✅ INICIALIZA COM TIPO PADRÃO DA LOJA
  void initializeWithStore(Store? store) {
    // Tipo padrão removido - sempre inicia com delivery
    if (state is DeliveryFeeInitial) {
      emit(const DeliveryFeeInitial(deliveryType: DeliveryType.delivery));
    }
    // Sempre que a loja for reinicializada ou atualizada, invalidamos o cache
    invalidateCache();
  }

  /// Limpa o cache de cálculo para forçar um novo processamento
  void invalidateCache() {
    _lastCalculationKey = null;
    AppLogger.d('🧹 [DELIVERY_FEE] Cache invalidado');
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
    bool isSilent = false,
    void Function(double? fee, String? error)? onResult,
  }) async {
    // ✅ CORREÇÃO BUG #2: Cria chave única para este cálculo
    final calculationKey =
        '${address?.id}_${address?.latitude}_${address?.longitude}_${cartSubtotal.toInt()}_${state.deliveryType}';

    // ✅ MELHORIA: Só ignora se for EXATAMENTE a mesma chave de cálculo
    if (_isCalculating && _lastCalculationKey == calculationKey) {
      AppLogger.d(
        '⏭️ [DELIVERY_FEE] Cálculo já em andamento para esta chave, ignorando',
      );
      // Adiciona um listener temporário para chamar o callback quando acabar, se necessário
      return;
    }

    // Se já temos um resultado válido com os mesmos parâmetros e NÃO estamos calculando, não recalcula
    if (!_isCalculating &&
        _lastCalculationKey == calculationKey &&
        state is DeliveryFeeLoaded) {
      AppLogger.d(
        '⏭️ [DELIVERY_FEE] Usando cache - parâmetros iguais ao último cálculo',
      );
      if (onResult != null) {
        final loaded = state as DeliveryFeeLoaded;
        onResult(loaded.deliveryFee, null);
      }
      return;
    }

    if (!_isCalculating &&
        _lastCalculationKey == calculationKey &&
        state is DeliveryFeeError) {
      AppLogger.d('⏭️ [DELIVERY_FEE] Usando cache de erro');
      if (onResult != null) {
        final errorState = state as DeliveryFeeError;
        onResult(null, errorState.message);
      }
      return;
    }

    // ✅ Marca como calculando e salva a chave
    _isCalculating = true;
    _lastCalculationKey = calculationKey;

    // Pega o tipo de entrega atual do estado, qualquer que seja ele.
    final currentDeliveryType = state.deliveryType;

    // Se o tipo de entrega for retirada, o frete é sempre zero.
    if (currentDeliveryType == DeliveryType.pickup) {
      _isCalculating = false;
      if (onResult != null) onResult(0, null);
      if (!isSilent) {
        emit(
          const DeliveryFeeLoaded(
            deliveryFee: 0,
            isFree: true,
            deliveryType: DeliveryType.pickup,
          ),
        );
      }
      return;
    }

    // Se não for retirada, mas não tiver endereço, requer um endereço.
    if (address == null) {
      _isCalculating = false;
      if (onResult != null) onResult(null, 'Endereço nulo');
      if (!isSilent) {
        emit(DeliveryFeeRequiresAddress(deliveryType: currentDeliveryType));
      }
      return;
    }

    if (!isSilent) emit(DeliveryFeeLoading(deliveryType: currentDeliveryType));

    // ✅ CRÍTICO: Verificar tipo de frete ativo para validar dados necessários
    // ✅ CORREÇÃO: Inclui progressive_radius e simple_radius que também precisam de coordenadas
    final requiresCoordinates = store.deliveryFeeRules.any(
      (r) =>
          r.isActive &&
          (r.ruleType == 'per_km' ||
              r.ruleType == 'radius' ||
              r.ruleType == 'progressive_radius' ||
              r.ruleType == 'simple_radius'),
    );

    // ✅ CRÍTICO: Validar coordenadas quando frete é por km/raio
    if (requiresCoordinates &&
        (address.latitude == null || address.longitude == null)) {
      _isCalculating = false;
      if (onResult != null) onResult(null, 'Coordenadas necessárias');
      if (!isSilent) {
        emit(
          DeliveryFeeError(
            'É necessário permitir acesso à localização para calcular o frete. O frete desta loja é calculado por distância.',
            deliveryType: currentDeliveryType,
          ),
        );
      }
      return;
    }

    // ✅ ENTERPRISE: Tenta usar o novo sistema de cálculo primeiro
    double? calculatedFee;
    bool eligibleForFreeDelivery = false;
    String? errorMessage;

    // ✅ VALIDAÇÃO: Verifica se tem coordenadas ou address_id
    if (address.latitude != null && address.longitude != null ||
        address.id != null) {
      try {
        final subtotalInCents = (cartSubtotal * 100).toInt();

        // ✅ NOVO: Tenta WebSocket primeiro (evita CORS)
        Map<String, dynamic>? result;

        try {
          print('🚚 Calculando frete via WebSocket...');
          result = await _realtimeRepository?.calculateDeliveryFee(
            addressId: address.id,
            latitude: address.latitude,
            longitude: address.longitude,
            subtotal: subtotalInCents,
          );
          print('✅ Resposta WebSocket: $result');
        } catch (wsError) {
          print('⚠️ Erro WebSocket, tentando HTTP: $wsError');
          // Fallback para HTTP se WebSocket falhar
          result = await _repository?.calculateDeliveryFee(
            addressId: address.id,
            latitude: address.latitude,
            longitude: address.longitude,
            subtotal: subtotalInCents,
          );
        }

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
              _isCalculating = false;
              if (onResult != null) onResult(null, errorMessage);
              if (!isSilent) {
                emit(
                  DeliveryFeeError(
                    errorMessage ??
                        'O restaurante não realiza entregas nesta região',
                    deliveryType: currentDeliveryType,
                  ),
                );
              }
              return;
            }

            // ✅ NOVO: Erro de coordenadas não configuradas
            if (lowerError.contains('não tem coordenadas') ||
                lowerError.contains('coordenadas configuradas')) {
              _isCalculating = false;
              if (onResult != null) onResult(null, errorMessage);
              if (!isSilent) {
                emit(
                  DeliveryFeeError(
                    errorMessage ??
                        'Loja não tem coordenadas configuradas. Entre em contato com o suporte.',
                    deliveryType: currentDeliveryType,
                  ),
                );
              }
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

            eligibleForFreeDelivery =
                result['eligible_for_free_delivery'] as bool? ?? false;

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
        // ✅ TRATAMENTO DE EXCEÇÃO: Loga erro e tenta cálculo local
        print('❌ Exceção ao calcular frete: $e');

        // ✅ NOVO: Se for erro de conexão, tenta calcular localmente
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('connection') ||
            errorStr.contains('xmlhttprequest') ||
            errorStr.contains('network') ||
            errorStr.contains('timeout')) {
          print(
            '🔄 Erro de conexão detectado - calculando frete localmente...',
          );

          // ✅ CÁLCULO LOCAL: Usa as regras de frete carregadas no Store
          final localResult = _calculateFeeLocally(
            store: store,
            address: address,
            cartSubtotal: cartSubtotal,
            deliveryType: currentDeliveryType,
          );

          if (localResult != null) {
            calculatedFee = localResult['fee'];
            eligibleForFreeDelivery = localResult['isFree'] ?? false;
            print(
              '✅ Frete calculado localmente: R\$ ${calculatedFee?.toStringAsFixed(2)}',
            );
          } else {
            // Se cálculo local também falhar, tenta fallback legado
            calculatedFee = null;
          }
        } else {
          calculatedFee = null;
        }
      }
    }

    // ✅ FALLBACK: Se o novo sistema não retornou, verifica se é erro de "não entrega"
    if (calculatedFee == null) {
      // ✅ CRÍTICO: Verifica se há regras novas configuradas
      final hasNewRules = store.deliveryFeeRules.any((r) => r.isActive);

      // ✅ VALIDAÇÃO: Se há erro específico de "não entrega", emite erro
      if (errorMessage != null) {
        final lowerError = errorMessage.toLowerCase();
        if (lowerError.contains('fora da área') ||
            lowerError.contains('não entrega') ||
            lowerError.contains('fora do raio') ||
            lowerError.contains('não tem coordenadas')) {
          _isCalculating = false;
          if (onResult != null) onResult(null, errorMessage);
          if (!isSilent) {
            emit(
              DeliveryFeeError(errorMessage, deliveryType: currentDeliveryType),
            );
          }
          return;
        }
      }

      // ✅ CRÍTICO: Só usa fallback legado se realmente não há regras novas
      if (hasNewRules) {
        // Se há regras novas mas cálculo falhou, mostra erro claro
        _isCalculating = false;
        if (onResult != null) onResult(null, errorMessage);
        if (!isSilent) {
          emit(
            DeliveryFeeError(
              errorMessage ??
                  'Não foi possível calcular o frete. Verifique se o endereço está completo e tente novamente.',
              deliveryType: currentDeliveryType,
            ),
          );
        }
        return;
      }

      // ✅ FALLBACK: Usa sistema antigo (legado) apenas se não há regras novas
      final config = store.store_operation_config;
      final double baseFee = _calculateBaseFee(address, store);

      // ✅ Verifica se está fora do raio de entrega
      if (baseFee == double.infinity) {
        _isCalculating = false;
        if (onResult != null) onResult(null, 'Fora da área');
        if (!isSilent) {
          emit(
            DeliveryFeeError(
              'O restaurante não realiza entregas nesta região',
              deliveryType: currentDeliveryType,
            ),
          );
        }
        return;
      }

      // ✅ CORREÇÃO: Usa frete grátis das regras de frete (prioridade) ou config antigo (fallback)
      final freeShippingThreshold =
          store.getFreeDeliveryThresholdForDelivery() ?? 0;

      if (freeShippingThreshold > 0 && cartSubtotal >= freeShippingThreshold) {
        _isCalculating = false;
        if (onResult != null) onResult(0, null);
        if (!isSilent) {
          emit(
            DeliveryFeeLoaded(
              deliveryFee: 0,
              isFree: true,
              deliveryType: currentDeliveryType,
            ),
          );
        }
        return;
      }

      _isCalculating = false;
      if (onResult != null) onResult(baseFee, null);
      if (!isSilent) {
        emit(
          DeliveryFeeLoaded(
            deliveryFee: baseFee,
            isFree: baseFee == 0,
            deliveryType: currentDeliveryType,
          ),
        );
      }
      return;
    }

    // ✅ Usa o resultado do novo sistema
    if (eligibleForFreeDelivery) {
      _isCalculating = false;
      if (onResult != null) onResult(0, null);
      if (!isSilent) {
        emit(
          DeliveryFeeLoaded(
            deliveryFee: 0,
            isFree: true,
            deliveryType: currentDeliveryType,
          ),
        );
      }
      return;
    }

    _isCalculating = false;
    if (onResult != null) onResult(calculatedFee, null);
    if (!isSilent) {
      emit(
        DeliveryFeeLoaded(
          deliveryFee: calculatedFee ?? 0,
          isFree: (calculatedFee ?? 0) == 0,
          deliveryType: currentDeliveryType,
        ),
      );
    }
  }

  // A função de cálculo base permanece a mesma.
  double _calculateBaseFee(CustomerAddress address, Store store) {
    // ✅ VALIDAÇÃO: Verifica se está dentro do raio de entrega
    if (store.latitude != null &&
        store.longitude != null &&
        address.latitude != null &&
        address.longitude != null) {
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

    // ✅ REMOVIDO: Não usamos mais frete por bairros (neighborhood_fee)
    // Usa apenas o sistema de cidades (fallback legado)
    final city = store.cities.firstWhereOrNull((c) => c.id == address.cityId);
    if (city != null && city.isActive) {
      return (city.deliveryFee.toDouble());
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

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
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

  /// ✅ NOVO: Calcula frete localmente usando as regras carregadas no Store
  /// Usado como fallback quando a API de cálculo de frete falha por erro de conexão
  Map<String, dynamic>? _calculateFeeLocally({
    required Store store,
    required CustomerAddress address,
    required double cartSubtotal,
    required DeliveryType? deliveryType,
  }) {
    try {
      // Se for retirada, frete é sempre 0
      if (deliveryType == DeliveryType.pickup) {
        return {'fee': 0.0, 'isFree': true};
      }

      // Verifica coordenadas
      if (store.latitude == null ||
          store.longitude == null ||
          address.latitude == null ||
          address.longitude == null) {
        print('⚠️ Cálculo local: Coordenadas incompletas');
        return null;
      }

      // Calcula distância
      final distanceKm = _calculateDistance(
        lat1: store.latitude!,
        lon1: store.longitude!,
        lat2: address.latitude!,
        lon2: address.longitude!,
      );
      print(
        '📏 Cálculo local: Distância = ${distanceKm.toStringAsFixed(2)} km',
      );

      // Busca regras ativas para delivery
      final activeRules =
          store.deliveryFeeRules
              .where((r) => r.isActive && r.deliveryMethod == 'delivery')
              .toList();

      if (activeRules.isEmpty) {
        print('⚠️ Cálculo local: Nenhuma regra ativa para delivery');
        return null;
      }

      // Ordena por prioridade (maior primeiro)
      activeRules.sort((a, b) => b.priority.compareTo(a.priority));

      for (final rule in activeRules) {
        // Verifica frete grátis por valor mínimo
        if (rule.freeDeliveryThreshold != null &&
            cartSubtotal >= rule.freeDeliveryThreshold!) {
          print(
            '✅ Cálculo local: Frete grátis (subtotal >= ${rule.freeDeliveryThreshold})',
          );
          return {'fee': 0.0, 'isFree': true};
        }

        final config = rule.config;

        // ════════════════════════════════════════════════════════════
        // REGRA: per_km (faixas de km)
        // ════════════════════════════════════════════════════════════
        if (rule.ruleType == 'per_km') {
          final ranges = config['ranges'] as List<dynamic>? ?? [];
          if (ranges.isEmpty) continue;

          // Ordena faixas por max_km
          final sortedRanges = List<Map<String, dynamic>>.from(
            ranges.map((r) => Map<String, dynamic>.from(r as Map)),
          );
          sortedRanges.sort(
            (a, b) => (a['max_km'] as num).compareTo(b['max_km'] as num),
          );

          for (final range in sortedRanges) {
            final maxKm = (range['max_km'] as num?)?.toDouble() ?? 0;
            if (distanceKm <= maxKm) {
              final feeCents = (range['fee'] as num?)?.toDouble() ?? 0;
              final feeReais = feeCents / 100.0;
              print(
                '✅ Cálculo local: Faixa encontrada (até $maxKm km) = R\$ ${feeReais.toStringAsFixed(2)}',
              );
              return {'fee': feeReais, 'isFree': feeReais == 0};
            }
          }

          // Fora de todas as faixas
          if (config['allow_outside_range'] == true &&
              sortedRanges.isNotEmpty) {
            final lastRange = sortedRanges.last;
            final feeCents = (lastRange['fee'] as num?)?.toDouble() ?? 0;
            final feeReais = feeCents / 100.0;
            print('⚠️ Cálculo local: Fora das faixas, usando última');
            return {'fee': feeReais, 'isFree': feeReais == 0};
          }

          print(
            '❌ Cálculo local: Distância $distanceKm km fora de todas as faixas',
          );
          continue; // Tenta próxima regra
        }

        // ════════════════════════════════════════════════════════════
        // REGRA: radius, simple_radius, progressive_radius
        // ════════════════════════════════════════════════════════════
        if (rule.ruleType == 'radius' ||
            rule.ruleType == 'simple_radius' ||
            rule.ruleType == 'progressive_radius') {
          // Simple radius: raio fixo com taxa fixa
          if (rule.ruleType == 'simple_radius') {
            final radiusKm = (config['radius_km'] as num?)?.toDouble() ?? 0;
            final feeCents = (config['fee'] as num?)?.toDouble() ?? 0;

            if (distanceKm <= radiusKm) {
              final feeReais = feeCents / 100.0;
              print(
                '✅ Cálculo local: Dentro do raio simples ($radiusKm km) = R\$ ${feeReais.toStringAsFixed(2)}',
              );
              return {'fee': feeReais, 'isFree': feeReais == 0};
            } else {
              print(
                '❌ Cálculo local: Fora do raio simples ($distanceKm km > $radiusKm km)',
              );
              continue;
            }
          }

          // Progressive radius: taxa base + progressiva
          final maxRadiusKm =
              (config['max_radius_km'] as num?)?.toDouble() ?? 0;
          final baseRadiusKm =
              (config['base_radius_km'] as num?)?.toDouble() ?? 0;
          final freeKm = (config['free_km'] as num?)?.toDouble() ?? 0;
          final baseFeeCents = (config['base_fee'] as num?)?.toDouble() ?? 0;
          final kmRate = (config['km_rate'] as num?)?.toDouble() ?? 0;

          // Verifica se está dentro do raio máximo
          if (maxRadiusKm > 0 && distanceKm > maxRadiusKm) {
            if (config['allow_outside_radius'] == true) {
              final outsideFeeCents =
                  (config['outside_fee'] as num?)?.toDouble() ?? baseFeeCents;
              final feeReais = outsideFeeCents / 100.0;
              print(
                '⚠️ Cálculo local: Fora do raio máximo, usando outside_fee = R\$ ${feeReais.toStringAsFixed(2)}',
              );
              return {'fee': feeReais, 'isFree': feeReais == 0};
            }
            print(
              '❌ Cálculo local: Fora do raio máximo ($distanceKm km > $maxRadiusKm km)',
            );
            continue;
          }

          // Calcula taxa progressiva
          double feeCents;
          if (freeKm > 0 && distanceKm <= freeKm) {
            feeCents = 0;
          } else if (baseRadiusKm > freeKm && distanceKm <= baseRadiusKm) {
            feeCents = baseFeeCents;
          } else {
            final startKm = freeKm >= baseRadiusKm ? freeKm : baseRadiusKm;
            final extraKm = (distanceKm - startKm).clamp(0, double.infinity);
            feeCents = baseFeeCents + (extraKm * kmRate);
          }

          final feeReais = feeCents / 100.0;
          print(
            '✅ Cálculo local: Raio progressivo = R\$ ${feeReais.toStringAsFixed(2)}',
          );
          return {'fee': feeReais, 'isFree': feeReais == 0};
        }
      }

      // Nenhuma regra se aplicou
      print(
        '❌ Cálculo local: Nenhuma regra se aplicou à distância $distanceKm km',
      );
      return null;
    } catch (e) {
      print('❌ Erro no cálculo local: $e');
      return null;
    }
  }
}
