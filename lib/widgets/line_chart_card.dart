import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LineChartCard extends StatelessWidget {
  final String title;
  final List<double?> values;
  final List<DateTime?>? dates;
  final String unit;

  const LineChartCard({
    super.key,
    required this.title,
    required this.values,
    this.dates,
    this.unit = "",
  });

  @override
  Widget build(BuildContext context) {
    // 1. Prepare the data spots
    // We filter out null values but keep the X-index consistent
    final List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) {
        spots.add(FlSpot(i.toDouble(), v));
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }

    // 2. Handle empty data case
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

    // 3. Add some padding to the Y-axis so the line isn't stuck to the edge
    final double yRange = maxY - minY;
    // Avoid division by zero if all values are the same
    final double buffer = yRange == 0 ? 1.0 : yRange * 0.1; 
    minY -= buffer;
    maxY += buffer;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Text(
              "$title ($unit)",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // The Chart
            AspectRatio(
              aspectRatio: 1.5,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (values.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  
                  // Grid Lines
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (yRange == 0 ? 1 : yRange) / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),

                  // Axis Titles (Labels)
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    
                    // LEFT AXIS (Numbers)
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == minY || value == maxY) return const SizedBox();
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                            textAlign: TextAlign.right,
                          );
                        },
                      ),
                    ),

                    // BOTTOM AXIS (Time)
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        // Show roughly 4 labels across the width
                        interval: (values.length / 4).floorToDouble(), 
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          
                          // Safety check for index out of bounds
                          if (dates == null || index < 0 || index >= dates!.length) {
                            return const SizedBox();
                          }

                          final date = dates![index];
                          if (date == null) return const SizedBox();

                          // Format the time (e.g., 10:30 AM)
                          final formatted = DateFormat('h:mm a').format(date);
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              formatted,
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

                  // Border
                  borderData: FlBorderData(show: false),

                  // Tooltip (Touch behavior)
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          String timeLabel = "";
                          if (dates != null && index >= 0 && index < dates!.length) {
                            final d = dates![index];
                            if (d != null) {
                              timeLabel = DateFormat('h:mm a').format(d) + "\n";
                            }
                          }
                          return LineTooltipItem(
                            "$timeLabel${spot.y.toStringAsFixed(1)} $unit",
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                  ),

                  // The Actual Line
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false), // Hide dots for cleaner look
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