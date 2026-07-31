import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

enum LocationAccessStatus {
  granted,
  denied,
  deniedForever,
  disabled,
  unavailable,
}

class LocationCoordinates {
  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class LocationAccessResult {
  const LocationAccessResult({
    required this.status,
    this.coordinates,
  });

  final LocationAccessStatus status;
  final LocationCoordinates? coordinates;
}

abstract class LocationService {
  Future<LocationAccessResult> getCurrentCoordinates();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationAccessResult> getCurrentCoordinates() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationAccessResult(status: LocationAccessStatus.disabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationAccessResult(status: LocationAccessStatus.denied);
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationAccessResult(
          status: LocationAccessStatus.deniedForever,
        );
      }

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return LocationAccessResult(
          status: LocationAccessStatus.granted,
          coordinates: LocationCoordinates(
            latitude: lastKnownPosition.latitude,
            longitude: lastKnownPosition.longitude,
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));

      return LocationAccessResult(
        status: LocationAccessStatus.granted,
        coordinates: LocationCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on MissingPluginException {
      // This can happen right after adding the plugin if the app was only hot reloaded,
      // or on targets where the native plugin is not available yet. Product code should
      // degrade gracefully instead of crashing the entire home flow.
      return const LocationAccessResult(status: LocationAccessStatus.unavailable);
    } catch (_) {
      return const LocationAccessResult(status: LocationAccessStatus.unavailable);
    }
  }
}
