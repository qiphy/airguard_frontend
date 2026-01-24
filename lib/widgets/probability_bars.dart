import 'package:flutter/material.dart';

class ProbabilityBars extends StatelessWidget {
  final Map<String, dynamic> probs; // {"LOW":0.7,"MEDIUM":0.2,"HIGH":0.1}

  const ProbabilityBars({super.key, required this.probs});

  @override
  Widget build(BuildContext context) {
    final entries = probs.entries
        .map((e) => MapEntry(e.key, (e.value as num).toDouble()))
        .toList();

    // Ensure stable ordering
    const order = ["LOW", "MEDIUM", "HIGH"];
    entries.sort((a, b) => order.indexOf(a.key).compareTo(order.indexOf(b.key)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Model probabilities", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        for (final e in entries) _row(context, e.key, e.value),
      ],
    );
  }

  Widget _row(BuildContext context, String label, double p) {
    final pct = (p * 100).clamp(0, 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label — $pct%"),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: p.clamp(0.0, 1.0),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}
