import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LineChartCard extends StatelessWidget {
  final String title;
  final List<double?> values;
  final List<DateTime?>? dates;
  final String unit;
  final bool useTimeXAxis;

  // ✅ YOU FORGOT THIS
  final int windowHours;

  const LineChartCard({
    super.key,
    required this.title,
    required this.values,
    this.dates,
    this.unit = "",
    this.useTimeXAxis = true,
    required this.windowHours,
  });

  DateTime _floorToHour(DateTime d) => DateTime(d.year, d.month, d.day, d.hour);

  DateTime _ceilToHour(DateTime d) {
    final floored = _floorToHour(d);
    return d.isAtSameMomentAs(floored)
        ? floored
        : floored.add(const Duration(hours: 1));
  }

  // ✅ Make dropdown change the chart readability
  double _bottomIntervalMsForWindow(int hours) {
    if (hours <= 24) return const Duration(hours: 3).inMilliseconds.toDouble();   // 24h
    if (hours <= 72) return const Duration(hours: 12).inMilliseconds.toDouble();  // 3d
    return const Duration(hours: 24).inMilliseconds.toDouble();                   // 7d
  }

  String _bottomLabelForWindow(DateTime dt, int hours) {
    if (hours <= 24) return DateFormat('ha').format(dt);            // 2PM
    if (hours <= 72) return DateFormat('MMM d\nha').format(dt);     // Jan 24\n2PM
    return DateFormat('MMM d').format(dt);                          // Jan 24
  }

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    // --- Build data points ---
    if (useTimeXAxis) {
      for (int i = 0; i < values.length; i++) {
        final v = values[i];
        final d = (dates != null && i < dates!.length) ? dates![i] : null;
        if (v == null || d == null) continue;

        spots.add(FlSpot(d.millisecondsSinceEpoch.toDouble(), v));
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
      spots.sort((a, b) => a.x.compareTo(b.x));
    } else {
      for (int i = 0; i < values.length; i++) {
        final v = values[i];
        if (v == null) continue;

        spots.add(FlSpot(i.toDouble(), v));
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }

    if (spots.isEmpty) {
      return const SizedBox(height: 200);
    }

    // --- Y axis padding ---
    final yRange = (maxY - minY).abs();
    final yBuffer = yRange == 0 ? 1.0 : yRange * 0.1;

    // --- X axis bounds + interval ---
    late final double minX;
    late final double maxX;
    late final double bottomInterval;

    if (useTimeXAxis) {
      final first = DateTime.fromMillisecondsSinceEpoch(spots.first.x.toInt());
      final last = DateTime.fromMillisecondsSinceEpoch(spots.last.x.toInt());

      minX = _floorToHour(first).millisecondsSinceEpoch.toDouble();
      maxX = _ceilToHour(last).millisecondsSinceEpoch.toDouble();

      // ✅ use dropdown
      bottomInterval = _bottomIntervalMsForWindow(windowHours);
    } else {
      minX = 0;
      maxX = (values.length - 1).toDouble();
      bottomInterval = (values.length / 4).clamp(1, double.infinity);
    }

    String formatBottom(double x) {
      final dt = useTimeXAxis
          ? DateTime.fromMillisecondsSinceEpoch(x.toInt())
          : dates?[x.toInt()];
      if (dt == null) return '';
      return _bottomLabelForWindow(dt, windowHours);
    }

    String formatTooltip(FlSpot spot) {
      final dt = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
      return "${DateFormat('MMM d, h:mm a').format(dt)}\n"
          "${spot.y.toStringAsFixed(1)} $unit";
    }

    final reservedBottom = windowHours <= 24 ? 30.0 : 46.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$title ($unit)",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.5,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY - yBuffer,
                  maxY: maxY + yBuffer,

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
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ),
                    ),

                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: reservedBottom,
                        interval: bottomInterval,
                        getTitlesWidget: (value, meta) {
                          // hide edge labels
                          if ((value - minX).abs() < bottomInterval / 2) {
                            return const SizedBox();
                          }
                          if ((maxX - value).abs() < bottomInterval / 2) {
                            return const SizedBox();
                          }

                          final label = formatBottom(value);
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

                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map((s) => LineTooltipItem(
                                formatTooltip(s),
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
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
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
}
