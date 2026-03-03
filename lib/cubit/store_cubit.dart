// lib/cubit/store_cubit.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/repositories/realtime_repository.dart';
import 'package:totem/core/utils/app_logger.dart';
import 'package:totem/utils/seo_helper.dart';

import '../models/store.dart';
import '../core/di.dart';
import '../pages/address/cubits/delivery_fee_cubit.dart';

/// StoreCubit — responsável APENAS pelos dados da loja:
/// configurações, horários, métodos de pagamento, operação, etc.
///
/// O catálogo (categorias, produtos, banners, selectedCategory)
/// agora é gerenciado pelo CatalogCubit.
class StoreCubit extends Cubit<StoreState> {
  StoreCubit(this._realtimeRepository) : super(StoreState()) {
    _storeSub = _realtimeRepository.storeController.listen((storeData) {
      AppLogger.d('🏪 StoreCubit: Loja recebida — ${storeData.name}');
      emit(StoreState(store: storeData));

      // ✅ Configura timer para atualizar quando pausa expirar
      _setupPauseExpirationTimer(storeData);

      // ✅ SEO: Atualiza título e descrição da página
      if (kIsWeb) {
        SeoHelper.updateStoreSeo(
          storeName: storeData.name,
          storeDescription: storeData.description,
          storeImageUrl: storeData.image?.url,
        );
      }

      // ✅ Inicializa tipo de entrega padrão
      try {
        getIt<DeliveryFeeCubit>().initializeWithStore(storeData);
      } catch (_) {
        // Ignora se não conseguir inicializar (pode não estar disponível ainda)
      }
    });
  }

  late final StreamSubscription<Store> _storeSub;
  Timer? _pauseExpirationTimer;

  final RealtimeRepository _realtimeRepository;

  /// Configura timer para atualizar automaticamente quando a pausa expirar
  void _setupPauseExpirationTimer(Store store) {
    _pauseExpirationTimer?.cancel();

    final pausedUntil = store.store_operation_config?.pausedUntil;

    if (pausedUntil != null && pausedUntil.isAfter(DateTime.now())) {
      final duration = pausedUntil.difference(DateTime.now());

      AppLogger.d(
        '⏰ StoreCubit: Pausa ativa. Timer para ${duration.inMinutes}min ${duration.inSeconds % 60}s',
      );

      _pauseExpirationTimer = Timer(duration + const Duration(seconds: 2), () {
        AppLogger.d('⏰ StoreCubit: Pausa expirou! Atualizando estado...');

        if (state.store != null) {
          final updatedConfig = state.store!.store_operation_config?.copyWith(
            isStoreOpen: true,
            pausedUntil: null,
          );
          final updatedStore = state.store!.copyWith(
            store_operation_config: updatedConfig,
          );
          emit(StoreState(store: updatedStore));
          AppLogger.d('✅ StoreCubit: Loja agora está ABERTA!');
        }
      });
    }
  }

  @override
  Future<void> close() {
    _pauseExpirationTimer?.cancel();
    _storeSub.cancel();
    return super.close();
  }
}
