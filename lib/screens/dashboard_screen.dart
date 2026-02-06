import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/dashboard_data.dart';
import '../widgets/aqi_gauge_card.dart';
import '../widgets/risk_badge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ApiService api;
  final _locationService = LocationService();
  
  // State variables instead of a single Future
  DashboardData? _data;
  bool _isLoading = true;
  String? _errorMessage;
  String? _detectedLocation;

  @override
  void initState() {
    super.initState();
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://airguardai.onrender.com',
    );
    api = ApiService(baseUrl);
    
    // 1. Initial Load (Default Location)
    _loadData(); 
    
    // 2. Background Location Refinement
    _detectLocationAndReload();
  }

  /// Centralized method to fetch data.
  /// If [city] is null, it uses the currently known _detectedLocation or defaults.
  Future<void> _loadData({String? city}) async {
    // Only show loading spinner if we have NO data yet (First load).
    // If we already have data, we just refresh silently/background.
    if (_data == null) {
      setState(() => _isLoading = true);
    }

    try {
      final queryCity = city ?? _detectedLocation;

      // FIXED: Pass the city to BOTH endpoints. 
      // Previously, 'fetchEnvPrediction' was missing the city, causing a data mismatch.
      final latest = await api.fetchLatest(city: queryCity);
      final predict = await api.fetchEnvPrediction(city: queryCity); 

      if (mounted) {
        setState(() {
          _data = DashboardData.fromApi(latest, predict);
          if (city != null) _detectedLocation = city; // Update source of truth
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _detectLocationAndReload() async {
    // Pass 'false' to fail silently if permission isn't already granted
    final city = await _locationService.getCurrentCity(requestPermission: false);
    
    if (city != null && mounted) {
      // Logic check: If the API is already showing this city, don't reload.
      if (_detectedLocation != city) {
        print("Location refined to: $city"); // Debug log
        _loadData(city: city);
      }
    }
  }

  void _manualRefresh() async {
    setState(() => _isLoading = true); // Force spinner on manual refresh
    
    // Ask for permission explicitly this time
    final city = await _locationService.getCurrentCity(requestPermission: true);
    
    // Reload with new city (or null, which falls back to existing/default)
    _loadData(city: city);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AirGuard AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _manualRefresh,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_data == null) {
      return const Center(child: Text("No data available"));
    }

    // If we are refreshing in the background, _data is still valid here.
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AqiGaugeCard(
            // Use the location actually returned by the API data to ensure accuracy
            location: _data!.location, 
            aqi: _data!.aqi,
            updatedAt: DateTime.now(),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RiskBadge(
            risk: _data!.risk,
            confidence: _data!.confidence,
            explanation:
                'Virus similarity is derived from protein sequence analysis. '
                'Air quality context provided for: ${_detectedLocation ?? "Default Region"}',
          ),
        ),
      ],
    );
  }
}