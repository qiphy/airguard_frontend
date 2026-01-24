class HistoryPoint {
  final double? aqi;
  final double? pm25;
  final DateTime? ts;

  const HistoryPoint({this.aqi, this.pm25, this.ts});

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;

    if (v is String) {
      final dt = DateTime.tryParse(v);
      if (dt == null) return null;

      // If server includes timezone info (e.g. "Z" or "+00:00"),
      // Dart parses it as UTC (dt.isUtc == true). Convert to device local time.
      // If server sends a "naive" timestamp (no timezone), dt.isUtc is false
      // and this returns dt unchanged.
      return dt.isUtc ? dt.toLocal() : dt;
    }

    return null;
  }

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    return HistoryPoint(
      aqi: (json['aqi'] as num?)?.toDouble(),
      pm25: (json['pm25'] as num?)?.toDouble(),
      ts: _parseTs(json['ts']),
    );
  }
}
