import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartCard extends StatelessWidget {
  final String title;
  final List<double> values;
  final String unit;

  /// Optional: allow parent (e.g., TrendsScreen) to control height.
  /// If null, this widget auto-sizes based on screen height.
  final double? chartHeight;

  const LineChartCard({
    super.key,
    required this.title,
    required this.values,
    this.unit = "AQI",
    this.chartHeight,
  });

  double _autoChartHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final isPortrait = media.orientation == Orientation.portrait;

    double v = isPortrait ? h * 0.30 : h * 0.55;
    return v.clamp(200.0, 420.0);
  }

  @override
  Widget build(BuildContext context) {
    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    // 1. Calculate actual data bounds safely
    double maxDataY = 100;
    if (values.isNotEmpty) {
      maxDataY = values.reduce((a, b) => a > b ? a : b);
    }

    // 2. FORCE STRICT BOUNDARIES (This fixes the overlapping bug!)
    // We always ground the AQI chart at 0.
    final double safeMinY = 0;
    
    // We create a clean ceiling based on the highest data point.
    // E.g., if max AQI is 72 -> ceiling is 100. If max AQI is 145 -> ceiling is 160.
    double safeMaxY = ((maxDataY / 20).ceil() * 20).toDouble() + 20;
    
    // Never let the chart scale be smaller than 0-100 to prevent layout collapse
    if (safeMaxY < 100) safeMaxY = 100; 

    // Force a strict interval so labels are always evenly spaced (e.g., 20, 40, 60...)
    double safeInterval = safeMaxY / 5;
    if (safeInterval < 20) safeInterval = 20;

    final double h = chartHeight ?? _autoChartHeight(context);
    final bool compact = h < 240;
    final double titleGap = compact ? 12 : 20;
    final double pad = compact ? 14 : 20;

    final bool useCurve = values.length >= 5;

    return Card(
      elevation: 0,
      color: Colors.grey.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: titleGap),

            SizedBox(
              height: h,
              child: LineChart(
                LineChartData(
                  minY: safeMinY,
                  maxY: safeMaxY,

                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          return LineTooltipItem(
                            '${barSpot.y.toInt()} $unit',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),

                  gridData: const FlGridData(show: false),

                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),

                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        // Give labels plenty of horizontal room
                        reservedSize: 40, 
                        // Apply the strict spacing we calculated
                        interval: safeInterval, 
                        getTitlesWidget: (double value, TitleMeta meta) {
                          // Hide the very top label so it doesn't clip the top border
                          if (value == safeMaxY || value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: compact ? 9 : 10,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1, // Show every day
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          if (value < 0 || value >= values.length) return const SizedBox.shrink();
                          
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              "Day ${value.toInt() + 1}",
                              style: TextStyle(
                                fontSize: compact ? 8 : 9,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  borderData: FlBorderData(show: false),

                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: useCurve,
                      color: Colors.blueAccent,
                      barWidth: compact ? 3 : 4,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.blueAccent.withOpacity(0.25),
                            Colors.blueAccent.withOpacity(0.02),
                          ],
                        ),
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