import 'package:flutter/material.dart';

class AqiRangeLegend extends StatelessWidget {
  final num aqi;

  const AqiRangeLegend({
    super.key,
    required this.aqi,
  });

  int _activeIndex(double v) {
    if (v <= 50) return 0;
    if (v <= 100) return 1;
    if (v <= 150) return 2;
    if (v <= 200) return 3;
    if (v <= 300) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final double v = aqi.toDouble().clamp(0, 500);
    final active = _activeIndex(v);

    // Keep these consistent with your gauge segments.
    final rows = const [
      _LegendRow("Good", "0–50", Color(0xFF2E7D32)),
      _LegendRow("Moderate", "51–100", Color(0xFFF9A825)),
      _LegendRow("Unhealthy (Sensitive Groups)", "101–150", Color(0xFFEF6C00)),
      _LegendRow("Unhealthy", "151–200", Color(0xFFC62828)),
      _LegendRow("Very Unhealthy", "201–300", Color(0xFF6A1B9A)),
      _LegendRow("Hazardous", "301–500", Color(0xFF4E342E)),
    ];

    return Semantics(
      label: "AQI category legend",
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "AQI Ranges (US)",
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Optional one-liner context
            Text(
              "Current: ${v.toStringAsFixed(0)}",
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.75)),
            ),
            const SizedBox(height: 10),

            ...List.generate(rows.length, (i) {
              final r = rows[i];
              final isActive = i == active;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? cs.primary.withOpacity(0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? cs.primary.withOpacity(0.55) : cs.onSurface.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: r.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      r.range,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: cs.onSurface.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LegendRow {
  final String label;
  final String range;
  final Color color;
  const _LegendRow(this.label, this.range, this.color);
}
