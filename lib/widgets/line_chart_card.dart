// lib/widgets/line_chart_card.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LineChartCard extends StatelessWidget {
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

  DateTime _floorToHour(DateTime d) => DateTime(d.year, d.month, d.day, d.hour);

  DateTime _ceilToHour(DateTime d) {
    final floored = _floorToHour(d);
    return d.isAtSameMomentAs(floored)
        ? floored
        : floored.add(const Duration(hours: 1));
  }

  double _chartHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    // Available height can be short in landscape; clamp for usability.
    // Tune these numbers if you want tighter/looser cards.
    final h = media.size.height;

    // In landscape, keep charts shorter so multiple cards fit without overflow.
    final target = isLandscape ? h * 0.32 : h * 0.28;

    // Clamp: never too tiny, never absurdly tall.
    return target.clamp(160.0, isLandscape ? 220.0 : 320.0);
  }

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    // ----- Build spots -----
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

    // ----- Y axis padding -----
    final yRange = (maxY - minY).abs();
    final yBuffer = yRange == 0 ? 1.0 : yRange * 0.1;

    final paddedMinY = minY - yBuffer;
    final paddedMaxY = maxY + yBuffer;

    // ----- X axis bounds + interval -----
    late final double minX;
    late final double maxX;
    late final double bottomInterval;

    if (useTimeXAxis) {
      final first = DateTime.fromMillisecondsSinceEpoch(spots.first.x.toInt());
      final last = DateTime.fromMillisecondsSinceEpoch(spots.last.x.toInt());

      // Align bounds to whole hours (keeps axis clean)
      minX = _floorToHour(first).millisecondsSinceEpoch.toDouble();
      maxX = _ceilToHour(last).millisecondsSinceEpoch.toDouble();

      // ✅ Labels every 6 hours (data is hourly)
      bottomInterval = const Duration(hours: 6).inMilliseconds.toDouble();
    } else {
      minX = 0;
      maxX = (values.length - 1).toDouble();
      bottomInterval = (values.length / 4).clamp(1, double.infinity);
    }

    String formatBottom(double x) {
      if (useTimeXAxis) {
        final dt = DateTime.fromMillisecondsSinceEpoch(x.toInt());
        // ✅ Date + hour, 2 lines (works across 24h/3d/7d)
        return DateFormat('MMM d\nha').format(dt); // e.g. "Jan 25\n6AM"
      } else {
        final idx = x.toInt();
        if (dates == null || idx < 0 || idx >= dates!.length) return "";
        final d = dates![idx];
        if (d == null) return "";
        return DateFormat('MMM d\nha').format(d);
      }
    }

    String formatTooltip(FlSpot spot) {
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

    final chartHeight = _chartHeight(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),

            // ✅ Responsive height instead of AspectRatio (prevents landscape overflow)
            SizedBox(
              height: chartHeight,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: paddedMinY,
                  maxY: paddedMaxY,

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
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),

                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46, // space for 2-line labels
                        interval: bottomInterval,
                        getTitlesWidget: (value, meta) {
                          // Hide edge labels (prevents clipped/duplicated right-most)
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
                          .map(
                            (s) => LineTooltipItem(
                              formatTooltip(s),
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
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
