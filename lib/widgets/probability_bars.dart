import 'package:flutter/material.dart';

class ProbabilityBars extends StatelessWidget {
  final Map<String, dynamic> probs; // {"LOW":0.7,"MEDIUM":0.2,"HIGH":0.1}

  const ProbabilityBars({super.key, required this.probs});

  /// ✅ Get color for risk level
  Color _getColor(String label) {
    switch (label) {
      case "LOW":
        return Colors.green;
      case "MEDIUM":
        return Colors.orange;
      case "HIGH":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// ✅ Get description for risk level
  String _getDescription(String label) {
    switch (label) {
      case "LOW":
        return "Low Risk — Safe conditions";
      case "MEDIUM":
        return "Moderate Risk — Caution advised";
      case "HIGH":
        return "High Risk — Heightened alert";
      default:
        return label;
    }
  }

  /// ✅ Validate and normalize probabilities
  Map<String, double> _normalizeProbs() {
    final normalized = <String, double>{};
    const order = ["LOW", "MEDIUM", "HIGH"];

    // Extract and validate values
    for (final key in order) {
      final value = probs[key];
      if (value != null) {
        final doubleVal = (value as num).toDouble();
        normalized[key] = doubleVal.clamp(0.0, 1.0);
      } else {
        normalized[key] = 0.0;
      }
    }

    // Handle case where sum is 0
    final sum = normalized.values.fold<double>(0, (a, b) => a + b);
    if (sum == 0) {
      return {"LOW": 0.33, "MEDIUM": 0.33, "HIGH": 0.34};
    }

    return normalized;
  }

  /// ✅ Get the highest probability category
  String _getHighestCategory(Map<String, double> normalized) {
    String highest = "LOW";
    double maxVal = normalized["LOW"] ?? 0;

    for (final entry in normalized.entries) {
      if (entry.value > maxVal) {
        maxVal = entry.value;
        highest = entry.key;
      }
    }

    return highest;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeProbs();
    final highest = _getHighestCategory(normalized);
    final entries = normalized.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Header with title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Risk Assessment",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  "Model probabilities",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            // ✅ Highlight badge for highest risk
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getColor(highest).withOpacity(0.15),
                border: Border.all(
                  color: _getColor(highest).withOpacity(0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                highest,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getColor(highest),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ✅ Probability bars with descriptions
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ProbabilityRow(
              label: e.key,
              probability: e.value,
              color: _getColor(e.key),
              description: _getDescription(e.key),
              isHighest: e.key == highest,
            ),
          ),
      ],
    );
  }
}

/// ✅ Extracted row widget for better organization
class _ProbabilityRow extends StatelessWidget {
  final String label;
  final double probability;
  final Color color;
  final String description;
  final bool isHighest;

  const _ProbabilityRow({
    required this.label,
    required this.probability,
    required this.color,
    required this.description,
    required this.isHighest,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (probability * 100).clamp(0, 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Label row with percentage
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // ✅ Percentage badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "$pct%",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ✅ Progress bar with better styling
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Filled portion with animation potential
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: probability.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isHighest
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
