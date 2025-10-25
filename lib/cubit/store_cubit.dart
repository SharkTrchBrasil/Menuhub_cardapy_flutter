// No seu StoreCubit
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/repositories/realtime_repository.dart';

import '../models/banners.dart';
import '../models/store.dart';
import '../models/rating_summary.dart';

class StoreCubit extends Cubit<StoreState> {
  StoreCubit(this._realtimeRepository) : super(StoreState()) {
    _subscription = _realtimeRepository.productsController.listen((products) {

      emit(state.copyWith(products: products));


      // ✅ CORREÇÃO: Seleciona categoria padrão baseado nas categorias da loja
      if (state.selectedCategory == null && state.categories.isNotEmpty) {
        print('⚙️ Selecionando categoria padrão: ${state.categories.first.name}');
        emit(state.copyWith(selectedCategory: state.categories.first));
      }
    });

    _storeSub = _realtimeRepository.storeController.listen((storeData) {
      print('🏪 StoreCubit: Loja recebida');
      print('   ├─ Nome: ${storeData.name}');
      print('   ├─ Categorias: ${storeData.categories.length}');
      for (var cat in storeData.categories) {
        print('      └─ ${cat.name} (ID: ${cat.id})');
      }

      emit(state.copyWith(store: storeData));

      print('📊 Estado após atualizar loja:');
      print('   ├─ state.store != null: ${state.store != null}');
      print('   ├─ state.categories.length: ${state.categories.length}');
      print('   └─ state.selectedCategory: ${state.selectedCategory?.name}');

      // ✅ ADICIONE: Quando a loja carregar, seleciona a primeira categoria
      if (state.selectedCategory == null && storeData.categories.isNotEmpty) {
        print('⚙️ Selecionando categoria padrão da loja: ${storeData.categories.first.name}');
        emit(state.copyWith(selectedCategory: storeData.categories.first));
      }
    });

    _bannersSub = _realtimeRepository.bannersController.listen((banners) {
      print('🎨 StoreCubit: Banners recebidos: ${banners.length}');
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