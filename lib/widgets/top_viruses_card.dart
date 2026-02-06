import 'package:flutter/material.dart';

/// A collapsible card that displays the top possible viruses for a location.
///
/// Expects `data` as a `List` of items where each item is a map with keys:
/// - `name` (String)
/// - `probability` (num, 0..1)
/// If `data` is null or empty, a small placeholder list is shown.
class TopVirusesCard extends StatelessWidget {
  final List<dynamic>? data;
  final VoidCallback? onRefresh;

  const TopVirusesCard({super.key, this.data, this.onRefresh});

  List<Map<String, dynamic>> _fallback() {
    return List.generate(6, (i) {
      final names = [
        'SARS-CoV-2',
        'Influenza A',
        'RSV',
        'Adenovirus',
        'Rhinovirus',
        'Norovirus'
      ];
      return {
        'name': names[i % names.length],
        'probability': (0.25 - i * 0.03).clamp(0.02, 0.9)
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = (data == null || (data is List && data!.isEmpty))
        ? _fallback()
        : List<Map<String, dynamic>>.from(data!.map((e) => Map<String, dynamic>.from(e as Map)));

    return Card(
      elevation: 0,
      child: ExpansionTile(
        title: Text('Top possible viruses', style: Theme.of(context).textTheme.titleSmall),
        initiallyExpanded: false,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'What this means',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('About these predictions'),
                  content: const Text(
                      'These are model-based suggestions showing the most likely virus matches for the provided input and location. Probabilities express relative likelihood and may be uncertain — use them as guidance, not diagnosis.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                  ],
                ),
              ),
            ),
            if (onRefresh != null)
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: onRefresh,
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: List.generate(items.length.clamp(0, 10), (i) {
                final it = items[i];
                final name = (it['name'] ?? 'Unknown').toString();
                final prob = (it['probability'] ?? 0) as num;
                final pct = (prob * 100).toDouble();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 28, child: Text('${i + 1}.', style: Theme.of(context).textTheme.bodyMedium)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(child: Text(name, style: Theme.of(context).textTheme.bodyMedium)),
                                Text('${pct.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: prob.clamp(0, 1).toDouble(),
                                minHeight: 8,
                                backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          )
        ],
      ),
    );
  }
}
