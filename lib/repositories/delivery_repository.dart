import 'package:dio/dio.dart';
import 'package:totem/models/customer_address.dart';

class DeliveryFeeRepository {
  final Dio _dio;

  DeliveryFeeRepository(this._dio);

  /// Calcula o frete usando o novo sistema (por km)
  Future<Map<String, dynamic>?> calculateDeliveryFee({
    int? addressId,
    double? latitude,
    double? longitude,
    int subtotal = 0, // Em centavos
  }) async {
    try {
      final response = await _dio.post(
        '/delivery-fee/calculate',
        data: {
          if (addressId != null) 'address_id': addressId,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'subtotal': subtotal,
        },
      );

      final data = response.data as Map<String, dynamic>;
      
      // ✅ ENTERPRISE: Validação robusta do response
      if (data.containsKey('error')) {
        return {
          'error': data['error'] as String? ?? 'Erro ao calcular frete',
          'fee': 0,
          'distance_km': null,
          'rule_type': null,
          'eligible_for_free_delivery': false,
        };
      }
      
      // ✅ CONVERSÃO: Converte fee de centavos para reais (já vem em centavos do backend)
      final feeValue = data['fee'];
      double feeInReais = 0.0;
      
      if (feeValue != null) {
        if (feeValue is int) {
          feeInReais = feeValue / 100.0;
        } else if (feeValue is double) {
          // Se já vier em reais (backward compatibility)
          feeInReais = feeValue;
        } else if (feeValue is num) {
          feeInReais = feeValue.toDouble() / 100.0;
        }
      }
      
      // ✅ VALIDAÇÃO: Garante que fee não é negativo
      if (feeInReais < 0) {
        feeInReais = 0.0;
      }
      
      return {
        'fee': feeInReais,
        'distance_km': (data['distance_km'] as num?)?.toDouble(),
        'rule_type': data['rule_type'] as String?,
        'eligible_for_free_delivery': data['eligible_for_free_delivery'] as bool? ?? false,
        'error': data['error'] as String?,
      };
    } on DioException catch (e) {
      // ✅ TRATAMENTO DE ERRO: Loga detalhes do erro
      print('❌ Erro DioException ao calcular frete: ${e.message}');
      print('📍 Status: ${e.response?.statusCode}');
      print('📍 Data: ${e.response?.data}');
      
      // ✅ RETORNA ERRO ESTRUTURADO
      return {
        'error': e.response?.data?['detail'] as String? ?? 'Erro ao calcular frete',
        'fee': 0,
        'distance_km': null,
        'rule_type': null,
        'eligible_for_free_delivery': false,
      };
    } catch (e, stackTrace) {
      // ✅ TRATAMENTO DE EXCEÇÃO: Loga stack trace para debug
      print('❌ Erro inesperado ao calcular frete: $e');
      print('📍 StackTrace: $stackTrace');
      return {
        'error': 'Erro inesperado ao calcular frete',
        'fee': 0,
        'distance_km': null,
        'rule_type': null,
        'eligible_for_free_delivery': false,
      };
    }
  }
}
