import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class AqiGaugeCard extends StatelessWidget {
  final String location;
  final num aqi;
  final DateTime updatedAt;
  final bool isDesktop;

  const AqiGaugeCard({
    super.key,
    required this.location,
    required this.aqi,
    required this.updatedAt,
    this.isDesktop = false,
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

    return Container(
      width: double.infinity,
      color: Colors.transparent, // Let the parent Dashboard box provide the color
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;

          final double gaugeWidth = width.clamp(200.0, 520.0);
          final double gaugeHeight = (gaugeWidth * 0.55).clamp(140.0, 300.0);

          final double needleLen = isPhone ? 0.55 : 0.65;
          final double axisLabelOffset = isPhone ? 20 : 22;

          final double aqiFont = isPhone
              ? (gaugeWidth * 0.12).clamp(36.0, 48.0)
              : (gaugeWidth * 0.11).clamp(30.0, 42.0);

          final double catFont = isPhone
              ? (gaugeWidth * 0.065).clamp(18.0, 24.0)
              : (gaugeWidth * 0.085).clamp(18.0, 26.0);

          final double axisFont = isPhone ? 12 : 14;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // --- FORCED LEFT ALIGN: Location Header ---
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location,
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: isPhone ? 18 : 20,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Last updated: ${updatedAt.toLocal()}",
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: isPhone ? 13 : 14,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- CENTER ALIGN: The Gauge Arc ---
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: gaugeWidth,
                      height: gaugeHeight,
                      child: SfRadialGauge(
                        axes: <RadialAxis>[
                          RadialAxis(
                            centerY: 0.65,
                            minimum: 0,
                            maximum: 502,
                            interval: 100, // Locks scale evenly to 100s
                            radiusFactor: 1.0,
                            labelOffset: axisLabelOffset,
                            showTicks: false,
                            showAxisLine: false,
                            startAngle: 180,
                            endAngle: 0,
                            axisLabelStyle: GaugeTextStyle(
                              fontSize: axisFont,
                              color: Theme.of(context).textTheme.bodySmall?.color,
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
                                needleColor: Theme.of(context).colorScheme.primary,
                                needleLength: needleLen,
                                needleStartWidth: 1.5,
                                needleEndWidth: 6,
                                knobStyle: const KnobStyle(
                                  knobRadius: 0.06,
                                  borderWidth: 0.02,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: Column(
                        children: [
                          Text(
                            "${aqi.toInt()}",
                            style: TextStyle(
                              fontSize: aqiFont,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: catFont,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // --- FORCED LEFT ALIGN: Footer Description ---
              SizedBox(
                width: double.infinity,
                child: Text(
                  "AQI reflects environmental conditions only. Virus similarity and surveillance risk are evaluated separately.",
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: isPhone ? 13 : 14,
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}