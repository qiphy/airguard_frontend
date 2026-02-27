import 'package:flutter/material.dart';

class LocationProvider with ChangeNotifier {
  // UI Display Name
  String _currentLocation = "Kuala Lumpur";
  
  // Strict Numerical ID (e.g., "@8832")
  String _stationId = "@8832"; 
  
  // Coordinates are the primary "engine" for the Analytics Page
  double _latitude = 3.1390; 
  double _longitude = 101.6869;

  String get currentLocation => _currentLocation;
  
  // Returns the numerical ID (e.g., @123) for general WAQI feeds
  String get queryId => _stationId;
  
  double get latitude => _latitude;
  double get longitude => _longitude;

  /// UPDATED: Enforces that location updates sync both ID and Coordinates
  void updateLocation(String name, {String? uid, double? lat, double? lon}) {
    _currentLocation = name;
    
    // 1. Update the Station ID
    if (uid != null && uid.isNotEmpty) {
      // Ensure numerical IDs are prefixed with @ for WAQI API consistency
      _stationId = uid.startsWith('@') ? uid : '@$uid';
    }

    // 2. CRITICAL FIX: Update coordinates
    // If your AnalyticsPage uses lat/lng, these MUST change here
    if (lat != null && lon != null) {
      _latitude = lat;
      _longitude = lon;
      debugPrint("📍 Provider Updated: $name ($lat, $lon)");
    } else {
      debugPrint("⚠️ Warning: $name updated without new coordinates. Chart may not move.");
    }

    // 3. Notify all listening widgets (Dashboard, Analytics, etc.)
    notifyListeners();
  }

  /// Sets station ID directly and triggers listeners
  void setStationId(dynamic id) {
    if (id == null) return;
    final String stringId = id.toString();
    _stationId = stringId.startsWith('@') ? stringId : '@$stringId';
    notifyListeners();
  }

  /// Sets coordinates directly and triggers listeners
  /// Use this when GPS moves or a search result provides lat/lng
  void setCoordinates(double lat, double lon) {
    _latitude = lat;
    _longitude = lon;
    debugPrint("📡 GPS/Manual Coordinate Sync: $lat, $lon");
    notifyListeners();
  }

  /// Convenience method to update everything at once from a Map (e.g., search result)
  void updateFromMap(Map<String, dynamic> data) {
    final String name = data['name'] ?? _currentLocation;
    final String? uid = data['uid']?.toString();
    final double? lat = data['lat']?.toDouble();
    final double? lon = data['lng']?.toDouble();
    
    updateLocation(name, uid: uid, lat: lat, lon: lon);
  }
}