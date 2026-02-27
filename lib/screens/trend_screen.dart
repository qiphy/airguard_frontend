import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../providers/location_provider.dart'; 

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  List<double> _weeklyAqi = [];
  List<String> _days = [];
  String _aiTrendAnalysis = "Waiting for data...";
  String _locationName = "Loading...";
  String _lastUpdatedStr = "Never";
  bool _isLoadingData = true;
  bool _isLoadingAI = true;

  // Trackers for change detection
  double? _lastLat;
  double? _lastLng;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // 10-second silent polling for current station data
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_lastLat != null && _lastLng != null) {
        _fetchDataAndAnalyze(
          lat: _lastLat!,
          lng: _lastLng!,
          locationName: _locationName,
          isSilentRefresh: true, 
          skipAi: true, 
        );
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); 
    super.dispose();
  }

  // --- REINFORCED: Detects location updates from Provider ---
  void _checkAndHandleLocationChange(LocationProvider provider) {
    final currentLat = provider.latitude;
    final currentLng = provider.longitude;

    // Detect if coordinates have actually changed
    if (currentLat != _lastLat || currentLng != _lastLng) {
      _lastLat = currentLat;
      _lastLng = currentLng;
      
      // HARD RESET: Clear existing state so user knows a new fetch started
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _weeklyAqi = [];
            _isLoadingData = true;
            _isLoadingAI = true;
          });
          _fetchDataAndAnalyze(
            lat: currentLat,
            lng: currentLng,
            locationName: provider.currentLocation.isEmpty ? "Current Location" : provider.currentLocation,
            isSilentRefresh: false, 
            skipAi: false,
          );
        }
      });
    }
  }

  Future<void> _fetchDataAndAnalyze({
    required double lat, 
    required double lng, 
    required String locationName,
    bool isSilentRefresh = false,
    bool skipAi = false,
  }) async {
    if (!mounted) return;

    try {
      // Step 1: Fetch Trend Data
      final trendData = await ApiService.fetch7DayAQI(lat, lng);
      
      if (!mounted) return;
      
      setState(() {
        _locationName = trendData['cityName'] ?? locationName;
        _weeklyAqi = List<double>.from(trendData['values']);
        _days = List<String>.from(trendData['days']);
        _lastUpdatedStr = DateFormat('HH:mm:ss').format(DateTime.now());
        _isLoadingData = false;
      });

      if (skipAi || _weeklyAqi.isEmpty) {
        if (_weeklyAqi.isEmpty) setState(() => _isLoadingAI = false);
        return;
      }

      // Step 2: Fetch AI Analysis
      final prompt = "Analyze these AQI values for $_locationName: ${_weeklyAqi.join(', ')}. Give 3 short tips.";
      final analysis = await ApiService.getGeminiPrediction(prompt, "Health Analyst");
      
      if (mounted) {
        setState(() {
          _aiTrendAnalysis = analysis;
          _isLoadingAI = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // TRIGGER: Watch the provider for changes
    final provider = context.watch<LocationProvider>();
    _checkAndHandleLocationChange(provider);

    double maxDataY = _weeklyAqi.isNotEmpty 
        ? _weeklyAqi.reduce((a, b) => a > b ? a : b) 
        : 100;
    double maxY = ((maxDataY / 20).ceil() * 20.0) + 20;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DEBUG HEADER & LOCATION ---
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    label: Text(provider.currentLocation), 
                    avatar: const Icon(Icons.location_on, size: 16, color: Colors.blueAccent)
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Last Update: $_lastUpdatedStr", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              const Text("Air Quality Trends", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              // --- CHART SECTION ---
              Container(
                height: 260,
                padding: const EdgeInsets.fromLTRB(8, 24, 24, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: _isLoadingData 
                  ? const Center(child: CircularProgressIndicator()) 
                  : LineChart(
                      _buildChartData(maxY),
                      duration: const Duration(milliseconds: 500),
                    ),
              ),

              const SizedBox(height: 32),
              _buildAiCard(),
            ],
          ),
        ),
      ),
    );
  }

  LineChartData _buildChartData(double maxY) {
    return LineChartData(
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.05))),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (val, meta) {
              int i = val.toInt();
              return (i >= 0 && i < _days.length) 
                ? Text(_days[i], style: const TextStyle(fontSize: 10, color: Colors.grey))
                : const SizedBox.shrink();
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: _weeklyAqi.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
          isCurved: true,
          barWidth: 4,
          belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.1)),
        ),
      ],
    );
  }

  Widget _buildAiCard() {
    return Card(
      elevation: 0,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blue.shade100)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.auto_awesome, color: Colors.blueAccent), SizedBox(width: 8), Text("AI Recommendations", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
            const Divider(height: 24),
            _isLoadingAI ? const Center(child: CircularProgressIndicator()) : MarkdownBody(data: _aiTrendAnalysis),
          ],
        ),
      ),
    );
  }
}