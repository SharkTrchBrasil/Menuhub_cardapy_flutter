import 'package:totem/models/store.dart';

/// StoreState — contém apenas dados da LOJA (configs, horários, pagamentos, etc.)
/// O catálogo (categorias, produtos, banners, selectedCategory) agora fica no CatalogState.
class StoreState {
  StoreState({this.store});

  final Store? store;

  StoreState copyWith({Store? store}) {
    return StoreState(store: store ?? this.store);
  }
}
