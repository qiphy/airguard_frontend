// lib/widgets/line_chart_card.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ Reusable badge widget for min/max display
class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class LineChartCard extends StatefulWidget {
  final String title;
  final List<double?> values;
  final List<DateTime?>? dates;
  final String unit;
  final bool useTimeXAxis;

  const LineChartCard({
    super.key,
    required this.title,
    required this.values,
    this.dates,
    this.unit = "",
    this.useTimeXAxis = true,
  });

  @override
  State<LineChartCard> createState() => _LineChartCardState();
}

class _LineChartCardState extends State<LineChartCard> {
  int? _touchedIndex;

  String get title => widget.title;
  List<double?> get values => widget.values;
  List<DateTime?>? get dates => widget.dates;
  String get unit => widget.unit;
  bool get useTimeXAxis => widget.useTimeXAxis;

  DateTime _floorToHour(DateTime d) => DateTime(d.year, d.month, d.day, d.hour);

  DateTime _ceilToHour(DateTime d) {
    final floored = _floorToHour(d);
    return d.isAtSameMomentAs(floored)
        ? floored
        : floored.add(const Duration(hours: 1));
  }

  /// Calculate dynamic interval based on time range
  double _calculateInterval(DateTime first, DateTime last) {
    final duration = last.difference(first);
    final hours = duration.inHours;

    if (hours <= 24) {
      // 24h view: labels every 4 hours
      return const Duration(hours: 4).inMilliseconds.toDouble();
    } else if (hours <= 72) {
      // 3-day view: labels every 12 hours
      return const Duration(hours: 12).inMilliseconds.toDouble();
    } else if (hours <= 168) {
      // 7-day view: labels every 2 days
      return const Duration(days: 2).inMilliseconds.toDouble();
    } else {
      // 30+ day view: labels every week
      return const Duration(days: 7).inMilliseconds.toDouble();
    }
  }

  double _chartHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;
    final h = media.size.height;

    final target = isLandscape ? h * 0.32 : h * 0.28;
    return target.clamp(160.0, isLandscape ? 220.0 : 320.0);
  }

  /// Extract valid data points and calculate stats
  Map<String, dynamic> _processData() {
    final List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    int validCount = 0;

    if (useTimeXAxis) {
      for (int i = 0; i < values.length; i++) {
        final v = values[i];
        final d = (dates != null && i < dates!.length) ? dates![i] : null;
        if (v == null || d == null) continue;

        spots.add(FlSpot(d.millisecondsSinceEpoch.toDouble(), v));
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
        validCount++;
      }
      spots.sort((a, b) => a.x.compareTo(b.x));
    } else {
      for (int i = 0; i < values.length; i++) {
        final v = values[i];
        if (v == null) continue;

        spots.add(FlSpot(i.toDouble(), v));
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
        validCount++;
      }
    }

    return {
      'spots': spots,
      'minY': minY == double.infinity ? 0 : minY,
      'maxY': maxY == double.negativeInfinity ? 1 : maxY,
      'validCount': validCount,
    };
  }

  /// Calculate trend (up/down/neutral)
  String _calculateTrend(List<FlSpot> spots) {
    if (spots.length < 2) return "→";

    final first = spots.first.y;
    final last = spots.last.y;
    final change = ((last - first) / first.abs()) * 100;

    if (change > 5) return "↑ +${change.toStringAsFixed(1)}%";
    if (change < -5) return "↓ ${change.toStringAsFixed(1)}%";
    return "→ Stable";
  }

  @override
  Widget build(BuildContext context) {
    final data = _processData();
    final spots = data['spots'] as List<FlSpot>;
    final minY = data['minY'] as double;
    final maxY = data['maxY'] as double;

    if (spots.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 200,
            child: Center(child: Text("No data available for $title")),
          ),
        ),
      );
    }

    // ✅ Y axis padding
    final yRange = (maxY - minY).abs();
    final yBuffer = yRange == 0 ? 1.0 : yRange * 0.1;
    final paddedMinY = minY - yBuffer;
    final paddedMaxY = maxY + yBuffer;

    // ✅ X axis bounds + dynamic interval
    late final double minX;
    late final double maxX;
    late final double bottomInterval;

    if (useTimeXAxis) {
      final first = DateTime.fromMillisecondsSinceEpoch(spots.first.x.toInt());
      final last = DateTime.fromMillisecondsSinceEpoch(spots.last.x.toInt());

      minX = _floorToHour(first).millisecondsSinceEpoch.toDouble();
      maxX = _ceilToHour(last).millisecondsSinceEpoch.toDouble();
      bottomInterval = _calculateInterval(first, last);
    } else {
      minX = 0;
      maxX = (values.length - 1).toDouble();
      bottomInterval = (values.length / 4).clamp(1, double.infinity);
    }

    final trend = _calculateTrend(spots);
    final chartHeight = _chartHeight(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header with title and trend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.isEmpty ? title : "$title ($unit)",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trend,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: trend.startsWith('↑')
                              ? Colors.green
                              : trend.startsWith('↓')
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // ✅ Min/Max badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatBadge(
                      label: 'Max',
                      value: maxY.toStringAsFixed(1),
                      color: Colors.green,
                    ),
                    const SizedBox(height: 4),
                    _StatBadge(
                      label: 'Min',
                      value: minY.toStringAsFixed(1),
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ Chart with touch feedback
            SizedBox(
              height: chartHeight,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: paddedMinY,
                  maxY: paddedMaxY,
                  clipData: const FlClipData.all(),

                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),

                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),

                    // ✅ Y-axis with unit label
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        unit.isNotEmpty ? unit : '',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      axisNameSize: 20,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),

                    // ✅ Bottom titles with dynamic interval
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: bottomInterval,
                        getTitlesWidget: (value, meta) {
                          if ((value - minX).abs() < bottomInterval / 2) {
                            return const SizedBox();
                          }
                          if ((maxX - value).abs() < bottomInterval / 2) {
                            return const SizedBox();
                          }

                          final label = _formatBottom(value);
                          if (label.isEmpty) return const SizedBox();

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  borderData: FlBorderData(show: false),

                  // ✅ Enhanced touch with visual feedback
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map((s) => LineTooltipItem(
                                _formatTooltip(s),
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ))
                          .toList(),
                    ),
                  ),

                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      // ✅ Show dots on touch
                      dotData: FlDotData(
                        show: _touchedIndex != null,
                        getDotPainter: (spot, percent, barData, index) {
                          if (_touchedIndex == index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: Theme.of(context).primaryColor,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          }
                          return FlDotCirclePainter(
                            radius: 0,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBottom(double x) {
    if (useTimeXAxis) {
      final dt = DateTime.fromMillisecondsSinceEpoch(x.toInt());
      return DateFormat('MMM d\nha').format(dt);
    } else {
      final idx = x.toInt();
      if (dates == null || idx < 0 || idx >= dates!.length) return "";
      final d = dates![idx];
      if (d == null) return "";
      return DateFormat('MMM d\nha').format(d);
    }
  }

  String _formatTooltip(LineBarSpot spot) {
    if (useTimeXAxis) {
      final dt = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
      return "${DateFormat('MMM d, h:mm a').format(dt)}\n"
          "${spot.y.toStringAsFixed(1)} $unit";
    } else {
      final idx = spot.x.toInt();
      DateTime? dt;
      if (dates != null && idx >= 0 && idx < dates!.length) dt = dates![idx];
      final time =
          dt == null ? "" : "${DateFormat('MMM d, h:mm a').format(dt)}\n";
      return "$time${spot.y.toStringAsFixed(1)} $unit";
    }
  }
}