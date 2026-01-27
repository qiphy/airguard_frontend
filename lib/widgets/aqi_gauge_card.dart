import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class AqiGaugeCard extends StatelessWidget {
  final String location;
  final num aqi;
  final DateTime updatedAt;

  const AqiGaugeCard({
    super.key,
    required this.location,
    required this.aqi,
    required this.updatedAt,
  });

  String get category {
    final v = aqi.toDouble();
    if (v <= 50) return "Good";
    if (v <= 100) return "Moderate";
    if (v <= 150) return "Unhealthy for Sensitive Groups";
    if (v <= 200) return "Unhealthy";
    if (v <= 300) return "Very Unhealthy";
    return "Hazardous";
  }

  @override
  Widget build(BuildContext context) {
    final double value = aqi.toDouble().clamp(0, 500).toDouble();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive sizing based on available width.
            // For a semicircle gauge, height ~ 0.6 * width feels balanced.
            final double width = constraints.maxWidth;

            // Clamp so it looks good on both phones and wide desktop cards.
            final double gaugeWidth = width.clamp(260.0, 520.0);
            final double gaugeHeight = (gaugeWidth * 0.62).clamp(170.0, 320.0);

            // Scale text proportionally so it doesn't look tiny/huge.
            final double numberSize = (gaugeWidth * 0.16).clamp(34.0, 64.0);
            final double labelSize = (gaugeWidth * 0.05).clamp(12.0, 16.0);
            final double categorySize = (gaugeWidth * 0.06).clamp(14.0, 18.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  "Last updated: ${updatedAt.toLocal()}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),

                Center(
                  child: SizedBox(
                    width: gaugeWidth,
                    height: gaugeHeight,
                    child: SfRadialGauge(
                      axes: <RadialAxis>[
                        RadialAxis(
                          minimum: 0,
                          maximum: 501,
                          labelOffset: 18,
                          interval: 50,
                          showTicks: false,
                          showAxisLine: false,

                          // Keep a clean semi-circle vibe
                          startAngle: 180,
                          endAngle: 0,

                          axisLabelStyle: GaugeTextStyle(
                            fontSize: (gaugeWidth * 0.03).clamp(10.0, 12.0),
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),

                          ranges: <GaugeRange>[
                            GaugeRange(startValue: 0, endValue: 50, color: Colors.green, startWidth: 14, endWidth: 14),
                            GaugeRange(startValue: 50, endValue: 100, color: Colors.yellow, startWidth: 14, endWidth: 14),
                            GaugeRange(startValue: 100, endValue: 150, color: Colors.orange, startWidth: 14, endWidth: 14),
                            GaugeRange(startValue: 150, endValue: 200, color: Colors.red, startWidth: 14, endWidth: 14),
                            GaugeRange(startValue: 200, endValue: 300, color: Colors.purple, startWidth: 14, endWidth: 14),
                            GaugeRange(
                              startValue: 300,
                              endValue: 500,
                              color: const Color(0xFF7E0023),
                              startWidth: 14,
                              endWidth: 14,
                            ),
                          ],

                          pointers: <GaugePointer>[
                            NeedlePointer(
                              value: value,
                              enableAnimation: true,
                              animationDuration: 900,
                              needleColor: Theme.of(context).colorScheme.primary,
                              needleLength: 0.65,
                              needleStartWidth: 1.5,
                              needleEndWidth: 6,
                              knobStyle: const KnobStyle(
                                knobRadius: 0.06,
                                borderWidth: 0.02,
                              ),
                            ),
                          ],

                          annotations: <GaugeAnnotation>[
                            GaugeAnnotation(
                              angle: 90,
                              positionFactor: 0.45, // lower = closer to bottom of gauge
                              widget: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${aqi.toInt()}",
                                    style: TextStyle(
                                      fontSize: (gaugeWidth * 0.085).clamp(20.0, 28.0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: (gaugeWidth * 0.06).clamp(14.0, 18.0),
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  "AQI reflects environmental conditions only. Virus similarity and surveillance risk are evaluated separately.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
