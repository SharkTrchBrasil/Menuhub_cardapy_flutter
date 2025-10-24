// pages/splash/splash_page_state.dart
import 'package:totem/models/product.dart';
import 'package:totem/models/store.dart';

class SplashPageState {
  SplashPageState({
    this.loading = false,
    this.products,
    this.store,
    this.error,
  });

  final bool loading;
  final List<Product>? products;
  final Store? store;
  final String? error; // ✅ Adicionado campo de erro
}