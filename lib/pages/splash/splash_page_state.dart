import 'package:totem/models/product.dart';
import 'package:totem/models/store.dart';

class SplashPageState {

  SplashPageState({
    this.loading = false,
    this.products,
    this.store,
  });

  final bool loading;
  final List<Product>? products;
  final Store? store;

}