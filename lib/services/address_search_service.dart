// lib/services/address_search_service.dart

import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nb_utils/nb_utils.dart';

/// Modelo de resultado da busca de endereço
class AddressSearchResult {
  final String description; // Descrição completa do endereço
  final String? street;
  final String? number;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? placeId; // Google Places ID

  AddressSearchResult({
    required this.description,
    this.street,
    this.number,
    this.neighborhood,
    this.city,
    this.state,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.placeId,
  });
}

/// Serviço de busca de endereço usando Google Places Autocomplete
/// Tier gratuito: $200/mês (aproximadamente 40.000 requisições)
class AddressSearchService {
  static const String _googlePlacesAutocompleteUrl = 
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _googlePlacesDetailsUrl = 
      'https://maps.googleapis.com/maps/api/place/details/json';

  final Dio _dio;

  AddressSearchService(this._dio);

  /// Busca sugestões de endereço baseado no texto digitado
  /// [input] - Texto de busca
  /// [countryCode] - Código do país (ex: 'br' para Brasil). Default: 'br'
  /// [userLatitude] - Latitude do usuário para bias de localização
  /// [userLongitude] - Longitude do usuário para bias de localização
  Future<List<AddressSearchResult>> searchAddresses({
    required String input,
    String countryCode = 'br',
    double? userLatitude,
    double? userLongitude,
  }) async {
    if (input.trim().isEmpty) {
      return [];
    }

    try {
      // ✅ SOLUÇÃO: Usa Mapbox Geocoding API (100k requisições/mês grátis)
      final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      
      if (mapboxToken.isNotEmpty) {
        final results = await _searchWithMapbox(input, countryCode, userLatitude, userLongitude, mapboxToken);
        if (results.isNotEmpty) return results;
        print('⚠️ Mapbox retornou 0 resultados, tentando Nominatim...');
      }
      
      // Fallback para Nominatim se não tiver token do Mapbox ou resultados vazios
      return await _searchWithNominatim(input, countryCode, userLatitude, userLongitude);
    } catch (e) {
      print('❌ Erro ao buscar endereços: $e');
      return await _searchWithNominatim(input, countryCode, userLatitude, userLongitude);
    }
  }

  /// Busca usando Mapbox Geocoding API
  /// 100.000 requisições/mês GRÁTIS
  /// Excelente qualidade de dados para Brasil
  Future<List<AddressSearchResult>> _searchWithMapbox(
    String input,
    String countryCode,
    double? userLatitude,
    double? userLongitude,
    String accessToken,
  ) async {
    try {
      // URL encode do input
      final encodedInput = Uri.encodeComponent(input.trim());
      
      // Monta a URL do Mapbox
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedInput.json';
      
      final queryParams = <String, dynamic>{
        'access_token': accessToken,
        'country': countryCode,
        'language': 'pt-BR',
        'types': 'address,place', // Endereços e lugares
        'limit': 10, 
      };

      if (userLatitude != null && userLongitude != null) {
        queryParams['proximity'] = '$userLongitude,$userLatitude'; 
      }

      print('🔍 [Mapbox] Request: $url');
      print('🔍 [Mapbox] Params: $queryParams');

      final response = await _dio.get(
        url,
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['features'] != null) {
        final features = response.data['features'] as List;
        
        // ✅ NOVO: Mapeia e calcula distâncias
        final resultsWithDistance = features.map((feature) {
          final properties = feature['properties'] as Map<String, dynamic>?;
          final context = feature['context'] as List?;
          final geometry = feature['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List?;
          
          // Calcula distância se tiver coordenadas do usuário
          double? distance;
          if (userLatitude != null && userLongitude != null && 
              coordinates != null && coordinates.length >= 2) {
            final resultLat = (coordinates[1] as num?)?.toDouble();
            final resultLon = (coordinates[0] as num?)?.toDouble();
            if (resultLat != null && resultLon != null) {
              distance = _calculateDistance(
                userLatitude, userLongitude,
                resultLat, resultLon,
              );
            }
          }
          
          // Extrai informações do contexto
          String? neighborhood;
          String? city;
          String? state;
          String? postalCode;
          
          if (context != null) {
            for (var item in context) {
              final id = item['id'] as String?;
              final text = item['text_pt-BR'] as String? ?? item['text'] as String?;
              
              if (id != null && text != null) {
                if (id.startsWith('neighborhood') || id.startsWith('locality')) {
                  neighborhood = text;
                } else if (id.startsWith('place')) {
                  city = text;
                } else if (id.startsWith('region')) {
                  state = text;
                } else if (id.startsWith('postcode')) {
                  postalCode = text;
                }
              }
            }
          }
          
          return {
            'result': AddressSearchResult(
              description: feature['place_name_pt-BR'] as String? ?? 
                          feature['place_name'] as String? ?? '',
              street: feature['text_pt-BR'] as String? ?? feature['text'] as String? ?? '',
              number: properties?['address'] ?? '',
              neighborhood: neighborhood,
              city: city,
              state: state,
              postalCode: postalCode,
              latitude: coordinates != null && coordinates.length >= 2 
                  ? (coordinates[1] as num?)?.toDouble() 
                  : null,
              longitude: coordinates != null && coordinates.length >= 2 
                  ? (coordinates[0] as num?)?.toDouble() 
                  : null,
              placeId: feature['id'] as String?,
            ),
            'distance': distance,
          };
        }).toList();
        
        // ✅ CRÍTICO: Filtra e ordena por distância se tiver coordenadas do usuário
        if (userLatitude != null && userLongitude != null) {
          // Filtra resultados dentro de 30km (raio da cidade)
          final filtered = resultsWithDistance.where((item) {
            final dist = item['distance'] as double?;
            return dist == null || dist <= 30.0; // 30km de raio
          }).toList();
          
          // Ordena por distância (mais próximos primeiro)
          filtered.sort((a, b) {
            final distA = a['distance'] as double? ?? double.infinity;
            final distB = b['distance'] as double? ?? double.infinity;
            return distA.compareTo(distB);
          });
          
          // Retorna apenas os 10 mais próximos
          return filtered
              .take(10)
              .map((item) => item['result'] as AddressSearchResult)
              .toList();
        }
        
        // Se não tiver coordenadas, retorna os primeiros 10
        return resultsWithDistance
            .take(10)
            .map((item) => item['result'] as AddressSearchResult)
            .toList();
      } else {
        print('⚠️ Mapbox API retornou status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao buscar com Mapbox: $e');
      // Fallback para Nominatim
      return await _searchWithNominatim(input, countryCode, userLatitude, userLongitude);
    }

    return [];
  }
  
  /// Calcula distância em km entre duas coordenadas (fórmula de Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Raio da Terra em km
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final sinHalfDLat = math.sin(dLat / 2);
    final sinHalfDLon = math.sin(dLon / 2);
    
    final a = sinHalfDLat * sinHalfDLat +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        sinHalfDLon * sinHalfDLon;
    
    final c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Busca detalhes completos de um endereço usando Place ID do Google
  Future<AddressSearchResult?> getAddressDetails(String placeId) async {
    try {
      final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
      
      if (apiKey.isEmpty) {
        return null;
      }

      final response = await _dio.get(
        _googlePlacesDetailsUrl,
        queryParameters: {
          'place_id': placeId,
          'key': apiKey,
          'language': 'pt-BR',
          'fields': 'formatted_address,address_components,geometry',
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final result = response.data['result'];
        return _parseGooglePlaceDetails(result);
      }
    } catch (e) {
      print('Erro ao buscar detalhes do endereço: $e');
    }

    return null;
  }

  /// Parse dos detalhes do Google Places
  AddressSearchResult? _parseGooglePlaceDetails(Map<String, dynamic> result) {
    final components = result['address_components'] as List?;
    if (components == null) return null;

    String? street;
    String? number;
    String? neighborhood;
    String? city;
    String? state;
    String? postalCode;

    for (var component in components) {
      final types = (component['types'] as List?)?.cast<String>() ?? [];
      final longName = component['long_name'] as String? ?? '';
      final shortName = component['short_name'] as String? ?? '';

      if (types.contains('street_number')) {
        number = longName;
      } else if (types.contains('route')) {
        street = longName;
      } else if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
        neighborhood = longName;
      } else if (types.contains('administrative_area_level_2') || types.contains('locality')) {
        city = longName;
      } else if (types.contains('administrative_area_level_1')) {
        state = shortName;
      } else if (types.contains('postal_code')) {
        postalCode = longName;
      }
    }

    final geometry = result['geometry'];
    final location = geometry?['location'];
    final latitude = location?['lat']?.toDouble();
    final longitude = location?['lng']?.toDouble();

    return AddressSearchResult(
      description: result['formatted_address'] ?? '',
      street: street,
      number: number,
      neighborhood: neighborhood,
      city: city,
      state: state,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
      placeId: result['place_id'] as String?,
    );
  }

  /// Fallback: Busca usando Nominatim (OpenStreetMap) - totalmente gratuito
  Future<List<AddressSearchResult>> _searchWithNominatim(
    String input,
    String countryCode,
    double? userLatitude,
    double? userLongitude,
  ) async {
    try {
      // ✅ MELHORIA: Prepara a query de busca
      String query = input.trim();
      
      // Se a query for muito curta ou genérica, adiciona contexto
      if (countryCode.toLowerCase() == 'br' && !query.toLowerCase().contains('brasil')) {
        query = '$query, Brasil';
      }

      final queryParams = <String, dynamic>{
        'q': query,
        'format': 'json',
        'limit': 10, // ✅ Aumentado de 5 para 10
        'addressdetails': 1,
        'countrycodes': countryCode,
        'accept-language': 'pt-BR,pt',
        'dedupe': 1, // Remove duplicatas
      };

      // ✅ MELHORIA: Adiciona viewbox para priorizar resultados próximos ao usuário
      if (userLatitude != null && userLongitude != null) {
        // Cria um "viewbox" de aproximadamente 100km ao redor do usuário
        final latDelta = 0.9; // ~100km
        final lonDelta = 0.9; // ~100km
        final left = userLongitude - lonDelta;
        final top = userLatitude + latDelta;
        final right = userLongitude + lonDelta;
        final bottom = userLatitude - latDelta;
        queryParams['viewbox'] = '$left,$top,$right,$bottom';
        queryParams['bounded'] = '0'; // Não força resultados dentro do box, apenas prioriza
      }

      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'User-Agent': 'MenuHub/1.0', // Obrigatório para Nominatim
          },
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final results = response.data as List;
        
        // ✅ MELHORIA: Filtra resultados irrelevantes
        final filteredResults = results.where((result) {
          final name = (result['name'] as String?)?.toLowerCase() ?? '';
          final displayName = (result['display_name'] as String?) ?? '';
          
          // Remove resultados genéricos como "Rua" sem nome específico
          if (name == 'rua' || name == 'avenida' || name == 'travessa') {
            return false;
          }
          
          // Remove resultados que não têm endereço detalhado
          final address = result['address'] as Map<String, dynamic>?;
          if (address == null) {
            return false;
          }
          
          return displayName.isNotEmpty;
        }).toList();
        
        return filteredResults.map((result) {
          final address = result['address'] as Map<String, dynamic>?;
          return AddressSearchResult(
            description: result['display_name'] ?? '',
            street: address?['road'] ?? address?['street'] ?? '',
            number: address?['house_number'] ?? '',
            neighborhood: address?['suburb'] ?? 
                         address?['neighbourhood'] ?? 
                         address?['quarter'] ?? '',
            city: address?['city'] ?? 
                 address?['town'] ?? 
                 address?['municipality'] ?? '',
            state: address?['state'] ?? '',
            postalCode: address?['postcode'] ?? '',
            latitude: (result['lat'] as String?)?.toDouble(),
            longitude: (result['lon'] as String?)?.toDouble(),
          );
        }).toList();
      }
    } catch (e) {
      print('❌ Erro ao buscar endereços com Nominatim: $e');
    }

    return [];
  }
}

