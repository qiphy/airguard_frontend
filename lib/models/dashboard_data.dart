class DashboardData {
  final String location;
  final num aqi;
  final num pm25;
  final String risk;
  final double confidence;

  DashboardData({
    required this.location,
    required this.aqi,
    required this.pm25,
    required this.risk,
    required this.confidence,
  });

  factory DashboardData.fromApi(
    Map<String, dynamic> latest,
    Map<String, dynamic> predict,
  ) {
    return DashboardData(
      location: latest['location'] ?? 'Kuala Lumpur',
      aqi: latest['aqi'] ?? 0,
      pm25: (latest['pm25'] ?? 0).toDouble(),
      risk: predict['prediction']['risk'] ?? 'UNKNOWN',
      confidence:
          (predict['prediction']['confidence'] ?? 0.0).toDouble(),
    );
  }
}
