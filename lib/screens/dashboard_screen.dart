import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../providers/location_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/aqi_gauge_card.dart';
import '../widgets/risk_badge.dart';
import '../widgets/aqi_range_legend.dart';

// ------------------------------------------------------------------
// DYNAMIC HEALTH SERVICE: Malaysia Open Data + AI Rationale
// ------------------------------------------------------------------
class KKMService {
  static const String _geminiKey = "AIzaSyCE39GkPuUSO5PPoGOHrUAkUdmsxFoMvQA";

  Future<List<Map<String, dynamic>>> getEnvironmentalHealthRisks(
      String location, num aqi, double temp, double humidity) async {
    try {
      final now = DateTime.now();
      final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      final currentMonth = months[now.month - 1];
      final currentYear = now.year;
      final currentDate = "$currentMonth $currentYear";

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiKey);
      
      final prompt = """
        You are an AI Environmental Health Expert. 
        Current Location: $location.
        Current Date: $currentDate.
        Current Environmental Data:
        - AQI: $aqi
        - Temperature: ${temp}°C
        - Humidity: ${humidity}%
        
        Task: Based STRICTLY on these environmental parameters and the current season, identify the top 5 specific health risks, viruses, or conditions for this location right now. 
        
        CRITICAL INSTRUCTIONS:
        1. Name SPECIFIC diseases or viruses (For example, "Dengue Fever", "Influenza A", "Tuberculosis", "COVID-19") and provide other viruses not in the examples if relevant to the current location. 
        2. Do NOT use vague umbrella categories like "Airborne Diseases".
        3. Write the 'desc' and 'rationale' in a professional, public-health advisory tone. It should be scientifically accurate but clearly readable by the general public.
        4. Do NOT provide estimated case numbers.
        5. Write the 'suggestions' in an easily understandable tone. It should be clearly readable by the general public.
        
        Output MUST be a valid JSON array of objects using this exact schema:
        [
          {"name": "Specific Disease/Condition Name", "risk": "High/Moderate/Low", "desc": "A concise summary of the risk.", "rationale": "Scientific explanation linking this disease to the AQI, Temp, Humidity, or season.", "suggestions": "Recommending what the user can and cannot do based on this condition."}
        ]
      """;

      final content = [Content.text(prompt)];
      final aiResponse = await model.generateContent(content);
      final text = aiResponse.text ?? "[]";
      
      final match = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      final cleanJson = match != null ? match.group(0)! : "[]";
      
      return List<Map<String, dynamic>>.from(jsonDecode(cleanJson));
    } catch (e) {
      return [
        {"name": "Asthma Exacerbation", "risk": aqi > 100 ? "High" : "Moderate", "desc": "Elevated risk of asthma attacks and airway inflammation.", "rationale": "High AQI levels introduce particulate matter that triggers bronchospasms in sensitive individuals.", "suggestions": "Stay at home to prevent inhaling air from the haze."},
        {"name": "Dengue Fever", "risk": (temp > 28 && humidity > 60) ? "Moderate" : "Low", "desc": "Current weather accelerates Aedes mosquito breeding.", "rationale": "High ambient temperatures and humidity shorten the mosquito life cycle and increase viral replication rates.", "suggestions": "Spray the outside of your house with mosquito repellent."},
      ];
    }
  }
}

// ------------------------------------------------------------------
// DASHBOARD SCREEN
// ------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _locationService = LocationService();
  final _kkmService = KKMService();
  final ApiService api = ApiService('https://airguardai.onrender.com');

  bool _isLoading = false;
  String? _errorMessage;
  num _aqi = 0;
  double _temp = 0.0;
  double _humidity = 0.0;
  String _risk = 'LOW';
  double _confidence = 0.0;
  String _stationUsed = '';
  double? _currentLat, _currentLng;

  @override
  void initState() {
    super.initState();
    _detectLocationAndReload(requirePermission: false);
  }

Future<void> _loadData({
  required String locationKey,
  String? displayName,
  double? lat,
  double? lng,
  bool updateProvider = true,
}) async {
  if (_isLoading) return;
  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _currentLat = lat;
    _currentLng = lng;
  });

  try {
    final latest = await api.fetchLatest(
      city: (lat != null && lng != null) ? null : locationKey,
      lat: lat,
      lng: lng
    );
    final resolvedDisplay = latest['display_location'] ?? latest['station'] ?? displayName ?? locationKey;

    final predict = await api.fetchEnvPrediction(city: resolvedDisplay.toString());
    final Map predMap = (predict['prediction'] is Map) ? predict['prediction'] : predict;

    double fetchedTemp = 0.0;
    double fetchedHumidity = 0.0;
    num fetchedAqi = (latest['aqi'] is num) ? latest['aqi'] : 0;

    // Ensure we use the passed-in lat/lng as priority
    double? finalLat = lat ?? double.tryParse(latest['lat']?.toString() ?? '');
    double? finalLng = lng ?? double.tryParse(latest['lng']?.toString() ?? '');
    String? stationUid = locationKey.startsWith('@') ? locationKey : latest['uid']?.toString();

    try {
      String waqiPath;
      if (finalLat != null && finalLng != null) {
        waqiPath = 'geo:${finalLat.toStringAsFixed(4)};${finalLng.toStringAsFixed(4)}';
      } else {
        waqiPath = stationUid ?? locationKey;
      }

      final localAqiData = await ApiService.fetchWAQIData(waqiPath);
      
      // --- FIX STARTS HERE ---
      // The WAQI API returns data in 'iaqi' -> 't' (temp) -> 'v' (value)
      if (localAqiData['iaqi'] != null) {
        final iaqi = localAqiData['iaqi'];
        // Parse Temperature (t)
        if (iaqi['t'] != null && iaqi['t']['v'] != null) {
          fetchedTemp = (iaqi['t']['v'] as num).toDouble();
        }
        // Parse Humidity (h)
        if (iaqi['h'] != null && iaqi['h']['v'] != null) {
          fetchedHumidity = (iaqi['h']['v'] as num).toDouble();
        }
      } 
      
      // Fallback: If your ApiService flattens data, keep this check, otherwise the above handles it
      if (fetchedTemp == 0.0) fetchedTemp = (localAqiData['temp'] as num?)?.toDouble() ?? 0.0;
      if (fetchedHumidity == 0.0) fetchedHumidity = (localAqiData['humidity'] as num?)?.toDouble() ?? 0.0;
      
      fetchedAqi = localAqiData['aqi'] ?? fetchedAqi;
      
      // Sync coordinates from WAQI if they were missing
      finalLat ??= (localAqiData['lat'] != null) ? (localAqiData['lat'] as num).toDouble() : null;
      finalLng ??= (localAqiData['lng'] != null) ? (localAqiData['lng'] as num).toDouble() : null;

      if (stationUid == null && localAqiData['idx'] != null) {
        stationUid = "@${localAqiData['idx']}";
      }
      // --- FIX ENDS HERE ---
      
    } catch (e) {
      debugPrint("WAQI Fetch Error: $e");
    }

    if (!mounted) return;

    if (updateProvider) {
      Provider.of<LocationProvider>(context, listen: false).updateLocation(
        resolvedDisplay.toString(),
        uid: stationUid,
        lat: finalLat,
        lon: finalLng,
      );
    }

    setState(() {
      _stationUsed = resolvedDisplay.toString();
      _aqi = fetchedAqi;
      _temp = fetchedTemp;
      _humidity = fetchedHumidity;
      _risk = predMap['risk']?.toString().toUpperCase() ?? 'LOW';
      _confidence = (predMap['confidence'] is num) ? (predMap['confidence'] as num).toDouble() : 0.0;
      _isLoading = false;
    });
  } catch (e) {
    if (mounted) setState(() { _errorMessage = "API Error: $e"; _isLoading = false; });
  }
}

  Future<void> _detectLocationAndReload({required bool requirePermission}) async {
    final summary = await _locationService.getLocationSummary();
    if (!mounted) return;
    if (summary["ok"] == true) {
      await _loadData(
        locationKey: summary["name"] ?? "Current Location",
        lat: (summary["lat"] as num).toDouble(),
        lng: (summary["lng"] as num).toDouble(),
      );
    } else if (requirePermission) {
      setState(() => _errorMessage = "Location sensor access denied.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLoc = Provider.of<LocationProvider>(context).currentLocation;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
// Inside DashboardScreen build method -> AppBar -> GestureDetector -> onTap
        onTap: () => showSearch(
                    context: context,
                    delegate: LocationSearchDelegate(
                      api: api,
                      provider: Provider.of<LocationProvider>(context, listen: false),
                      // Callback now accepts lat and lon
                      onSelected: (sel, name, lat, lon) => _loadData(
                        locationKey: sel, 
                        displayName: name, 
                        lat: lat, 
                        lng: lon, 
                        updateProvider: true
                      ),
                    ),
                  ),
          child: Row(
            children: [
              const Icon(Icons.place, size: 22, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Flexible(child: Text(currentLoc, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => _detectLocationAndReload(requirePermission: true),
          )
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildScrollableContent(currentLoc),
    );
  }

  Widget _buildScrollableContent(String locationName) {
    if (_errorMessage != null) return Center(child: Text(_errorMessage!));

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWideScreen = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              if (isWideScreen)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          
                          _buildGaugeWithMetrics(true),
                          const SizedBox(height: 24),
                          RiskBadge(risk: _risk, confidence: _confidence, explanation: 'Prediction for $_stationUsed'),
                          const SizedBox(height: 16),
                          AqiRangeLegend(aqi: _aqi),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKKMThreatsHeader(),
                          const SizedBox(height: 12),
                          _buildKKMThreatsSection(locationName, isDesktop: true),
                        ],
                      ),
                    ),
                  ],
                )
                else
                // MOBILE: Standard Stacked View
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGaugeWithMetrics(false),
                    const SizedBox(height: 16),
                    
                    AqiRangeLegend(aqi: _aqi),
                    const SizedBox(height: 24),
                    
                    _buildKKMThreatsHeader(),
                    const SizedBox(height: 12),
                    _buildKKMThreatsSection(locationName),
                    const SizedBox(height: 16),
                    RiskBadge(risk: _risk, confidence: _confidence, explanation: 'Prediction for $_stationUsed'),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Color _getAqiBaseColor(num aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.amber;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  Widget _buildGaugeWithMetrics(bool isWide) {
    final baseColor = _getAqiBaseColor(_aqi);
    final borderColor = baseColor.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withOpacity(0.25),
            baseColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: isWide 
        ? Row(
            children: [
              Expanded(flex: 2, child: AqiGaugeCard(location: _stationUsed, aqi: _aqi, updatedAt: DateTime.now())),
              const SizedBox(width: 20),
              Expanded(flex: 1, child: Column(children: _getMetricTiles())),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, 
            children: [
              AqiGaugeCard(location: _stationUsed, aqi: _aqi, updatedAt: DateTime.now()),
              const SizedBox(height: 16),
              ..._getMetricTiles(), 
            ],
          ),
    );
  }

  List<Widget> _getMetricTiles() {
    return [
      _metricTile(Icons.thermostat, "${_temp.toStringAsFixed(1)}°C", "Temperature", Colors.orange),
      const SizedBox(height: 12, width: 12),
      _metricTile(Icons.water_drop, "${_humidity.toStringAsFixed(0)}%", "Humidity", Colors.blueAccent),
    ];
  }

  Widget _metricTile(IconData icon, String val, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  } 

  Widget _buildKKMThreatsHeader() {
    final now = DateTime.now();
    final shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final currentShortDate = "${shortMonths[now.month - 1]} ${now.year}";

    return Row(
      children: [
        const Icon(Icons.auto_awesome, size: 18, color: Colors.deepPurple),
        const SizedBox(width: 8),
        Text(
          "Health & Environment Risks ($currentShortDate)", 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        ),
      ],
    );
  }

  Widget _buildKKMThreatsSection(String location, {bool isDesktop = false}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _kkmService.getEnvironmentalHealthRisks(location, _aqi, _temp, _humidity),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("No risk data available.");
        }
        return Column(
          children: snapshot.data!.map((t) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(radius: 6, backgroundColor: _getRiskColor(t['risk'] ?? 'Low')),
              title: Text(t['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                "${t['risk']} Risk", 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: _getRiskColor(t['risk'] ?? 'Low'),
                  fontSize: 13,
                ),
              ), 
              onTap: () => _showVirusDetail(t),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            ),
          )).toList(),
        );
      },
    );
  }

void _showVirusDetail(Map<String, dynamic> virus) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to expand for longer suggestions
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text(virus['name'] ?? 'Unknown', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "${virus['risk']} Risk Level", 
                style: TextStyle(color: _getRiskColor(virus['risk'] ?? 'Low'), fontWeight: FontWeight.bold, fontSize: 16)
              ),
              const Divider(height: 40),

              // Description
              const Text("About this risk", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(virus['desc'] ?? '', style: const TextStyle(fontSize: 16, height: 1.5)),
              const SizedBox(height: 24),

              // Scientific Rationale (The "Why")
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05), 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.1))
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science_outlined, size: 22, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Rationale: ${virus['rationale']}", 
                        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)
                      )
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Actionable Suggestions (The "New Suggestions" variable)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08), 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.2))
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 22, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Health Advice", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            virus['suggestions'] ?? "No specific suggestions available.", 
                            style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4, fontWeight: FontWeight.w500)
                          ),
                        ],
                      )
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Close Button
              SizedBox(
                width: double.infinity, 
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("Got it", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
  Color _getRiskColor(String risk) {
    if (risk.contains("Critical") || risk.contains("Alert") || risk == "High") return Colors.red;
    if (risk == "Moderate" || risk == "Warning") return Colors.orange;
    return Colors.blue;
  }
}

// ------------------------------------------------------------------
// SEARCH DELEGATE
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// FIXED SEARCH DELEGATE
// ------------------------------------------------------------------
class LocationSearchDelegate extends SearchDelegate<String> {
  final ApiService api;
  final LocationProvider provider;
  final void Function(String sel, String name, double? lat, double? lon) onSelected;

  LocationSearchDelegate({required this.api, required this.provider, required this.onSelected});

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  @override
  Widget buildResults(BuildContext context) => _buildSuggestions(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions(context);

  Widget _buildSuggestions(BuildContext context) {
    if (query.trim().length < 2) return const Center(child: Text("Search city or station..."));
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: api.searchStations(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        final results = snapshot.data ?? [];
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            final name = item['name']?.toString() ?? 'Unknown Station';
            final aqiValue = item['aqi']?.toString() ?? '--';

            return ListTile(
              leading: const Icon(Icons.location_city),
              title: Text(name),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _getAqiColor(aqiValue), borderRadius: BorderRadius.circular(6)),
                child: Text("AQI $aqiValue", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              onTap: () async {
                double? targetLat;
                double? targetLon;
                final String stationUid = item['uid']?.toString() ?? '';
                final String name = item['name']?.toString() ?? 'Station';

                try {
                  // 1. Better than Geocoding: Fetch the live feed for this specific ID
                  // The path should be something like "@1234"
                  final String path = stationUid.startsWith('@') ? stationUid : '@$stationUid';
                  final stationDetails = await ApiService.fetchWAQIData(path);

                  // 2. Extract coordinates directly from the station's metadata
                  // Note: Adjust the keys based on your fetchWAQIData return structure
                  targetLat = stationDetails['lat']?.toDouble();
                  targetLon = stationDetails['lng']?.toDouble();
                  
                  debugPrint("✅ Found Coordinates via WAQI: $targetLat, $targetLon");
                } catch (e) {
                  debugPrint("⚠️ WAQI detail fetch failed, trying Geocoding fallback...");
                  // 3. Fallback to geocoding if the API fetch fails
                  try {
                    final locations = await geo.locationFromAddress(name);
                    if (locations.isNotEmpty) {
                      targetLat = locations.first.latitude;
                      targetLon = locations.first.longitude;
                    }
                  } catch (_) {}
                }

                // 4. Update the provider - the chart will now definitely move
                onSelected(
                  stationUid.isNotEmpty ? '@$stationUid' : name, 
                  name, 
                  targetLat, 
                  targetLon
                );
                close(context, name);
              },
            );
          },
        );
      },
    );
  }

  Color _getAqiColor(String aqiStr) {
    final v = int.tryParse(aqiStr);
    if (v == null) return Colors.grey;
    if (v <= 50) return Colors.green;
    if (v <= 100) return Colors.amber;
    if (v <= 150) return Colors.orange;
    if (v <= 200) return Colors.red;
    return Colors.purple;
  }
}