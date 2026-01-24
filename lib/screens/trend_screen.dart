import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/history_point.dart';
import '../widgets/line_chart_card.dart';
import '../utils/trend_insight.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  final api = ApiService(const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://airguardai.onrender.com',
  ));

  int hours = 24;
  late Future<List<HistoryPoint>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<HistoryPoint>> _load() async {
    final res = await api.fetchHistory(hours: hours);
    final points = (res['points'] as List)
        .map((e) => HistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    // CRITICAL: Sort by date so the graph draws left-to-right correctly
    points.sort((a, b) {
      if (a.ts == null) return -1;
      if (b.ts == null) return 1;
      return a.ts!.compareTo(b.ts!);
    });

    return points;
  }

  void _reload() {
    setState(() {
      future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trends"),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<HistoryPoint>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final points = snapshot.data ?? [];
          final aqiValues = points.map((p) => p.aqi?.toDouble()).toList();
          final pm25Values = points.map((p) => p.pm25).toList();
          
          // Extract the DateTime list to pass to the chart
          final dates = points.map((p) => p.ts).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _hoursPicker(),
              const SizedBox(height: 12),

              LineChartCard(
                title: "AQI Trend",
                values: aqiValues,
                dates: dates, // Passing the real dates now
                unit: "AQI",
              ),
              const SizedBox(height: 12),
              Text(trendInsight(aqiValues, label: "AQI")),
              const SizedBox(height: 16),

              LineChartCard(
                title: "PM2.5 Trend",
                values: pm25Values.map((e) => e?.toDouble()).toList(),
                dates: dates, // Passing the real dates now
                unit: "µg/m³",
              ),
              const SizedBox(height: 12),
              Text(trendInsight(pm25Values.map((e) => e?.toDouble()).toList(), label: "PM2.5")),

              const SizedBox(height: 24),
              Text(
                "Tip: Keep collecting data to see the trend line grow.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hoursPicker() {
    return Row(
      children: [
        const Text("Window: "),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: hours,
          items: const [
            DropdownMenuItem(value: 24, child: Text("24 hours")),
            DropdownMenuItem(value: 72, child: Text("3 days")),
            DropdownMenuItem(value: 168, child: Text("7 days")),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              hours = v;
              future = _load();
            });
          },
        ),
      ],
    );
  }
}