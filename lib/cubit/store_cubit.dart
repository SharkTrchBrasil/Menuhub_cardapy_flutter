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
        AppLogger.debug('⚙️ Selecionando categoria padrão: ${state.categories.first.name}');
        emit(state.copyWith(selectedCategory: state.categories.first));
      }
    });

    _storeSub = _realtimeRepository.storeController.listen((storeData) {
      AppLogger.debug('🏪 StoreCubit: Loja recebida');
      AppLogger.debug('   ├─ Nome: ${storeData.name}');
      AppLogger.debug('   ├─ Categorias: ${storeData.categories.length}');
      for (var cat in storeData.categories) {
        AppLogger.debug('      └─ ${cat.name} (ID: ${cat.id})');
      }

      emit(state.copyWith(store: storeData));

      // ✅ SEO: Atualiza título e descrição da página com dados da loja
      if (kIsWeb) {
        SeoHelper.updateStoreSeo(
          storeName: storeData.name,
          storeDescription: storeData.description,
          storeImageUrl: storeData.image?.url,
        );
        AppLogger.debug('🔍 SEO: Título atualizado para "${storeData.name}"');
      }

      AppLogger.debug('📊 Estado após atualizar loja:');
      AppLogger.debug('   ├─ state.store != null: ${state.store != null}');
      AppLogger.debug('   ├─ state.categories.length: ${state.categories.length}');
      AppLogger.debug('   └─ state.selectedCategory: ${state.selectedCategory?.name}');

      // ✅ ADICIONE: Quando a loja carregar, seleciona a primeira categoria
      if (state.selectedCategory == null && storeData.categories.isNotEmpty) {
        AppLogger.debug('⚙️ Selecionando categoria padrão da loja: ${storeData.categories.first.name}');
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
      AppLogger.debug('🎨 StoreCubit: Banners recebidos: ${banners.length}');
      emit(state.copyWith(banners: banners));
    });
  }

  late final StreamSubscription<List<BannerModel>> _bannersSub;
  late StreamSubscription<List<Product>> _subscription;
  late final StreamSubscription<Store> _storeSub;

  final RealtimeRepository _realtimeRepository;

  void selectCategory(Category category) {
    emit(state.copyWith(selectedCategory: category));
  }

  @override
  Future<void> close() {
    _storeSub.cancel();
    _subscription.cancel();
    _bannersSub.cancel();

    return super.close();
  }
}