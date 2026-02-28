import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://airguardai.onrender.com";
  static double? lastFetchedTemp;
  static double? lastFetchedHumidity;
  static const Duration _timeout = Duration(seconds: 20);

  final String instanceBaseUrl;
  ApiService(this.instanceBaseUrl);

  // ---------------------------
  // Static Helpers (Required for static methods)
  // ---------------------------

  static String _staticSafeBody(http.Response res) {
    final body = res.body;
    if (body.isEmpty) return '';
    return body.length > 800 ? body.substring(0, 800) : body;
  }

  static Exception _staticHttpError(String label, http.Response res) {
    return Exception('$label: ${res.statusCode} ${_staticSafeBody(res)}');
  }

  // ---------------------------
  // Instance Helpers (Kept for non-static methods)
  // ---------------------------

  String _safeBody(http.Response res) => _staticSafeBody(res);
  Exception _httpError(String label, http.Response res) => _staticHttpError(label, res);

  // ---------------------------
  // AQICN Search (Instance Method)
  // ---------------------------

  Future<List<Map<String, dynamic>>> searchStations(String keyword) async {
    final q = keyword.trim();
    if (q.length < 2) return const <Map<String, dynamic>>[];

    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {'keyword': q});

    try {
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) throw _httpError('Search failed', res);

      final data = jsonDecode(res.body);
      final rawList = (data is Map && data['results'] is List)
          ? (data['results'] as List)
          : const <dynamic>[];

      final out = <Map<String, dynamic>>[];
      for (final item in rawList) {
        if (item is Map) {
          final m = item.map((k, v) => MapEntry(k.toString(), v));
          if (m['name'] != null) {
            out.add({
              'uid': m['uid'],
              'name': m['name'],
              'aqi': m['aqi'],
            });
          }
        }
      }
      return out.where((r) => r['name'] != null).toList();
    } catch (e) {
      print('Search error: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  // ---------------------------
  // WAQI Data Fetching (Static)
  // ---------------------------

  static Future<Map<String, dynamic>> fetchWAQIData(String path) async {
    final url = "$baseUrl/waqi/feed?path=${Uri.encodeComponent(path)}";
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        
        if (decoded['status'] == 'ok') {
          final data = decoded['data'];
          final Map<String, dynamic> result = Map<String, dynamic>.from(data);

          if (data['city'] != null && data['city']['geo'] != null) {
            List<dynamic> geo = data['city']['geo'];
            if (geo.length >= 2) {
              result['lat'] = (geo[0] as num).toDouble();
              result['lng'] = (geo[1] as num).toDouble();
            }
          }

          if (data['iaqi'] != null) {
            final iaqi = data['iaqi'];
            if (iaqi['t'] != null) {
              result['temp'] = (iaqi['t']['v'] as num).toDouble();
              lastFetchedTemp = result['temp'];
            }
            if (iaqi['h'] != null) {
              result['humidity'] = (iaqi['h']['v'] as num).toDouble();
              lastFetchedHumidity = result['humidity'];
            }
          }
          return result; 
        }
      }
      throw Exception("Failed to load WAQI data via Proxy");
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------
  // WAQI 7-Day History (Static)
  // ---------------------------

  static Future<Map<String, dynamic>> fetch7DayAQI(double lat, double lng) async {
    final url = Uri.parse('$baseUrl/waqi/history').replace(queryParameters: {
      'lat': lat.toString(),
      'lng': lng.toString(),
    });
    
    try {
      final response = await http.get(url).timeout(_timeout);
    
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'ok' && data['data'] != null) {
          final cityName = data['data']['city']?['name'] ?? "Unknown Station";
          
          if (data['data']['forecast']?['daily']?['pm25'] != null) {
            final List forecast = data['data']['forecast']['daily']['pm25'];
            final String todayStr = DateTime.now().toIso8601String().split('T')[0];
            
            final pastAndToday = forecast.where((item) {
              return (item['day'] as String).compareTo(todayStr) <= 0;
            }).toList();

            pastAndToday.sort((a, b) => a['day'].compareTo(b['day']));

            final int count = pastAndToday.length;
            final int start = count > 7 ? count - 7 : 0;
            final List<dynamic> last7Days = pastAndToday.sublist(start);

            List<double> aqiValues = [];
            List<String> days = [];

            for (var item in last7Days) {
              aqiValues.add((item['avg'] as num).toDouble());
              String dateStr = item['day']; 
              final parts = dateStr.split('-');
              days.add(parts.length == 3 ? '${parts[1]}/${parts[2]}' : dateStr);
            }
            
            return {
              'values': aqiValues,
              'days': days,
              'cityName': cityName,
            };
          }
        }
      }
      return {'values': <double>[], 'days': <String>[], 'cityName': 'No Data'};
    } catch (e) {
      return {'values': <double>[], 'days': <String>[], 'cityName': 'Error'};
    }
  }

Future<Map<String, dynamic>> fetchLatest({
    String? city,
    double? lat,
    double? lng,
  }) async {
    final params = <String, String>{};
    if (city != null) params['location'] = city;
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();

    final uri = Uri.parse('$baseUrl/latest').replace(queryParameters: params);
    final res = await http.get(uri).timeout(_timeout);

    if (res.statusCode != 200) throw _httpError('Failed to fetch latest', res);
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>> fetchEnvPrediction({String? city}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/predict_env'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(city != null ? {'location': city} : {}),
    ).timeout(_timeout);

    if (res.statusCode != 200) throw _httpError('Failed env prediction', res);
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  // ---------------------------
  // Gemini AI (Static)
  // ---------------------------
  
static Future<String> getGeminiPrediction(String prompt, String systemContext) async {
    final url = Uri.parse('$baseUrl/gemini/chat');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'system_context': systemContext,
        }),
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['text'] ?? "Analysis failed.";
      }
      // Use the static helper to avoid instance access error
      throw _staticHttpError('Gemini Proxy Error', res);
    } catch (e) {
      return "AI connection error: $e";
    }
  }
}