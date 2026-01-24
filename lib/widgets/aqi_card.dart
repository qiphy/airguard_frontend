import 'package:flutter/material.dart';

class AQICard extends StatelessWidget {
  final String location;
  final num aqi;
  final String status;
  final DateTime updatedAt;

  const AQICard({
    super.key,
    required this.location,
    required this.aqi,
    required this.status,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(location, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('AQI: $aqi', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(status),
            const SizedBox(height: 8),
            Text('Last updated: ${updatedAt.toLocal()}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
