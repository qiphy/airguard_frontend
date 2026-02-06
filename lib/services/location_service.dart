import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Attempts to get the current city name silently.
  /// Returns null if permission is denied or service is disabled.
  Future<String?> getCurrentCity({bool requestPermission = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        if (requestPermission) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return null;
        } else {
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) return null;

      // Get position
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Decode to city name
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // Prioritize locality (City) -> SubAdmin (District) -> Admin (State)
        return p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
      }
    } catch (_) {
      // Fail silently
    }
    return null;
  }
}