import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  // ✅ UPDATED: Accepts city to get specific environmental predictions
  Future<Map<String, dynamic>> fetchEnvPrediction({String? city}) async {
    // If a city is provided, send it in the body. Otherwise send empty map.
    final bodyData = city != null ? {'location': city} : {};

    final res = await http.post(
      Uri.parse('$baseUrl/predict_env'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyData),
    );
    
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch env prediction: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ✅ Virus + environment combined prediction (Kept as is)
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
    );
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

    final res = await http.get(uri);
    
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch latest: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> fetchHistory({int hours = 24}) async {
    final res = await http.get(Uri.parse('$baseUrl/history?hours=$hours'));
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch history: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}