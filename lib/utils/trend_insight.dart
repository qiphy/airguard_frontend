String trendInsight(List<double?> values, {String label = "Value"}) {
  final clean = values.whereType<double>().toList();

  // Need at least 3 values to talk about "rising/falling in last 3 readings"
  if (clean.length < 3) {
    return "Collecting data… (${clean.length}/3 readings).";
  }

  final last3 = clean.sublist(clean.length - 3);

  final rising = last3[2] > last3[1] && last3[1] > last3[0];
  final falling = last3[2] < last3[1] && last3[1] < last3[0];

  if (rising) return "$label is rising in the last 3 readings.";
  if (falling) return "$label is falling in the last 3 readings.";
  return "$label is stable recently.";
}
