// Em: lib/cubits/cart/cart_cubit.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:totem/models/cart.dart';
import 'package:totem/models/update_cart_payload.dart';
import 'package:totem/repositories/realtime_repository.dart';

import 'package:totem/core/utils/app_logger.dart';
import 'package:totem/core/exceptions/app_exception.dart';
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
      AppLogger.info('Produtos no carrinho atualizados. Sincronizando...', tag: 'CART');
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

  /// ✅ ATUALIZADO: Usa modo granular para economizar banda.
  /// Atualiza apenas o item modificado localmente em vez de receber o carrinho todo.
  Future<void> updateItem(UpdateCartItemPayload payload) async {
    // Não emitimos 'loading' para a UI não piscar a cada item adicionado.
    emit(state.copyWith(isUpdating: true));
    try {
      AppLogger.debug(
        'Atualizando item: productId=${payload.productId}, qty=${payload.quantity}',
        tag: 'CART',
      );
      
      // ✅ NOVO: Tenta usar modo granular primeiro
      try {
        final response = await _realtimeRepository.updateCartItemGranular(payload);
        AppLogger.success(
          'Item atualizado (granular). Action: ${response.action}, Total: ${response.cartItemsCount} itens',
          tag: 'CART',
        );
        
        // Atualiza o estado localmente baseado na ação
        final currentCart = state.cart;
        Cart updatedCart;
        
        switch (response.action) {
          case 'removed':
            // Remove o item da lista local
            updatedCart = currentCart.copyWith(
              items: currentCart.items.where((i) => i.id != response.removedItemId).toList(),
              subtotal: response.cartSubtotal,
              discount: response.cartDiscount,
              total: response.cartTotal,
            );
            break;
            
          case 'added':
            // Adiciona o novo item à lista local
            if (response.item != null) {
              updatedCart = currentCart.copyWith(
                items: [...currentCart.items, response.item!],
                subtotal: response.cartSubtotal,
                discount: response.cartDiscount,
                total: response.cartTotal,
              );
            } else {
              updatedCart = currentCart.copyWith(
                subtotal: response.cartSubtotal,
                discount: response.cartDiscount,
                total: response.cartTotal,
              );
            }
            break;
            
          case 'quantity_changed':
          case 'updated':
          default:
            // Atualiza o item existente na lista local
            if (response.item != null) {
              final updatedItems = currentCart.items.map((item) {
                if (item.id == response.item!.id) {
                  return response.item!;
                }
                return item;
              }).toList();
              
              updatedCart = currentCart.copyWith(
                items: updatedItems,
                subtotal: response.cartSubtotal,
                discount: response.cartDiscount,
                total: response.cartTotal,
              );
            } else {
              updatedCart = currentCart.copyWith(
                subtotal: response.cartSubtotal,
                discount: response.cartDiscount,
                total: response.cartTotal,
              );
            }
        }
        
        emit(state.copyWith(status: CartStatus.success, cart: updatedCart, isUpdating: false));
        return;
        
      } on CartGranularFallbackException catch (e) {
        // Fallback: backend retornou carrinho completo (versão antiga)
        AppLogger.warning('Fallback: usando carrinho completo (backend antigo)', tag: 'CART');
        emit(state.copyWith(status: CartStatus.success, cart: e.cart, isUpdating: false));
        return;
      }
      
    } on NetworkException catch (e) {
      AppLogger.error('Erro de rede ao atualizar item', error: e, tag: 'CART');
      await fetchCart();
      emit(state.copyWith(isUpdating: false));
      throw CartException('Erro de conexão. Verifique sua internet.');
    } on ServerException catch (e) {
      AppLogger.error('Erro do servidor ao atualizar item', error: e, tag: 'CART');
      await fetchCart();
      emit(state.copyWith(isUpdating: false));
      throw CartException(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Erro ao atualizar item', error: e, stackTrace: stackTrace, tag: 'CART');
      await fetchCart();
      emit(state.copyWith(isUpdating: false));
      throw CartException('Erro ao atualizar carrinho. Tente novamente.');
    }
  }

  Future<void> clearCart() async {
    // ✅ OPTIMISTIC CLEAR: Limpa estado local imediatamente
    // Isso garante que a UI reflita carrinho vazio assim que o pedido é confirmado
    final emptyCart = state.cart.copyWith(
      items: [],
      subtotal: 0,
      discount: 0,
      total: 0,
      couponCode: null, // Limpa cupom também
    );
    
    // Atualiza estado
    emit(state.copyWith(
      status: CartStatus.success, 
      cart: emptyCart, 
      isUpdating: true
    ));

    try {
      final updatedCart = await _realtimeRepository.clearCart();
      AppLogger.success('Carrinho limpo no backend', tag: 'CART');
      // Confirma com o estado real do backend (que deve ser vazio também)
      emit(state.copyWith(status: CartStatus.success, cart: updatedCart, isUpdating: false));
    } catch (e) {
      AppLogger.error('Erro ao limpar carrinho no backend', error: e, tag: 'CART');
      // Mesmo com erro no backend, mantemos limpo localmente pois o pedido foi feito
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