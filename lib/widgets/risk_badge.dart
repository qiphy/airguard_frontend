import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final String risk; // LOW, MEDIUM, HIGH
  final double confidence; // 0..1
  final String? explanation;

  const RiskBadge({
    super.key,
    required this.risk,
    required this.confidence,
    this.explanation,
  });

  Color _bg(String r) {
    switch (r.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bg(risk);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        border: Border.all(color: bg.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Predicted Risk: ${risk.toUpperCase()}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: bg)),
          const SizedBox(height: 6),
          Text('Confidence: ${(confidence * 100).toStringAsFixed(0)}%'),
          if (explanation != null && explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(explanation!, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ],
      ),
    );
  }
}
