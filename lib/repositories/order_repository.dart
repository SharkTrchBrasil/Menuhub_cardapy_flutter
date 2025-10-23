// lib/repositories/order_repository.dart (CRIAR SE NÃO EXISTIR)

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import '../models/order.dart';
import '../models/cart.dart';

class OrderRepository {
  final Dio _dio;

  OrderRepository(this._dio);

  Future<Either<String, Order>> createOrder({
    required Cart cart,
    required String paymentMethod,
    String? deliveryAddress,
    String? customerNote,
  }) async {
    try {
      final response = await _dio.post(
        '/orders',
        data: {
          'items': cart.items.map((item) => item.toJson()).toList(),
          'payment_method': paymentMethod,
          'delivery_address': deliveryAddress,
          'customer_note': customerNote,
          'subtotal': cart.subtotal,
          'total': cart.total,
        },
      );

      final order = Order.fromJson(response.data);
      return Right(order);
    } on DioException catch (e) {
      final errorMessage = e.response?.data['detail'] ?? 'Erro ao criar pedido';
      return Left(errorMessage);
    } catch (e) {
      return Left('Erro inesperado: $e');
    }
  }

  Future<Either<String, Order>> getOrderStatus(int orderId) async {
    try {
      final response = await _dio.get('/orders/$orderId');
      return Right(Order.fromJson(response.data));
    } on DioException catch (e) {
      return Left(e.response?.data['detail'] ?? 'Erro ao buscar pedido');
    }
  }
}