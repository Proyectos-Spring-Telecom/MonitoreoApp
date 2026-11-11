import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<bool> requestLocationPermission() async {
    // Verificar si el servicio de ubicación está habilitado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Tiempo máximo para obtener la posición una vez concedido el permiso.
  static const Duration positionTimeout = Duration(seconds: 15);

  /// Tiempo máximo de todo el proceso, incluido el aviso de permiso. Algunos
  /// navegadores (Safari, PWA en iOS) a veces nunca responden.
  static const Duration totalTimeout = Duration(seconds: 30);

  /// `null` si no hay permiso o no se obtuvo la posición a tiempo; quien la
  /// pide sigue sin coordenadas.
  static Future<Position?> getCurrentLocation() async {
    try {
      return await _readPosition().timeout(totalTimeout);
    } catch (e) {
      return null;
    }
  }

  static Future<Position?> _readPosition() async {
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: positionTimeout,
        ),
      );
    } catch (e) {
      // Sin señal a tiempo: la última posición conocida (no existe en web).
      if (kIsWeb) return null;
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  static Future<String?> getLocationName(
      double latitude, double longitude) async {
    try {
      // Por ahora retornamos las coordenadas formateadas
      // En el futuro se puede integrar con un servicio de geocoding inverso
      // como Google Maps Geocoding API o similar
      return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    } catch (e) {
      // En caso de error, retornar coordenadas
      return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }
  }
}
