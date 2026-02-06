import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  
  // 1. TIMEOUT FIX: 
  // Render free servers take ~60s to wake up. Default Flutter timeout is too short.
  // We set this to 90 seconds to prevent "ClientException: Failed to fetch".
  static const Duration _timeout = Duration(seconds: 90);

  ApiService(this.baseUrl);

  // ✅ UPDATED: Accepts city to get specific environmental predictions
  Future<Map<String, dynamic>> fetchEnvPrediction({String? city}) async {
    // If a city is provided, send it in the body. Otherwise send empty map.
    final bodyData = city != null ? {'location': city} : {};

    final res = await http.post(
      Uri.parse('$baseUrl/predict_env'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyData),
    ).timeout(_timeout); // <--- Applied Timeout
    
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch env prediction: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ✅ Virus + environment combined prediction
  Future<Map<String, dynamic>> fetchVirusPrediction({
    required String proteinSequence,
    String location = "Kuala Lumpur",
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "protein_sequence": proteinSequence,
        "location": location,
      }),
    ).timeout(_timeout); // <--- Applied Timeout

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch virus prediction: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ✅ UPDATED: Accepts city for live sensor data
  Future<Map<String, dynamic>> fetchLatest({String? city}) async {
    // We use Uri.replace to safely add query parameters (handles spaces automatically)
    // Example result: https://.../latest?location=Subang%20Jaya
    final uri = Uri.parse('$baseUrl/latest').replace(
      queryParameters: city != null ? {'location': city} : null,
    );

    final res = await http.get(uri).timeout(_timeout); // <--- Applied Timeout
    
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch latest: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  // ✅ UPDATED: Added optional city parameter to match backend capabilities
  Future<Map<String, dynamic>> fetchHistory({int hours = 24, String? city}) async {
    final queryParams = {'hours': hours.toString()};
    if (city != null) {
      queryParams['location'] = city;
    }

    final uri = Uri.parse('$baseUrl/history').replace(queryParameters: queryParams);
    
    final res = await http.get(uri).timeout(_timeout); // <--- Applied Timeout

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch history: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}