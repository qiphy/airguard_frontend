import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
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

  final _locationService = LocationService();

  int hours = 24;
  late Future<List<HistoryPoint>> future;

  // Use real-time X axis for better accuracy
  final bool useRealTimeXAxis = true;

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

  Future<List<HistoryPoint>> _fetchAndSort() async {
    try {
      final res = await api.fetchHistory(hours: hours);
      
      final rawPoints = (res['points'] as List)
          .map((e) => HistoryPoint.fromJson(e as Map<String, dynamic>))
          .toList();

      rawPoints.sort((a, b) {
        if (a.ts == null) return -1;
        if (b.ts == null) return 1;
        return a.ts!.compareTo(b.ts!);
      });

      return rawPoints;
    } catch (e) {
      debugPrint("Error loading trends: $e");
      rethrow;
    }
  }

  bool _useGrid(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.orientation == Orientation.landscape || media.size.width >= 900;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Tuned aspect ratio to prevent "Bottom Overflowed" in landscape
    final double gridAspectRatio = media.size.height < 500 ? 1.4 : 1.1;

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

          // 1. Safe Filtering
          final validAqiPoints = points.where((p) => p.aqi != null && p.ts != null).toList();
          final validPm25Points = points.where((p) => p.pm25 != null && p.ts != null).toList();

          if (validAqiPoints.isEmpty && validPm25Points.isEmpty) {
             return const Center(child: Text("Data available but values are missing/null."));
          }

          final aqiValues = validAqiPoints.map((p) => p.aqi!.toDouble()).toList();
          final aqiDates = validAqiPoints.map((p) => p.ts!.toLocal()).toList();

          final pm25Values = validPm25Points.map((p) => p.pm25!.toDouble()).toList();
          final pm25Dates = validPm25Points.map((p) => p.ts!.toLocal()).toList();

          final gridMode = _useGrid(context);

          // 2. Constraints Setup
          final constraints = gridMode 
              ? const BoxConstraints() // Let GridView control height
              : const BoxConstraints(minHeight: 240); // Force height in list

          // 3. Create Blocks (With Empty Data Safety)
          final aqiBlock = _TrendBlock(
            gridMode: gridMode,
            chart: ConstrainedBox(
              constraints: constraints,
              child: aqiValues.isEmpty 
                  ? const Center(child: Text("No AQI Data"))
                  : LineChartCard(
                      title: "AQI Trend",
                      values: aqiValues,
                      dates: aqiDates,
                      unit: "AQI",
                      useTimeXAxis: useRealTimeXAxis,
                    ),
            ),
            // ✅ FIX: Don't call trendInsight on empty list
            insight: aqiValues.isEmpty 
                ? "Insufficient data for insight." 
                : trendInsight(aqiValues, label: "AQI"),
          );

          final pm25Block = _TrendBlock(
            gridMode: gridMode,
            chart: ConstrainedBox(
              constraints: constraints,
              child: pm25Values.isEmpty
                  ? const Center(child: Text("No PM2.5 Data"))
                  : LineChartCard(
                      title: "PM2.5 Trend",
                      values: pm25Values,
                      dates: pm25Dates,
                      unit: "µg/m³",
                      useTimeXAxis: useRealTimeXAxis,
                    ),
            ),
            // ✅ FIX: Don't call trendInsight on empty list
            insight: pm25Values.isEmpty 
                ? "Insufficient data for insight." 
                : trendInsight(pm25Values, label: "PM2.5"),
          );

          // 4. Render Layout
          if (!gridMode) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(alignment: Alignment.centerLeft, child: _hoursPicker()),
                const SizedBox(height: 12),
                aqiBlock,
                const SizedBox(height: 16),
                pm25Block,
                const SizedBox(height: 24),
              ],
            );
          }

          // Grid Layout (Landscape/Wide)
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Align(alignment: Alignment.centerLeft, child: _hoursPicker()),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: gridAspectRatio,
                    children: [aqiBlock, pm25Block],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hoursPicker() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Window: "),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: hours,
          items: const [
            DropdownMenuItem(value: 6, child: Text("6 hours")),
            DropdownMenuItem(value: 12, child: Text("12 hours")),
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

class _TrendBlock extends StatelessWidget {
  final Widget chart;
  final String insight;
  final bool gridMode;

  const _TrendBlock({
    required this.chart,
    required this.insight,
    required this.gridMode,
  });

  @override
  Widget build(BuildContext context) {
    final insightWidget = Text(
      insight,
      maxLines: gridMode ? 2 : null,
      overflow: gridMode ? TextOverflow.ellipsis : TextOverflow.visible,
      style: Theme.of(context).textTheme.bodyMedium,
    );

    if (!gridMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [chart, const SizedBox(height: 10), insightWidget],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: chart), 
        const SizedBox(height: 10), 
        insightWidget
      ],
    );
  }
}