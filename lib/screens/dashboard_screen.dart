import 'package:flutter/material.dart';
import '../services/api_service.dart';
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
  late Future<DashboardData> future;

  @override
  void initState() {
    super.initState();

    // Configure at runtime:
    // flutter run -d chrome --dart-define=API_BASE_URL=https://airguardai.onrender.com
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://airguardai.onrender.com',
    );

    api = ApiService(baseUrl);
    future = _loadData();
  }

  Future<DashboardData> _loadData() async {
    final latest = await api.fetchLatest();
    final predict = await api.fetchEnvPrediction();
    return DashboardData.fromApi(latest, predict);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AirGuard AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
            onPressed: () {
              setState(() {
                future = _loadData();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === AQI METER (ENVIRONMENT ONLY) ===
              AqiGaugeCard(
                location: data.location,
                aqi: data.aqi,
                updatedAt: DateTime.now(),
              ),

              const SizedBox(height: 16),

              // === COMBINED SURVEILLANCE INDICATOR ===
              RiskBadge(
                risk: data.risk,
                confidence: data.confidence,
                explanation:
                    'Virus similarity is derived from protein sequence analysis. '
                    'Air quality (AQI / PM2.5) is used only to contextualise '
                    'environmental susceptibility.',
              ),
            ],
          );
        },
      ),
    );
  }
}
