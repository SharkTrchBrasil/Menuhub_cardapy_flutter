// Em: lib/pages/product/product_page_state.dart

import 'package:equatable/equatable.dart';
import 'package:totem/models/cart_product.dart';
import 'package:totem/models/page_status.dart'; // Seu arquivo PageStatus

class ProductPageState extends Equatable {
  final PageStatus status;
  final CartProduct? product;
  final bool isEditMode;
  final int? originalCartItemId;

  const ProductPageState({
    required this.status,
    this.product,
    this.isEditMode = false,
    this.originalCartItemId,
  });

  // O construtor 'factory' cria nosso estado inicial padrão
  factory ProductPageState.initial() {
    return ProductPageState(
      // ✅ CORREÇÃO: Usa seu estado 'Idle' como o estado inicial.
      status: PageStatusIdle(),
      product: null,
      isEditMode: false,
    );
  }

  ProductPageState copyWith({
    PageStatus? status,
    CartProduct? product,
    bool? isEditMode,
    int? originalCartItemId, // ✅
  }) {
    return ProductPageState(
      status: status ?? this.status,
      product: product ?? this.product,
      isEditMode: isEditMode ?? this.isEditMode,
      originalCartItemId: originalCartItemId ?? this.originalCartItemId,
    );
  }

  @override
  List<Object?> get props => [status, product, isEditMode,  originalCartItemId];
}