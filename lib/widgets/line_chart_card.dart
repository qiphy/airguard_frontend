import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartCard extends StatelessWidget {
  final String title;
  final List<double?> values;
  final String unit;

  const LineChartCard({
    super.key,
    required this.title,
    required this.values,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final clean = values.where((v) => v != null).cast<double>().toList();
    final hasData = clean.length >= 2;


    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: hasData
                  ? LineChart(_buildChart(values))
                  : const Center(child: Text("Not enough data yet (need at least 2 points)")),
            ),
            const SizedBox(height: 8),
            Text("Unit: $unit", style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChart(List<double?> values) {
  final spots = <FlSpot>[];
  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (v == null) continue;
    spots.add(FlSpot(i.toDouble(), v));
  }

  // ✅ Guard: if <2 points, return a basic empty chart safely
  if (spots.length < 2) {
    return LineChartData(
      minY: 0,
      maxY: 1,
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          dotData: const FlDotData(show: true),
          barWidth: 3,
        ),
      ],
    );
  }

  double minY = spots.first.y;
  double maxY = spots.first.y;

  for (final s in spots) {
    if (s.y < minY) minY = s.y;
    if (s.y > maxY) maxY = s.y;
  }

  // Add padding so line isn't stuck on edges
  final pad = (maxY - minY) * 0.1;
  if (pad > 0) {
    minY -= pad;
    maxY += pad;
  } else {
    // if all values identical, create a small range
    minY -= 1;
    maxY += 1;
  }

  return LineChartData(
    minY: minY,
    maxY: maxY,
    gridData: const FlGridData(show: true),
    titlesData: const FlTitlesData(show: false),
    borderData: FlBorderData(show: false),
    lineBarsData: [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        dotData: const FlDotData(show: false),
        barWidth: 3,
      ),
    ],
  );
}}
