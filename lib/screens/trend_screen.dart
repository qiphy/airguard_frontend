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

  DateTime _floorToHour(DateTime d) => DateTime(d.year, d.month, d.day, d.hour);

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

      // ✅ ENFORCE WINDOW (past N hours) on the client
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(hours: hours));

      final filtered = rawPoints.where((p) {
        final t = p.ts?.toLocal();
        if (t == null) return false;
        return t.isAfter(cutoff);
      }).toList();

      return filtered;
    } catch (e) {
      // ignore: avoid_print
      print("Error loading trends: $e");
      rethrow;
    }
  }

  bool _useGrid(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    // On web/desktop, you can also trigger grid even in portrait if wide enough.
    final isWide = media.size.width >= 900;

    return isLandscape || isWide;
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

          // ✅ Safe debug (after empty check)
          debugPrint(
            "hours=$hours -> points=${points.length} "
            "first=${points.first.ts} last=${points.last.ts}",
          );

          // Values (already sorted)
          final aqiValues = points.map((p) => p.aqi?.toDouble()).toList();
          final pm25Values = points.map((p) => p.pm25?.toDouble()).toList();

          // Dates: convert to local for display/charting
          final dates = points.map((p) {
            final ts = p.ts;
            if (ts == null) return null;

            final local = ts.toLocal();
            if (!useRealTimeXAxis && floorLabelsToHourWhenIndexBased) {
              return _floorToHour(local);
            }
            return local;
          }).toList();

          final gridMode = _useGrid(context);

          // --- Chart+insight blocks ---
          final aqiBlock = _TrendBlock(
            chart: LineChartCard(
              title: "AQI Trend",
              values: aqiValues,
              dates: dates,
              unit: "AQI",
              useTimeXAxis: useRealTimeXAxis,
            ),
            insight: trendInsight(aqiValues, label: "AQI"),
          );

          final pm25Block = _TrendBlock(
            chart: LineChartCard(
              title: "PM2.5 Trend",
              values: pm25Values,
              dates: dates,
              unit: "µg/m³",
              useTimeXAxis: useRealTimeXAxis,
            ),
            insight: trendInsight(pm25Values, label: "PM2.5"),
          );

          if (!gridMode) {
            // ===== Portrait / narrow: keep simple ListView =====
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _hoursPicker(),
                const SizedBox(height: 12),

                aqiBlock,
                const SizedBox(height: 16),

                pm25Block,
                const SizedBox(height: 24),

                Text(
                  "Tip: Keep collecting data to see the trend line grow.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }

          // ===== Landscape / wide: charts in 2-column grid =====
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // top controls
                Align(
                  alignment: Alignment.centerLeft,
                  child: _hoursPicker(),
                ),
                const SizedBox(height: 12),

                // grid area
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    // Wider-than-tall tiles: fits short landscape heights better
                    childAspectRatio: 1.35,
                    children: const [],
                  ),
                ),
              ],
            ),
          )._withGridChildren([aqiBlock, pm25Block]);
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

/// A chart card + its insight text, kept together as a single block.
class _TrendBlock extends StatelessWidget {
  final Widget chart;
  final String insight;

  const _TrendBlock({
    required this.chart,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chart,
        const SizedBox(height: 10),
        Text(insight),
      ],
    );
  }
}

/// Tiny helper extension so we can keep the GridView code clean.
extension _GridChildrenHack on Widget {
  Widget _withGridChildren(List<Widget> children) {
    // This extension wraps the widget tree and swaps the placeholder GridView
    // with the real one without duplicating the surrounding layout.
    if (this is! Padding) return this;
    final p = this as Padding;

    return Padding(
      padding: p.padding,
      child: Builder(
        builder: (context) {
          // Rebuild the structure with children injected
          final col = (p.child as Column);
          final top = col.children[0];
          final gap = col.children[1];
          final expanded = col.children[2] as Expanded;
          final grid = expanded.child as GridView;

          return Column(
            children: [
              top,
              gap,
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.35,
                  children: children,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
