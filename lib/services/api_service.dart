// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

class ApiService {
  final String baseUrl;
  
  // ⚠️ Replace with your actual secure key handling in production
  static const String _aqiToken = 'f3b08bd8268e7c6974d013f3567e08a021a84e3d';
  static const String _geminiKey = 'AIzaSyDGF-x6ObAoaKYOnFYR77cwhTeO1UejeXA'; 
  static double? lastFetchedTemp;
  static double? lastFetchedHumidity;

  static const Duration _timeout = Duration(seconds: 20);

  ApiService(this.baseUrl);

  // ---------------------------
  // Helpers
  // ---------------------------

  String _safeBody(http.Response res) {
    final body = res.body;
    if (body.isEmpty) return '';
    return body.length > 800 ? body.substring(0, 800) : body;
  }

  Exception _httpError(String label, http.Response res) {
    return Exception('$label: ${res.statusCode} ${_safeBody(res)}');
  }

  // ---------------------------
  // AQICN Search
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
  // WAQI Data Fetching (FIXED)
  // ---------------------------

  /// Fetches detailed data for a station/geo-location and flattens
  /// nested `iaqi` (temp/humidity) into the top-level map.
  static Future<Map<String, dynamic>> fetchWAQIData(String path) async {
    final url = "https://api.waqi.info/feed/$path/?token=$_aqiToken";
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        
        if (decoded['status'] == 'ok') {
          final data = decoded['data'];
          final Map<String, dynamic> result = Map<String, dynamic>.from(data);

          // 1. Extract Coordinates
          if (data['city'] != null && data['city']['geo'] != null) {
            List<dynamic> geo = data['city']['geo'];
            if (geo.length >= 2) {
              result['lat'] = (geo[0] as num).toDouble();
              result['lng'] = (geo[1] as num).toDouble();
            }
          }

          // 2. Extract Temp & Humidity from 'iaqi' (Flattening)
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

          // Ensure keys exist even if null (defaults)
          result.putIfAbsent('temp', () => 0.0);
          result.putIfAbsent('humidity', () => 0.0);
          
          return result; 
        }
      }
      throw Exception("Failed to load WAQI data: Status not ok");
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the last 7 days of AQI history from the forecast array
  static Future<Map<String, dynamic>> fetch7DayAQI(double lat, double lng) async {
    final cleanLat = lat.toStringAsFixed(4);
    final cleanLng = lng.toStringAsFixed(4);
    
    final url = Uri.parse(
      'https://api.waqi.info/feed/geo:$cleanLat;$cleanLng/?token=$_aqiToken'
    );
    
    try {
      final response = await http.get(url).timeout(_timeout);
    
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'ok' && data['data'] != null) {
          final cityName = data['data']['city']?['name'] ?? "Unknown Station";
          
          if (data['data']['forecast']?['daily']?['pm25'] != null) {
            final List forecast = data['data']['forecast']['daily']['pm25'];
            final String todayStr = DateTime.now().toIso8601String().split('T')[0];
            
            // 1. Filter: Get only dates <= Today (History + Today)
            final pastAndToday = forecast.where((item) {
              return (item['day'] as String).compareTo(todayStr) <= 0;
            }).toList();

            // 2. Sort: Ensure they are in ascending order
            pastAndToday.sort((a, b) => a['day'].compareTo(b['day']));

            // 3. Slice: Take the last 7 entries
            final int count = pastAndToday.length;
            final int start = count > 7 ? count - 7 : 0;
            final List<dynamic> last7Days = pastAndToday.sublist(start);

            List<double> aqiValues = [];
            List<String> days = [];

            for (var item in last7Days) {
              aqiValues.add((item['avg'] as num).toDouble());
              
              String dateStr = item['day']; 
              final parts = dateStr.split('-');
              // Format: "MM/DD"
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
      // Return empty structure on fail to prevent UI crash
      return {'values': <double>[], 'days': <String>[], 'cityName': 'Error'};
    }
  }

  // ---------------------------
  // Backend Endpoints
  // ---------------------------

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

    final data = jsonDecode(res.body);
    return (data is Map)
        ? data.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchEnvPrediction({String? city}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/predict_env'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(city != null ? {'location': city} : {}),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) throw _httpError('Failed env prediction', res);

    final data = jsonDecode(res.body);
    return (data is Map)
        ? data.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
  }

  // ---------------------------
  // Virus & NCBI Tools
  // ---------------------------

  Future<Map<String, dynamic>> predictVirusByName({
    required String location,
    required String virusName,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'virus_name': virusName,
            'location': location,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) throw _httpError('Failed virus prediction', res);

    final data = jsonDecode(res.body);
    return (data is Map)
        ? data.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
  }

  /// Checks NCBI database for virus citations in a location
  static Future<int> checkVirusInLocation(String virus, String location) async {
    // FIX: Correct string interpolation for virus name
    final query = '${virus}[Organism] AND ${location}[All Fields]';
    final term = Uri.encodeComponent(query);
    
    // Using AllOrigins proxy to bypass potential CORS in web apps, 
    // or direct NCBI if backend permits.
    final ncbiUrl = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=nuccore&term=$term&retmode=json';
    final proxyUrl = Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(ncbiUrl)}');
    
    try {
      final response = await http.get(proxyUrl).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['esearchresult'] != null && data['esearchresult']['count'] != null) {
          return int.parse(data['esearchresult']['count']);
        }
      }
    } catch (e) { 
      print("NCBI Error: $e"); 
    }
    return 0;
  }

  // ---------------------------
  // Gemini AI
  // ---------------------------

  static Future<String> getGeminiPrediction(
    String prompt, String systemContext,
  ) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash', 
      apiKey: _geminiKey,
    );

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Analysis failed to generate.";
    } catch (e) {
      throw Exception("Gemini API Error: $e");
    }
  }
}