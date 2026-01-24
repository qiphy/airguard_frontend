import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  // ✅ Env-only prediction (no body) — recommended to keep Dashboard working
  Future<Map<String, dynamic>> fetchEnvPrediction() async {
    final res = await http.post(
      Uri.parse('$baseUrl/predict_env'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch env prediction: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ✅ NEW: Virus + environment combined prediction
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
      // backend returns {"detail": "..."} on error
      throw Exception('Failed to fetch virus prediction: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchLatest() async {
    final res = await http.get(Uri.parse('$baseUrl/latest'));
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
