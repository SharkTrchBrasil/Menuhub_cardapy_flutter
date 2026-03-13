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
  StreamSubscription<bool>? _socketReadySubscription;

  CartCubit(this._realtimeRepository) : super(CartState.initial()) {
    // ✅ CORREÇÃO: Não chama fetchCart() no construtor
    // Isso evita o erro "Usuário não autenticado" antes do login
    _listenToProductUpdates();
    _listenToSocketReady();
  }

  void _listenToProductUpdates() {
    // Cancela a inscrição anterior para evitar duplicatas
    _productSubscription?.cancel();
    // Inicia a "escuta" das atualizações de produtos
    _productSubscription = _realtimeRepository.productsController.stream.listen(
      _onProductsUpdated,
    );
  }

  /// ✅ CRITICAL FIX: Escuta quando Socket está pronto e tenta carregar carrinho
  /// se ainda não foi carregado (initial) ou estava em erro (ex: "Usuário não autenticado")
  void _listenToSocketReady() {
    _socketReadySubscription?.cancel();
    _socketReadySubscription = _realtimeRepository
        .isSocketReadyController
        .stream
        .listen((isReady) {
          // Tenta carregar se Socket pronto E (ainda não carregado OU em erro)
          final shouldFetch =
              isReady &&
              (state.status == CartStatus.initial ||
                  state.status == CartStatus.error);

          if (shouldFetch) {
            AppLogger.i(
              '🔄 [CartCubit] Socket pronto! Carregando carrinho (status: ${state.status})...',
              tag: 'CART',
            );
            fetchCart();
          }
        });
  }

  void _onProductsUpdated(List<Product> updatedProducts) {
    // ✅ CORREÇÃO: Se está em error, tenta recarregar o carrinho quando produtos atualizam
    if (state.status == CartStatus.error) {
      AppLogger.i(
        '🔄 [CartCubit] Recuperando de estado error após atualização de produtos',
        tag: 'CART',
      );
      fetchCart();
      return;
    }

    if (state.status != CartStatus.success || state.cart.isEmpty) {
      return;
    }

    final productIdsInCart =
        state.cart.items.map((item) => item.product.id).toSet();
    final bool isCartAffected = updatedProducts.any(
      (updatedProduct) => productIdsInCart.contains(updatedProduct.id),
    );

    if (isCartAffected) {
      AppLogger.i(
        'Produtos no carrinho atualizados. Sincronizando...',
        tag: 'CART',
      );
      fetchCart();
    }
  }

  @override
  Future<void> close() {
    _productSubscription?.cancel();
    _socketReadySubscription?.cancel();
    return super.close();
  }

  Future<void> fetchCart() async {
    if (state.status == CartStatus.loading) return;

    // ✅ CORREÇÃO: Se está em error, limpa o erro antes de tentar novamente
    final wasInErrorState = state.status == CartStatus.error;
    if (wasInErrorState) {
      AppLogger.i(
        '🔄 [CartCubit] Tentando recuperação de estado error',
        tag: 'CART',
      );
    }

    AppLogger.d('🛒 [CartCubit] Iniciando fetchCart...', tag: 'CART');
    emit(state.copyWith(status: CartStatus.loading, errorMessage: null));
    try {
      final cart = await _realtimeRepository.getOrCreateCart();
      AppLogger.i(
        '✅ [CartCubit] Carrinho carregado: ${cart.items.length} itens, total: R\$${(cart.total / 100).toStringAsFixed(2)}',
        tag: 'CART',
      );
      emit(state.copyWith(status: CartStatus.success, cart: cart));
    } catch (e) {
      AppLogger.e(
        '❌ [CartCubit] Erro ao carregar carrinho',
        error: e,
        tag: 'CART',
      );
      emit(
        state.copyWith(status: CartStatus.error, errorMessage: e.toString()),
      );
    }
  }

  void setOrderAgainProcessing(bool isProcessing) {
    emit(
      state.copyWith(
        isOrderAgainProcessing: isProcessing,
        orderAgainSnapshotCart: isProcessing ? state.cart : null,
        clearOrderAgainSnapshotCart: !isProcessing,
      ),
    );
  }

  /// ✅ ATUALIZADO: Usa modo granular para economizar banda.
  /// Atualiza apenas o item modificado localmente em vez de receber o carrinho todo.
  Future<void> updateItem(UpdateCartItemPayload payload) async {
    // Não emitimos 'loading' para a UI não piscar a cada item adicionado.
    emit(state.copyWith(isUpdating: true));
    try {
      AppLogger.d(
        'Atualizando item: productId=${payload.productId}, qty=${payload.quantity}',
        tag: 'CART',
      );

      // ✅ NOVO: Tenta usar modo granular primeiro
      try {
        final response = await _realtimeRepository.updateCartItemGranular(
          payload,
        );
        AppLogger.i(
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
              id: response.cartId,
              items:
                  currentCart.items
                      .where((i) => i.id != response.removedItemId)
                      .toList(),
              subtotal: response.cartSubtotal,
              discount: response.cartDiscount,
              total: response.cartTotal,
            );
            break;

          case 'added':
            // Adiciona o novo item à lista local
            if (response.item != null) {
              var newItem = response.item!;

              final shouldUseLocalVariants =
                  (payload.variants?.isNotEmpty ?? false) &&
                  (newItem.variants.isEmpty ||
                      newItem.variants.length != payload.variants!.length ||
                      newItem.variants.any(
                        (variant) =>
                            variant.options.isEmpty ||
                            variant.options.any((option) => option.price <= 0),
                      ));

              // ✅ ROBUSTEZ VISUAL: Se o backend retornou item sem variantes (comum em pizzas recém-criadas),
              // mas nós enviamos variantes, usamos as variantes do payload para garantir a exibição correta (borda, sabores).
              // Verifica se payload.variants não é nulo antes de acessar isNotEmpty
              if (shouldUseLocalVariants) {
                print(
                  "⚠️ [CartCubit] Backend retornou item sem variantes. Usando dados locais para exibição.",
                );
                newItem = newItem.copyWith(
                  variants: payload.variants,
                  // Tenta preservar outros dados se estarem zerados
                  sizeName: newItem.sizeName ?? payload.sizeName,
                  sizeImageUrl: newItem.sizeImageUrl ?? payload.sizeImageUrl,
                );
              } else if ((payload.sizeImageUrl?.isNotEmpty ?? false) &&
                  (newItem.sizeImageUrl == null ||
                      newItem.sizeImageUrl!.isEmpty)) {
                newItem = newItem.copyWith(sizeImageUrl: payload.sizeImageUrl);
              }

              updatedCart = currentCart.copyWith(
                id: response.cartId,
                items: [...currentCart.items, newItem],
                subtotal: response.cartSubtotal,
                discount: response.cartDiscount,
                total: response.cartTotal,
              );
            } else {
              updatedCart = currentCart.copyWith(
                id: response.cartId,
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
              final updatedItems =
                  currentCart.items.map((item) {
                    if (item.id == response.item!.id) {
                      return response.item!;
                    }
                    return item;
                  }).toList();

              updatedCart = currentCart.copyWith(
                id: response.cartId,
                items: updatedItems,
                subtotal: response.cartSubtotal,
                discount: response.cartDiscount,
                total: response.cartTotal,
              );
            } else {
              updatedCart = currentCart.copyWith(
                id: response.cartId,
                subtotal: response.cartSubtotal,
                discount: response.cartDiscount,
                total: response.cartTotal,
              );
            }
        }

        emit(
          state.copyWith(
            status: CartStatus.success,
            cart: updatedCart,
            isUpdating: false,
          ),
        );
        calculatePromotions();
        return;
      } on CartGranularFallbackException catch (e) {
        // Fallback: backend retornou carrinho completo (versão antiga)
        AppLogger.w(
          'Fallback: usando carrinho completo (backend antigo)',
          tag: 'CART',
        );
        emit(
          state.copyWith(
            status: CartStatus.success,
            cart: e.cart,
            isUpdating: false,
          ),
        );
        calculatePromotions();
        return;
      }
    } on NetworkException catch (e) {
      AppLogger.e('Erro de rede ao atualizar item', error: e, tag: 'CART');
      await fetchCart();
      emit(state.copyWith(isUpdating: false));
      throw CartException('Erro de conexão. Verifique sua internet.');
    } on ServerException catch (e) {
      AppLogger.e('Erro do servidor ao atualizar item', error: e, tag: 'CART');
      await fetchCart();
      emit(state.copyWith(isUpdating: false));
      throw CartException(e.message);
    } catch (e, stackTrace) {
      AppLogger.e(
        'Erro ao atualizar item',
        error: e,
        stackTrace: stackTrace,
        tag: 'CART',
      );
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
    emit(
      state.copyWith(
        status: CartStatus.success,
        cart: emptyCart,
        isUpdating: true,
      ),
    );

    try {
      final updatedCart = await _realtimeRepository.clearCart();
      AppLogger.i('Carrinho limpo no backend', tag: 'CART');
      // Confirma com o estado real do backend (que deve ser vazio também)
      emit(
        state.copyWith(
          status: CartStatus.success,
          cart: updatedCart,
          isUpdating: false,
        ),
      );
    } catch (e) {
      AppLogger.e('Erro ao limpar carrinho no backend', error: e, tag: 'CART');
      // Mesmo com erro no backend, mantemos limpo localmente pois o pedido foi feito
      emit(state.copyWith(isUpdating: false));
    }
  }

  void resetCartLocally() {
    emit(CartState.initial());
  }

  Future<void> applyCoupon(String code) async {
    try {
      final updatedCart = await _realtimeRepository.applyCoupon(code);
      AppLogger.i(
        'Cupom aplicado: ${updatedCart.couponCode}, desconto: ${updatedCart.discount}, frete grátis: ${updatedCart.isFreeDelivery}',
        tag: 'CART',
      );
      emit(state.copyWith(status: CartStatus.success, cart: updatedCart));

      // ✅ NOVO: Recalcula promoções após aplicar cupom para garantir que
      // outros descontos e regras de frete sejam atualizados.
      await calculatePromotions();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeCoupon() async {
    try {
      final updatedCart = await _realtimeRepository.removeCoupon();
      AppLogger.i(
        'Cupom removido. Backend retornou: couponCode=${updatedCart.couponCode}, desconto=${updatedCart.discount}, frete grátis=${updatedCart.isFreeDelivery}',
        tag: 'CART',
      );

      // ✅ CORREÇÃO: SEMPRE usa copyWithCouponRemoved para garantir que todos os campos
      // relacionados ao cupom sejam resetados, incluindo isFreeDelivery.
      // Isso é necessário porque o backend pode retornar isFreeDelivery: true incorretamente.
      final cartToEmit = updatedCart.copyWithCouponRemoved();

      emit(state.copyWith(status: CartStatus.success, cart: cartToEmit));

      // ✅ NOVO: Recalcula promoções após remover cupom.
      await calculatePromotions();
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ Calcula promoções (Frete Grátis, Descontos de Entrega, Vouchers Automáticos)
  Future<void> calculatePromotions() async {
    // Só calcula se tiver itens e não estiver carregando
    if (state.cart.isEmpty) return;

    try {
      final result = await _realtimeRepository.applyPromotions(
        subtotal: state.cart.subtotal,
        deliveryFee: state.cart.deliveryFee,
      );

      final updatedCart = state.cart.copyWith(
        discount: result['total_order_discount'] as int,
        deliveryDiscount: result['total_delivery_discount'] as int,
        finalDeliveryFee: result['final_delivery_fee'] as int,
        promotionMessage: result['message'] as String?,
        total: result['final_total'] as int,
      );

      emit(state.copyWith(cart: updatedCart));
    } catch (e) {
      // Falha silenciosa na UI, apenas loga
      AppLogger.e('Erro ao atualizar promoções', error: e, tag: 'CART');
    }
  }
}
