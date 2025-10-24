// pages/splash/splash_page_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/store.dart';
import 'package:totem/pages/splash/splash_page_state.dart';
import 'package:totem/repositories/realtime_repository.dart';

class SplashPageCubit extends Cubit<SplashPageState> {
  final RealtimeRepository _realtimeRepository;

  SplashPageCubit()
      : _realtimeRepository = GetIt.I<RealtimeRepository>(),
        super(SplashPageState());

  // ✅ VERSÃO SIMPLIFICADA: Apenas aguarda os dados via Socket.IO
  Future<void> initialize() async {
    emit(SplashPageState(loading: true));

    try {
      // Aguarda os primeiros dados do Socket.IO
      final results = await Future.wait([
        _realtimeRepository.productsController.first,
        _realtimeRepository.storeController.first,
      ]);

      final products = results[0] as List<Product>;
      final store = results[1] as Store;

      emit(SplashPageState(
        loading: false,
        products: products,
        store: store,
      ));

      print('✅ Splash carregado: ${products.length} produtos, loja: ${store.name}');
    } catch (e) {
      print('❌ Erro ao carregar dados do splash: $e');
      emit(SplashPageState(loading: false, error: e.toString()));
    }
  }
}