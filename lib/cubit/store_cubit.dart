// No seu StoreCubit
import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/repositories/realtime_repository.dart';
import 'package:totem/core/utils/app_logger.dart';
import 'package:totem/utils/seo_helper.dart';

import '../models/banners.dart';
import '../models/store.dart';
import '../core/di.dart';
import '../pages/address/cubits/delivery_fee_cubit.dart';

class StoreCubit extends Cubit<StoreState> {
  StoreCubit(this._realtimeRepository) : super(StoreState()) {
    _subscription = _realtimeRepository.productsController.listen((products) {

      emit(state.copyWith(products: products));


      // ✅ CORREÇÃO: Seleciona categoria padrão baseado nas categorias da loja
      if (state.selectedCategory == null && state.categories.isNotEmpty) {
        AppLogger.d('⚙️ Selecionando categoria padrão: ${state.categories.first.name}');
        emit(state.copyWith(selectedCategory: state.categories.first));
      }
    });

    _storeSub = _realtimeRepository.storeController.listen((storeData) {
      AppLogger.d('🏪 StoreCubit: Loja recebida');
      AppLogger.d('   ├─ Nome: ${storeData.name}');
      AppLogger.d('   ├─ Categorias: ${storeData.categories.length}');
      for (var cat in storeData.categories) {
        AppLogger.d('      └─ ${cat.name} (ID: ${cat.id})');
      }

      emit(state.copyWith(store: storeData));
      
      // ✅ NOVO: Configura timer para atualizar quando pausa expirar
      _setupPauseExpirationTimer(storeData);

      // ✅ SEO: Atualiza título e descrição da página com dados da loja
      if (kIsWeb) {
        SeoHelper.updateStoreSeo(
          storeName: storeData.name,
          storeDescription: storeData.description,
          storeImageUrl: storeData.image?.url,
        );
        AppLogger.d('🔍 SEO: Título atualizado para "${storeData.name}"');
      }

      AppLogger.d('📊 Estado após atualizar loja:');
      AppLogger.d('   ├─ state.store != null: ${state.store != null}');
      AppLogger.d('   ├─ state.categories.length: ${state.categories.length}');
      AppLogger.d('   └─ state.selectedCategory: ${state.selectedCategory?.name}');

      // ✅ ADICIONE: Quando a loja carregar, seleciona a primeira categoria
      if (state.selectedCategory == null && storeData.categories.isNotEmpty) {
        AppLogger.d('⚙️ Selecionando categoria padrão da loja: ${storeData.categories.first.name}');
        emit(state.copyWith(selectedCategory: storeData.categories.first));
      }

      // ✅ INICIALIZA TIPO DE ENTREGA PADRÃO
      try {
        getIt<DeliveryFeeCubit>().initializeWithStore(storeData);
      } catch (_) {
        // Ignora se não conseguir inicializar (pode não estar disponível ainda)
      }
    });

    _bannersSub = _realtimeRepository.bannersController.listen((banners) {
      AppLogger.d('🎨 StoreCubit: Banners recebidos: ${banners.length}');
      emit(state.copyWith(banners: banners));
    });
  }

  late final StreamSubscription<List<BannerModel>> _bannersSub;
  late StreamSubscription<List<Product>> _subscription;
  late final StreamSubscription<Store> _storeSub;
  Timer? _pauseExpirationTimer; // ✅ Timer para expiração da pausa

  final RealtimeRepository _realtimeRepository;

  /// ✅ NOVO: Configura timer para atualizar automaticamente quando a pausa expirar
  void _setupPauseExpirationTimer(Store store) {
    _pauseExpirationTimer?.cancel();
    
    final pausedUntil = store.store_operation_config?.pausedUntil;
    
    if (pausedUntil != null && pausedUntil.isAfter(DateTime.now())) {
      final duration = pausedUntil.difference(DateTime.now());
      
      AppLogger.d('⏰ StoreCubit: Pausa ativa. Timer configurado para ${duration.inMinutes} min ${duration.inSeconds % 60}s');
      
      _pauseExpirationTimer = Timer(duration + const Duration(seconds: 2), () {
        AppLogger.d('⏰ StoreCubit: Pausa expirou! Forçando atualização do estado...');
        
        // ✅ Limpa o pausedUntil localmente e re-emite o estado
        if (state.store != null) {
          final updatedConfig = state.store!.store_operation_config?.copyWith(
            isStoreOpen: true,
            pausedUntil: null,
          );
          
          final updatedStore = state.store!.copyWith(
            store_operation_config: updatedConfig,
          );
          
          emit(state.copyWith(store: updatedStore));
          AppLogger.d('✅ StoreCubit: Estado atualizado - Loja agora está ABERTA!');
        }
      });
    }
  }

  void selectCategory(Category category) {
    emit(state.copyWith(selectedCategory: category));
  }

  @override
  Future<void> close() {
    _pauseExpirationTimer?.cancel(); // ✅ Cancela timer
    _storeSub.cancel();
    _subscription.cancel();
    _bannersSub.cancel();

    return super.close();
  }
}
