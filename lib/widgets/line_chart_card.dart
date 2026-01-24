// lib/widgets/line_chart_card.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LineChartCard extends StatelessWidget {
  final String title;
  final List<double?> values;
  final List<DateTime?>? dates;
  final String unit;

  /// true = real time X axis (millisecondsSinceEpoch)
  /// false = index-based X axis (0..N-1)
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
  Widget build(BuildContext context) {
    // Build spots + Y bounds
    final List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    if (useTimeXAxis) {
      // Time-based: needs dates
      for (int i = 0; i < values.length; i++) {
        final v = values[i];
        final d = (dates != null && i < dates!.length) ? dates![i] : null;
        if (v == null || d == null) continue;

        final x = d.millisecondsSinceEpoch.toDouble();
        spots.add(FlSpot(x, v));

        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }

      // Ensure strictly increasing X
      spots.sort((a, b) => a.x.compareTo(b.x));
    } else {
      // Index-based
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 200,
            child: Center(child: Text("No data available for $title")),
          ),
        ),
      );
    }

    // Y padding
    final yRange = (maxY - minY).abs();
    final buffer = yRange == 0 ? 1.0 : yRange * 0.1;
    final paddedMinY = minY - buffer;
    final paddedMaxY = maxY + buffer;

    // X range from data
    final minX = spots.first.x;
    final maxX = spots.last.x;

    // Bottom label interval (~4 labels)
    final double bottomInterval;
    if (useTimeXAxis) {
      final span = maxX - minX;
      bottomInterval = span <= 0 ? 1 : span / 3;
    } else {
      final n = values.length;
      final every = (n / 4).floor();
      bottomInterval = (every <= 0 ? 1 : every).toDouble();
    }

    String formatBottom(double x) {
      if (useTimeXAxis) {
        final dt = DateTime.fromMillisecondsSinceEpoch(x.toInt());
        return DateFormat('h:mm a').format(dt);
      } else {
        final idx = x.toInt();
        if (dates == null || idx < 0 || idx >= dates!.length) return "";
        final d = dates![idx];
        if (d == null) return "";
        return DateFormat('h:mm a').format(d);
      }
    }

    String formatTooltip(FlSpot spot) {
      if (useTimeXAxis) {
        final dt = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
        final t = DateFormat('h:mm a').format(dt);
        return "$t\n${spot.y.toStringAsFixed(1)} $unit";
      } else {
        final idx = spot.x.toInt();
        String t = "";
        if (dates != null && idx >= 0 && idx < dates!.length) {
          final d = dates![idx];
          if (d != null) t = "${DateFormat('h:mm a').format(d)}\n";
        }
        return "$t${spot.y.toStringAsFixed(1)} $unit";
      }
    }

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.5,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: paddedMinY,
                  maxY: paddedMaxY,

                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (yRange == 0 ? 1 : yRange) / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),

                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          // Skip extreme labels
                          if ((value - paddedMinY).abs() < 1e-9 ||
                              (value - paddedMaxY).abs() < 1e-9) {
                            return const SizedBox();
                          }
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                            textAlign: TextAlign.right,
                          );
                        },
                      ),
                    ),

                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: bottomInterval,
                        getTitlesWidget: (value, meta) {
                          final label = formatBottom(value);
                          if (label.isEmpty) return const SizedBox();

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              label,
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
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((barSpot) {
                          return LineTooltipItem(
                            formatTooltip(barSpot),
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
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
