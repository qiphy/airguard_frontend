class HistoryPoint {
  final double? aqi;
  final double? pm25;
  final DateTime? ts; // Changed from String to DateTime

  HistoryPoint({this.aqi, this.pm25, this.ts});

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    return HistoryPoint(
      aqi: (json['aqi'] as num?)?.toDouble(),
      pm25: (json['pm25'] as num?)?.toDouble(),
      // Automatically parses "2026-01-24T10:00:00" into a Date object
      ts: json['ts'] != null ? DateTime.tryParse(json['ts']) : null,
    );
  }
}