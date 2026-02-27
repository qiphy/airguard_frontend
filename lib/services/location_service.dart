// lib/services/location_service.dart
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Future<bool> ensurePermission() async {
    // Web: permissions behave differently; just attempt and handle failures
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !kIsWeb) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) return false;
      if (permission == LocationPermission.deniedForever) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Position?> getCurrentPositionSafe() async {
    try {
      final ok = await ensurePermission();
      if (!ok) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (e) {
      debugPrint("getCurrentPositionSafe error: $e");
      return null;
    }
  }

Future<String?> reverseGeocodeSafe(Position? pos) async {
  if (pos == null) return null;

  final lat = pos.latitude;
  final lon = pos.longitude;

  // reject NaN/Infinity
  if (!lat.isFinite || !lon.isFinite) return null;

  // ✅ fallback string that is always usable
  final coordFallback =
      "${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}";

  // ✅ On Web, reverse geocoding is often unreliable. Don’t depend on it.
  if (kIsWeb) return coordFallback;

  try {
    final placemarks = await placemarkFromCoordinates(lat, lon)
        .timeout(const Duration(seconds: 8));

    if (placemarks.isEmpty) return coordFallback;

    final p = placemarks.first;

    final parts = <String>[
      (p.locality ?? '').trim(),
      (p.administrativeArea ?? '').trim(),
      (p.country ?? '').trim(),
    ].where((s) => s.isNotEmpty).toList();

    return parts.isEmpty ? coordFallback : parts.join(', ');
  } catch (e) {
    debugPrint("reverseGeocodeSafe error: $e");
    return coordFallback;
  }
}


  /// Convenience: get "City, State, Country" or fallback.
  Future<Map<String, dynamic>> getLocationSummary() async {
    final pos = await getCurrentPositionSafe();
    if (pos == null) {
      return {
        "ok": false,
        "name": "Current Location",
        "lat": null,
        "lng": null,
        "error": "Location unavailable or denied",
      };
    }

    final name = await reverseGeocodeSafe(pos) ?? "Current Location";

    return {
      "ok": true,
      "name": name,
      "lat": pos.latitude,
      "lng": pos.longitude,
    };
  }

  
}
