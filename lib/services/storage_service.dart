import '../models/saved_location.dart';

class StorageService {
  // A simple static list to act as our temporary database
  static List<SavedLocation> _mockDb = [
    SavedLocation(id: '1', name: 'Home', address: 'Ipoh, Perak'),
    SavedLocation(id: '2', name: 'Office', address: 'Kuala Lumpur'),
  ];

  static Future<List<SavedLocation>> loadLocations() async {
    // Simulate a short network/loading delay
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_mockDb);
  }

  static Future<void> addLocation(SavedLocation loc) async {
    _mockDb.add(loc);
  }

  static Future<void> removeLocation(String id) async {
    _mockDb.removeWhere((item) => item.id == id);
  }
}