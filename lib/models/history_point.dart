class HistoryPoint {
  final DateTime ts;
  final int? aqi;
  final double? pm25;

  HistoryPoint({
    required this.ts,
    required this.aqi,
    required this.pm25,
  });

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    return HistoryPoint(
      ts: DateTime.parse(json['ts']),
      aqi: json['aqi'],
      pm25: (json['pm25'] == null) ? null : (json['pm25'] as num).toDouble(),
    );
  }
}
