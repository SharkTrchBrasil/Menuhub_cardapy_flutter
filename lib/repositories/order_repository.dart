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
      final response = await _dio.get('/customer/orders/$orderId');
      return Right(Order.fromJson(response.data));
    } on DioException catch (e) {
      return Left(e.response?.data['detail'] ?? 'Erro ao buscar pedido');
    }
  }

  Future<Either<String, Order>> getOrderById(int orderId) async {
    try {
      final response = await _dio.get('/customer/orders/$orderId');
      return Right(Order.fromJson(response.data));
    } on DioException catch (e) {
      return Left(e.response?.data['detail'] ?? 'Erro ao buscar pedido');
    }
  }

  Future<Either<String, void>> submitOrderReview({
    required String orderPublicId,
    required int stars,
    String? comment,
    List<String>? positiveTags,
  }) async {
    try {
      await _dio.post(
        '/reviews/order/$orderPublicId',
        data: {
          'stars': stars,
          'comment': comment,
          'positive_tags': positiveTags,
        },
      );
      return Right(null);
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['detail'] ?? 'Erro ao enviar avaliação';
      return Left(errorMessage);
    } catch (e) {
      return Left('Erro inesperado: $e');
    }
  }

  Future<Either<String, void>> submitDeliveryReview({
    required String orderPublicId,
    required bool likedDelivery,
    List<String>? negativeTags,
    String? comment,
  }) async {
    try {
      await _dio.post(
        '/reviews/order/$orderPublicId/delivery',
        data: {
          'liked_delivery': likedDelivery,
          'negative_tags': negativeTags,
          'comment': comment,
        },
      );
      return Right(null);
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['detail'] ?? 'Erro ao enviar avaliação da entrega';
      return Left(errorMessage);
    } catch (e) {
      return Left('Erro inesperado: $e');
    }
  }

  /// ✅ Cancela um pedido
  Future<Either<String, void>> cancelOrder({
    required int orderId,
    String? reason,
  }) async {
    try {
      await _dio.post(
        '/customer/orders/$orderId/cancel',
        data: reason ?? 'Cancelado pelo cliente',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return Right(null);
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['detail'] ??
          e.response?.data['message'] ??
          'Erro ao cancelar pedido';
      return Left(errorMessage);
    } catch (e) {
      return Left('Erro inesperado: $e');
    }
  }

  /// ✅ Obtém lista de pedidos do cliente
  Future<Either<String, List<Order>>> getCustomerOrders(int customerId) async {
    try {
      final response = await _dio.get('/customer/$customerId/orders');
      final data = response.data as List;
      final orders = data.map((json) => Order.fromJson(json)).toList();
      return Right(orders);
    } on DioException catch (e) {
      return Left(
        e.response?.data['detail'] ?? 'Erro ao buscar histórico de pedidos',
      );
    } catch (e) {
      return Left('Erro inesperado: $e');
    }
  }
}
