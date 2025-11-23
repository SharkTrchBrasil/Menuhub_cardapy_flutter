// lib/services/reverse_geocoding_service.dart

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Serviço de reverse geocoding usando Mapbox (preferencial) ou Nominatim (fallback)
/// Converte coordenadas (latitude, longitude) em endereço
class ReverseGeocodingService {
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';
  
  // Dio separado para chamadas externas (sem interceptores)
  static Dio? _dio;
  
  static Dio get _externalDio {
    if (_dio != null) return _dio!;
    
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'MenuHub/1.0', // Obrigatório para Nominatim
      },
    ));
    
    return _dio!;
  }

  /// Converte coordenadas em endereço
  /// Retorna um mapa com os dados do endereço ou null se não encontrar
  /// ✅ MELHORADO: Usa Mapbox primeiro (mais preciso), fallback para Nominatim
  static Future<Map<String, dynamic>?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    // ✅ CRÍTICO: Tenta Mapbox primeiro (muito mais preciso para bairros no Brasil)
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (mapboxToken.isNotEmpty) {
      final mapboxResult = await _reverseGeocodeWithMapbox(latitude, longitude, mapboxToken);
      if (mapboxResult != null) {
        return mapboxResult;
      }
      print('⚠️ Mapbox reverse geocoding falhou, tentando Nominatim...');
    }
    
    // Fallback para Nominatim
    return await _reverseGeocodeWithNominatim(latitude, longitude);
  }

  /// ✅ NOVO: Reverse geocoding usando Mapbox v6 (muito mais preciso)
  /// Documentação: https://docs.mapbox.com/api/search/geocoding/
  static Future<Map<String, dynamic>?> _reverseGeocodeWithMapbox(
    double latitude,
    double longitude,
    String accessToken,
  ) async {
    try {
      // ✅ ATUALIZADO: Usa API v6 do Mapbox (endpoint diferente)
      final url = 'https://api.mapbox.com/search/geocoding/v6/reverse';
      
      print('🔍 ========== INICIANDO REVERSE GEOCODING MAPBOX v6 ==========');
      print('📍 Coordenadas: lat=$latitude, lon=$longitude');
      print('🌐 URL: $url');
      
      final response = await _externalDio.get(
        url,
        queryParameters: {
          'longitude': longitude.toString(),
          'latitude': latitude.toString(),
          'access_token': accessToken,
          'language': 'pt-BR',
          'limit': 1,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      // ✅ DEBUG: Print completo da resposta do Mapbox
      print('🔍 ========== RESPOSTA COMPLETA DO MAPBOX ==========');
      print('📦 Response Status: ${response.statusCode}');
      print('📦 Response Data Type: ${response.data.runtimeType}');
      print('📦 Response Data: ${response.data}');
      print('🔍 ================================================');

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>?;
        
        if (responseData == null) {
          print('⚠️ Response data é null');
          return null;
        }
        
        final features = responseData['features'] as List?;
        if (features == null || features.isEmpty) {
          print('⚠️ Nenhuma feature retornada do Mapbox');
          print('📦 ResponseData completo: $responseData');
          return null;
        }
        
        final feature = features[0] as Map<String, dynamic>;
        
        // ✅ DEBUG: Print da feature completa
        print('🔍 ========== FEATURE COMPLETA ==========');
        print('Feature Type: ${feature['type']}');
        print('Feature Properties: ${feature['properties']}');
        print('Feature Geometry: ${feature['geometry']}');
        print('Feature Context: ${feature['context']}');
        print('Feature completo: $feature');
        print('🔍 =====================================');
        
        final context = feature['context'] as List?;
        final properties = feature['properties'] as Map<String, dynamic>?;
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List?;
        
        // ✅ DEBUG: Print do contexto detalhado
        print('🔍 ========== ANÁLISE DO CONTEXTO ==========');
        print('Context é null? ${context == null}');
        print('Context length: ${context?.length ?? 0}');
        if (context != null) {
          for (var i = 0; i < context.length; i++) {
            final item = context[i];
            print('Context[$i]: $item');
            if (item is Map) {
              print('  - id: ${item['id']}');
              print('  - type: ${item['type']}');
              print('  - text: ${item['text']}');
              print('  - short_code: ${item['short_code']}');
            }
          }
        }
        print('🔍 =========================================');
        
        // Extrai informações do contexto (Mapbox v6 usa contexto estruturado)
        String? neighborhood;
        String? locality;
        String? city;
        String? state;
        String? postalCode;
        
        if (context != null) {
          for (var item in context) {
            if (item is! Map<String, dynamic>) continue;
            
            final id = item['id'] as String?;
            final type = item['type'] as String?;
            final text = item['text'] as String?;
            final shortCode = item['short_code'] as String?;
            
            // ✅ DEBUG: Print de cada item do contexto
            print('🔍 Analisando Context Item:');
            print('   - id: $id');
            print('   - type: $type');
            print('   - text: $text');
            print('   - short_code: $shortCode');
            
            if (text != null && text.isNotEmpty) {
              // ✅ CRÍTICO: Verifica pelo TYPE primeiro (v6 usa type no contexto)
              if (type == 'neighborhood' || (id != null && id.contains('neighborhood'))) {
                neighborhood = text;
                print('   ✅ Bairro encontrado (neighborhood): $text');
              } else if (type == 'locality' || (id != null && id.contains('locality'))) {
                // Locality pode ser usado como bairro se não tiver neighborhood
                if (neighborhood == null) {
                  locality = text;
                  print('   ✅ Locality encontrado (pode ser bairro): $text');
                }
              } else if (type == 'place' || (id != null && id.contains('place'))) {
                if (city == null) {
                  city = text;
                  print('   ✅ Cidade encontrada: $text');
                }
              } else if (type == 'region' || (id != null && id.contains('region'))) {
                state = text;
                print('   ✅ Estado encontrado: $text');
              } else if (type == 'postcode' || (id != null && id.contains('postcode'))) {
                postalCode = text;
                print('   ✅ CEP encontrado: $text');
              }
            }
          }
        }
        
        // ✅ CRÍTICO: Usa neighborhood primeiro, depois locality como fallback
        final finalNeighborhood = neighborhood ?? locality ?? '';
        
        // Extrai rua e número
        final featureText = properties?['name'] as String? ?? 
                           properties?['address_line1'] as String? ??
                           feature['text'] as String? ?? '';
        final addressNumber = properties?['address_number'] as String? ?? 
                             properties?['address'] as String? ?? '';
        
        // ✅ DEBUG: Print do resultado final
        print('🔍 ========== RESULTADO FINAL EXTRAÍDO ==========');
        print('Rua: $featureText');
        print('Número: $addressNumber');
        print('Bairro (neighborhood): $neighborhood');
        print('Locality: $locality');
        print('Bairro Final (usado): $finalNeighborhood');
        print('Cidade: $city');
        print('Estado: $state');
        print('CEP: $postalCode');
        print('🔍 ============================================');
        
        final result = {
          'street': featureText,
          'number': addressNumber,
          'neighborhood': finalNeighborhood,
          'city': city ?? '',
          'state': state ?? '',
          'postcode': postalCode ?? '',
          'country': 'Brasil',
          'latitude': coordinates != null && coordinates.length >= 2 
              ? (coordinates[1] as num?)?.toDouble() 
              : latitude,
          'longitude': coordinates != null && coordinates.length >= 2 
              ? (coordinates[0] as num?)?.toDouble() 
              : longitude,
          'display_name': properties?['full_address'] as String? ?? 
                         properties?['place_name'] as String? ?? 
                         featureText,
        };
        
        print('🔍 ========== RESULTADO FINAL RETORNADO ==========');
        print('$result');
        print('🔍 ==============================================');
        
        return result;
      }

      print('⚠️ Status code não é 200: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Erro no reverse geocoding Mapbox: $e');
      if (e is DioException) {
        print('❌ DioException - Status: ${e.response?.statusCode}');
        print('❌ DioException - Message: ${e.message}');
        print('❌ DioException - Data: ${e.response?.data}');
        print('❌ DioException - Request Path: ${e.requestOptions.path}');
        print('❌ DioException - Request Query: ${e.requestOptions.queryParameters}');
      }
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Fallback: Reverse geocoding usando Nominatim (OpenStreetMap)
  static Future<Map<String, dynamic>?> _reverseGeocodeWithNominatim(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await _externalDio.get(
        _nominatimUrl,
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'format': 'json',
          'addressdetails': '1',
          'accept-language': 'pt-BR,pt,en',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        
        if (data['error'] != null) {
          return null;
        }

        final address = data['address'] as Map<String, dynamic>?;
        if (address == null) {
          return null;
        }

        // Extrai informações do endereço
        return {
          'street': _getStreet(address),
          'number': _extractNumberFromAddress(address),
          'neighborhood': address['suburb'] ?? 
                         address['neighbourhood'] ?? 
                         address['quarter'] ?? 
                         address['city_district'] ?? 
                         '',
          'city': address['city'] ?? 
                 address['town'] ?? 
                 address['municipality'] ?? 
                 address['village'] ?? 
                 '',
          'state': address['state'] ?? 
                  address['region'] ?? 
                  '',
          'postcode': address['postcode'] ?? '',
          'country': address['country'] ?? '',
          'latitude': latitude,
          'longitude': longitude,
          'display_name': data['display_name'] ?? '',
        };
      }

      return null;
    } on DioException catch (e) {
      print('❌ Erro no reverse geocoding Nominatim: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Erro inesperado no reverse geocoding: $e');
      return null;
    }
  }

  static String _getStreet(Map<String, dynamic> address) {
    return address['road'] ?? 
           address['street'] ?? 
           address['pedestrian'] ?? 
           address['path'] ?? 
           '';
  }

  static String _extractNumberFromAddress(Map<String, dynamic> address) {
    // Tenta extrair número de vários campos possíveis
    return address['house_number'] ?? 
           address['house'] ?? 
           address['building'] ?? 
           '';
  }
}

