// Em: lib/cubits/cart/cart_cubit.dart

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:totem/models/cart.dart'; // ✅ Importa o novo Cart
import 'package:totem/models/update_cart_payload.dart'; // ✅ Importa o payload
import 'package:totem/repositories/realtime_repository.dart';
import '../../models/product.dart';
import 'cart_state.dart';
class CartCubit extends Cubit<CartState> {
  final RealtimeRepository _realtimeRepository;
  late final StreamSubscription<List<Product>> _productSubscription;

  CartCubit(this._realtimeRepository) : super(CartState.initial()) {
    fetchCart();

    // Inicia a "escuta" das atualizações de produtos
    _productSubscription = _realtimeRepository.productsController.stream.listen(_onProductsUpdated);
  }

  /// ✅ ESTA É A NOVA LÓGICA DE ATUALIZAÇÃO EM TEMPO REAL
  void _onProductsUpdated(List<Product> updatedProducts) {
    // Só processa se o carrinho já estiver carregado e não estiver vazio
    if (state.status != CartStatus.success || state.cart.isEmpty) {
      return;
    }

    bool isCartAffected = false;
    // Pega os IDs de todos os produtos que estão atualmente no carrinho
    final productIdsInCart = state.cart.items.map((item) => item.product.id).toSet();

    // Verifica se algum dos produtos atualizados está no nosso carrinho
    for (final updatedProduct in updatedProducts) {
      if (productIdsInCart.contains(updatedProduct.id)) {
        isCartAffected = true;
        break; // Encontramos uma correspondência, não precisa continuar
      }
    }

    // Se o carrinho foi afetado por uma mudança, busca a versão mais recente do backend
    if (isCartAffected) {
      print('🔄 Produtos no carrinho foram atualizados no servidor. Buscando carrinho atualizado...');
      fetchCart();
      // Opcional: você poderia emitir um estado aqui para mostrar uma notificação
      // na UI, como "Os preços no seu carrinho foram atualizados".
    }
  }

  @override
  Future<void> close() {
    _productSubscription.cancel(); // Cancela a inscrição para evitar vazamentos de memória
    return super.close();
  }

  /// Busca o estado mais recente do carrinho no servidor.
  Future<void> fetchCart() async {
    // Evita múltiplas chamadas se já estiver carregando
    if (state.status == CartStatus.loading) return;

    emit(state.copyWith(status: CartStatus.loading));
    try {
      final cart = await _realtimeRepository.getOrCreateCart();
      emit(state.copyWith(status: CartStatus.success, cart: cart));
    } catch (e) {
      emit(state.copyWith(status: CartStatus.error, errorMessage: e.toString()));
    }
  }


  Future<void> updateItem(UpdateCartItemPayload payload) async {
    emit(state.copyWith(isUpdating: true));
    try {
      // Não emitimos 'loading' aqui para a UI não piscar a cada item adicionado.
      final updatedCart = await _realtimeRepository.updateCartItem(payload);
      // O backend retorna o carrinho inteiro e atualizado. Nós apenas o exibimos.
      emit(state.copyWith(status: CartStatus.success, cart: updatedCart,  isUpdating: false,));
    } catch (e) {
      // Idealmente, mostre um SnackBar ou Toast com o erro.
      print("Erro ao atualizar item: $e");
      emit(state.copyWith(isUpdating: false));
      // Você pode querer re-buscar o carrinho para garantir consistência.
      fetchCart();
    }
  }

  Future<void> clearCart() async {
    try {
      final updatedCart = await _realtimeRepository.clearCart();
      emit(state.copyWith(status: CartStatus.success, cart: updatedCart));
    } catch (e) {
      print("Erro ao limpar carrinho: $e");
    }
  }



  Future<void> applyCoupon(String code) async {
    // Poderíamos ter um estado de loading específico para o cupom, se desejado
    try {
      final updatedCart = await _realtimeRepository.applyCoupon(code);
      emit(state.copyWith(cart: updatedCart));
    } catch (e) {
      // Re-lança o erro para a UI poder pegá-lo e mostrar um SnackBar
      throw e;
    }
  }

  Future<void> removeCoupon() async {
    try {
      final updatedCart = await _realtimeRepository.removeCoupon();
      emit(state.copyWith(cart: updatedCart));
    } catch (e) {
      throw e;
    }
  }

}