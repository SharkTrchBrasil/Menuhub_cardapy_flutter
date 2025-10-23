import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/store.dart';
import 'package:totem/pages/splash/splash_page_state.dart';
import 'package:totem/repositories/auth_repository.dart';
import 'package:totem/repositories/realtime_repository.dart';

import '../../models/totem_auth.dart';

class SplashPageCubit extends Cubit<SplashPageState> {

  final RealtimeRepository _realtimeRepository;
  final AuthRepository _authRepository;

  SplashPageCubit()
      : _realtimeRepository = GetIt.I<RealtimeRepository>(),
        _authRepository = GetIt.I<AuthRepository>(),
        super(SplashPageState());

  // ▼▼▼ ALTERE A ASSINATURA DESTE MÉTODO ▼▼▼
  Future<void> initialize(TotemAuth auth) async {
    emit(SplashPageState(loading: true));

    // USA O TOKEN RECEBIDO DIRETAMENTE! Não precisa mais chamar o repositório aqui.
    _realtimeRepository.initialize(auth.token);
    final results = await Future.wait([
      _realtimeRepository.productsController.first,
      _realtimeRepository.storeController.first
    ]);

    final products = results[0] as List<Product>;
    final store = results[1] as Store;

    emit(SplashPageState(loading: false, products: products, store: store));
  }
}
