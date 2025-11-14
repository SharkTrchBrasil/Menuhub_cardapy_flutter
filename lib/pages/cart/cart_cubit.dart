// Em: lib/cubits/cart/cart_cubit.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:totem/models/cart.dart';
import 'package:totem/models/update_cart_payload.dart';
import 'package:totem/repositories/realtime_repository.dart';
import '../../models/product.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  final RealtimeRepository _realtimeRepository;
  StreamSubscription<List<Product>>? _productSubscription;

  CartCubit(this._realtimeRepository) : super(CartState.initial()) {
    fetchCart();
    _listenToProductUpdates();
  }

  void _listenToProductUpdates() {
    // Cancela a inscrição anterior para evitar duplicatas
    _productSubscription?.cancel();
    // Inicia a "escuta" das atualizações de produtos
    _productSubscription = _realtimeRepository.productsController.stream.listen(_onProductsUpdated);
  }

  void _onProductsUpdated(List<Product> updatedProducts) {
    if (state.status != CartStatus.success || state.cart.isEmpty) {
      return;
    }

    final productIdsInCart = state.cart.items.map((item) => item.product.id).toSet();
    final bool isCartAffected = updatedProducts.any((updatedProduct) => productIdsInCart.contains(updatedProduct.id));

    if (isCartAffected) {
      print('🔄 Produtos no carrinho foram atualizados no servidor. Buscando carrinho atualizado...');
      fetchCart();
    }
  }

  @override
  Future<void> close() {
    _productSubscription?.cancel();
    return super.close();
  }

  Future<void> fetchCart() async {
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
    // Não emitimos 'loading' para a UI não piscar a cada item adicionado.
    emit(state.copyWith(isUpdating: true));
    try {
      print('🛒 [CartCubit] Atualizando item: productId=${payload.productId}, categoryId=${payload.categoryId}, quantity=${payload.quantity}');
      print('   Variants: ${payload.variants?.length ?? 0}');
      print('   Note: ${payload.note ?? "sem observação"}');
      
      final updatedCart = await _realtimeRepository.updateCartItem(payload);
      print('✅ [CartCubit] Item atualizado com sucesso. Carrinho tem ${updatedCart.items.length} itens.');
      emit(state.copyWith(status: CartStatus.success, cart: updatedCart, isUpdating: false));
    } catch (e, stackTrace) {
      print("❌ [CartCubit] Erro ao atualizar item: $e");
      print("   Stack trace: $stackTrace");
      // Re-busca o carrinho para garantir consistência após um erro.
      await fetchCart();
      // Finalmente, remove o estado de 'isUpdating'
      emit(state.copyWith(isUpdating: false));
      // Re-lança o erro para a UI poder mostrá-lo (ex: com um SnackBar)
      throw Exception('Erro interno ao atualizar item: ${e.toString()}');
    }
  }

  Future<void> clearCart() async {
    emit(state.copyWith(isUpdating: true));
    try {
      final updatedCart = await _realtimeRepository.clearCart();
      emit(state.copyWith(status: CartStatus.success, cart: updatedCart, isUpdating: false));
    } catch (e) {
      print("Erro ao limpar carrinho: $e");
      emit(state.copyWith(isUpdating: false));
    }
  }

  Future<void> applyCoupon(String code) async {
    try {
      final updatedCart = await _realtimeRepository.applyCoupon(code);
      emit(state.copyWith(cart: updatedCart));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeCoupon() async {
    try {
      final updatedCart = await _realtimeRepository.removeCoupon();
      emit(state.copyWith(cart: updatedCart));
    } catch (e) {
      rethrow;
    }
  }
}