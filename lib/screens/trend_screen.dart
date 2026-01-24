// lib/screens/trends_screen.dart
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

  /// true = real-time X axis (recommended)
  /// false = index-based X axis (even spacing)
  final bool useRealTimeXAxis = true;

  /// Only used when useRealTimeXAxis == false
  /// Floors labels to the hour so you never see :17 etc.
  final bool floorLabelsToHourWhenIndexBased = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      future = _fetchAndSort();
    });
  }

DateTime _floorToHour(DateTime d) =>
    DateTime(d.year, d.month, d.day, d.hour);

  Future<List<HistoryPoint>> _fetchAndSort() async {
    try {
      final res = await api.fetchHistory(hours: hours);
      final rawPoints = (res['points'] as List)
          .map((e) => HistoryPoint.fromJson(e as Map<String, dynamic>))
          .toList();

      // Sort by timestamp (oldest → newest)
      rawPoints.sort((a, b) {
        if (a.ts == null) return -1;
        if (b.ts == null) return 1;
        return a.ts!.compareTo(b.ts!);
      });

      return rawPoints;
    } catch (e) {
      // ignore: avoid_print
      print("Error loading trends: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trends"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
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
          if (points.isEmpty) {
            return const Center(child: Text("No data yet. Check back later!"));
          }

          // Values (already sorted)
          final aqiValues = points.map((p) => p.aqi?.toDouble()).toList();
          final pm25Values = points.map((p) => p.pm25?.toDouble()).toList();

          // Dates: DO NOT mutate HistoryPoint.ts (it may be final)
          final dates = points.map((p) {
            if (p.ts == null) return null;

            final local = p.ts!.toLocal();

            if (!useRealTimeXAxis && floorLabelsToHourWhenIndexBased) {
              return _floorToHour(local);
            }

            return local;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _hoursPicker(),
              const SizedBox(height: 12),

              LineChartCard(
                title: "AQI Trend",
                values: aqiValues,
                dates: dates,
                unit: "AQI",
                useTimeXAxis: useRealTimeXAxis,
              ),
              const SizedBox(height: 12),
              Text(trendInsight(aqiValues, label: "AQI")),
              const SizedBox(height: 16),

              LineChartCard(
                title: "PM2.5 Trend",
                values: pm25Values,
                dates: dates,
                unit: "µg/m³",
                useTimeXAxis: useRealTimeXAxis,
              ),
              const SizedBox(height: 12),
              Text(trendInsight(pm25Values, label: "PM2.5")),

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
              _load();
            });
          },
        ),
      ],
    );
  }
}
