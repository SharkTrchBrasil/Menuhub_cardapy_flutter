// No seu StoreCubit
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/product.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/repositories/realtime_repository.dart';

import '../models/banners.dart';
import '../models/store.dart';
import '../models/rating_summary.dart'; // Importe RatingsSummary

class StoreCubit extends Cubit<StoreState> {
  StoreCubit(this._realtimeRepository) : super(StoreState()) {
    _subscription = _realtimeRepository.productsController.listen((products) {
      emit(state.copyWith(products: products));

      if(state.selectedCategory == null && state.categories.isNotEmpty ||
          !state.categories.contains(state.selectedCategory)) {
        emit(state.copyWith(selectedCategory: state.categories.first));
      }
    });

    _storeSub = _realtimeRepository.storeController.listen((storeData) {
      emit(state.copyWith(store: storeData));
    });

    _bannersSub = _realtimeRepository.bannersController.listen((banners) {
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