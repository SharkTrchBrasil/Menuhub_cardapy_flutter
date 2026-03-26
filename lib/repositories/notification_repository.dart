// lib/repositories/notification_repository.dart

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart';
import 'package:totem/models/notification.dart';
import '../core/session/in_memory_session_store.dart';

class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  /// ✅ STATELESS: Obtém store_id da memória (não do localStorage)
  int? _getStoreId() {
    return InMemorySessionStore.instance.storeId;
  }

  /// Obtém Dio configurado para a área admin
  Dio _getAdminDio() {
    // Remove '/app' da base URL para usar admin
    final baseUrl = _dio.options.baseUrl.replaceAll('/app', '/admin');
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers:
            _dio.options.headers, // Mantém headers (incluindo Authorization)
      ),
    );
  }

  /// ✅ Busca todas as notificações para a loja
  Future<Either<String, NotificationListResponse>> getNotifications({
    bool includeRead = false,
    int limit = 50,
  }) async {
    try {
      final storeId = _getStoreId();
      if (storeId == null) {
        return const Left('Store ID não encontrado');
      }

      final adminDio = _getAdminDio();

      final response = await adminDio.get(
        '/stores/$storeId/notifications',
        queryParameters: {'include_read': includeRead, 'limit': limit},
      );

      final data = NotificationListResponse.fromJson(response.data);
      return Right(data);
    } on DioException catch (e) {
      debugPrint('Erro ao buscar notificações: $e');
      final errorMessage =
          e.response?.data?['detail'] ?? 'Erro ao buscar notificações';
      return Left(errorMessage);
    } catch (e) {
      debugPrint('Erro inesperado ao buscar notificações: $e');
      return Left('Erro inesperado ao buscar notificações');
    }
  }

  /// ✅ Busca contagem de notificações não lidas
  Future<Either<String, NotificationCountResponse>>
  getNotificationCount() async {
    try {
      final storeId = _getStoreId();
      if (storeId == null) {
        return const Left('Store ID não encontrado');
      }

      final adminDio = _getAdminDio();

      final response = await adminDio.get(
        '/stores/$storeId/notifications/count',
      );

      final data = NotificationCountResponse.fromJson(response.data);
      return Right(data);
    } on DioException catch (e) {
      debugPrint('Erro ao buscar contagem de notificações: $e');
      final errorMessage =
          e.response?.data?['detail'] ?? 'Erro ao buscar contagem';
      return Left(errorMessage);
    } catch (e) {
      debugPrint('Erro inesperado ao buscar contagem: $e');
      return Left('Erro inesperado ao buscar contagem');
    }
  }

  /// ✅ Marca uma notificação como lida
  Future<Either<String, void>> markAsRead(String notificationId) async {
    try {
      final storeId = _getStoreId();
      if (storeId == null) {
        return const Left('Store ID não encontrado');
      }

      final adminDio = _getAdminDio();

      await adminDio.post(
        '/stores/$storeId/notifications/read',
        data: {'notification_id': notificationId},
      );

      return const Right(null);
    } on DioException catch (e) {
      debugPrint('Erro ao marcar notificação como lida: $e');
      final errorMessage =
          e.response?.data?['detail'] ?? 'Erro ao marcar como lida';
      return Left(errorMessage);
    } catch (e) {
      debugPrint('Erro inesperado ao marcar como lida: $e');
      return Left('Erro inesperado ao marcar como lida');
    }
  }
}
