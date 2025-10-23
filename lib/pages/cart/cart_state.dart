// Em: lib/cubits/cart/cart_state.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/cart.dart'; // ✅ Importamos nosso novo modelo de carrinho!

// Um enum para controlar o estado da UI de forma clara
enum CartStatus { initial, loading, success, error }

class CartState extends Equatable {
  const CartState({
    required this.status,
    this.isUpdating = false,
    required this.cart,
    this.errorMessage,
  });

  final CartStatus status;
  final Cart cart; // ✅ A única fonte da verdade sobre os dados do carrinho
  final String? errorMessage;
  final bool isUpdating;

  // Estado inicial, com um carrinho vazio.
  factory CartState.initial() {
    return const CartState(
      status: CartStatus.initial,
      isUpdating: false,
      cart: Cart.empty(), // Usamos o construtor vazio que criamos no modelo
    );
  }

  CartState copyWith({
    CartStatus? status,
    bool? isUpdating,
    Cart? cart,
    String? errorMessage,
  }) {
    return CartState(
      status: status ?? this.status,
      isUpdating: isUpdating ?? this.isUpdating,
      cart: cart ?? this.cart,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, cart, isUpdating, errorMessage];
}