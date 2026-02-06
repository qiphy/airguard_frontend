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
    final media = MediaQuery.sizeOf(context);
    final bool isPhone = media.shortestSide < 600;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;

            final double gaugeWidth = width.clamp(260.0, 520.0);
            final double gaugeHeight =
                (gaugeWidth * 0.8).clamp(170.0, 380.0);

            final double posFactor = isPhone ? 0.62 : 0.48;
            final double needleLen = isPhone ? 0.52 : 0.65;
            final double axisLabelOffset = isPhone ? 26 : 22;

            // 🔼 Increased font sizes (bumped for better readability)
            final double aqiFont = isPhone
              ? (gaugeWidth * 0.095).clamp(26.0, 36.0)
              : (gaugeWidth * 0.11).clamp(30.0, 42.0);

            final double catFont = isPhone
              ? (gaugeWidth * 0.07).clamp(16.0, 22.0)
              : (gaugeWidth * 0.085).clamp(18.0, 26.0);

            final double axisFont = isPhone ? 12 : 14;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: isPhone ? 18 : 20,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Last updated: ${updatedAt.toLocal()}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: isPhone ? 13 : 14,
                      ),
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
                          maximum: 502,
                          interval: 50,
                          radiusFactor: 0.9,
                          labelOffset: axisLabelOffset,
                          showTicks: false,
                          showAxisLine: false,
                          startAngle: 180,
                          endAngle: 0,
                          axisLabelStyle: GaugeTextStyle(
                            fontSize: axisFont,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color,
                          ),
                          ranges: <GaugeRange>[
                            GaugeRange(startValue: 0, endValue: 50, color: Colors.green, startWidth: 14, endWidth: 14),
                            GaugeRange(startValue: 50, endValue: 100, color: Colors.yellow, startWidth: 14, endWidth: 14),
                            GaugeRange(startValue: 100, endValue: 150, color: Colors.orange, startWidth: 14, endWidth: 14),
                            GaugeRange(startValue: 150, endValue: 200, color: Colors.red, startWidth: 14, endWidth: 14),
                            GaugeRange(startValue: 200, endValue: 300, color: Colors.purple, startWidth: 14, endWidth: 14),
                            GaugeRange(startValue: 300, endValue: 500, color: const Color(0xFF7E0023), startWidth: 14, endWidth: 14),
                          ],
                          pointers: <GaugePointer>[
                            NeedlePointer(
                              value: value,
                              enableAnimation: true,
                              animationDuration: 900,
                              needleColor:
                                  Theme.of(context).colorScheme.primary,
                              needleLength: needleLen,
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
                              positionFactor: posFactor,
                              widget: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${aqi.toInt()}",
                                    style: TextStyle(
                                      fontSize: aqiFont,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: catFont,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: isPhone ? 13 : 14,
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
