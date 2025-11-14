// lib/services/geolocation_service.dart
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';


/// Serviço de geolocalização usando fórmula Haversine (sem APIs caras)
class GeolocationService {
  /// Raio da Terra em quilômetros
  static const double _earthRadiusKm = 6371.0;

  /// Calcula a distância entre duas coordenadas usando fórmula Haversine
  /// Retorna a distância em quilômetros
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = _earthRadiusKm * c;

    return distance;
  }

  /// Converte graus para radianos
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Verifica se uma coordenada está dentro do raio de entrega
  static bool isWithinDeliveryRadius({
    required double storeLat,
    required double storeLon,
    required double? deliveryRadiusKm,
    required double customerLat,
    required double customerLon,
  }) {
    if (deliveryRadiusKm == null || deliveryRadiusKm <= 0) {
      // Se não há raio definido, assume que está dentro (fallback para sistema antigo)
      return true;
    }

    final distance = calculateDistance(
      lat1: storeLat,
      lon1: storeLon,
      lat2: customerLat,
      lon2: customerLon,
    );

    return distance <= deliveryRadiusKm;
  }

  /// Obtém a localização atual do dispositivo
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  /// Solicita permissão de localização
  static Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      return permission != LocationPermission.denied;
    }

    return permission != LocationPermission.deniedForever;
  }
}

