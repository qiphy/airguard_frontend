import 'package:flutter/material.dart';
import '../services/api_service.dart';



class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _locationCtrl =
    TextEditingController(text: "Kuala Lumpur");

Map<String, dynamic>? _result;
String? _error;
bool _loading = false;


  final api = ApiService(const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://airguardai.onrender.com',
  ));

  late Future<Map<String, dynamic>> future;

  String sanitizeProteinInput(String raw) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final sb = StringBuffer();

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('>')) continue; // FASTA header
      sb.write(t);
    }

    // Keep letters only (remove digits, spaces, *, -, etc.)
    final cleaned = sb.toString().replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    return cleaned;
  }

  @override
  void initState() {
    super.initState();
    future = api.fetchEnvPrediction();
  }

  void _reload() {
    setState(() => future = api.fetchEnvPrediction());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Insights"),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
body: ListView(
  padding: const EdgeInsets.all(16),
  children: [
    TextField(
      controller: _proteinCtrl,
      maxLines: 10,
      decoration: InputDecoration(
          labelText: "Enter Protein Sequence or Virus Name",
          hintText: "e.g., Covid, Flu, Ebola...",
        ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _locationCtrl,
      decoration: const InputDecoration(
        labelText: "Location (optional)",
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),

    ElevatedButton.icon(
      onPressed: _loading
          ? null
          : () async {
              setState(() {
                _loading = true;
                _error = null;
                _result = null;
              });

              try {
                final seq = sanitizeProteinInput(_proteinCtrl.text);
                final loc = _locationCtrl.text.trim().isEmpty
                    ? "Kuala Lumpur"
                    : _locationCtrl.text.trim();

                if (seq.length < 50) {
                  throw Exception("Protein sequence too short (need >= 50 amino acids).");
                }

                final res = await api.fetchVirusPrediction(
                  proteinSequence: seq,
                  location: loc,
                );

                setState(() {
                  _result = res;
                });
              } catch (e) {
                setState(() {
                  _error = e.toString();
                });
              } finally {
                setState(() {
                  _loading = false;
                });
              }
            },
      icon: _loading
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.psychology),
      label: const Text("Predict (virus + environment)"),
    ),

    const SizedBox(height: 16),

    if (_error != null)
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text("Error: $_error", style: const TextStyle(color: Colors.red)),
        ),
      ),

    if (_result != null) ...[
      _buildResultCards(context, _result!),
    ],

    
  ],
),

    );
  }

  Widget _buildResultCards(BuildContext context, Map<String, dynamic> data) {
  final virus = (data["virus_similarity"] ?? {}) as Map<String, dynamic>;
  final env = (data["environment"] ?? {}) as Map<String, dynamic>;

  final p = ((virus["p_influenza_like"] ?? 0) as num).toDouble();
  final m = ((env["env_multiplier"] ?? 1.0) as num).toDouble();
  final overall = ((data["overall_risk"] ?? 0) as num).toDouble();

  final features = (env["features_used"] ?? {}) as Map<String, dynamic>;
  final aqi = features["aqi"];
  final pm25 = features["pm25"];

  return Column(
    children: [
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Virus similarity",
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text("Influenza-like probability: ${(p * 100).toStringAsFixed(1)}%"),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Environment (AQICN)",
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text("AQI: $aqi"),
              Text("PM2.5: $pm25"),
              const SizedBox(height: 8),
              Text("Env multiplier: ${m.toStringAsFixed(2)}"),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Combined",
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text("Overall risk score: ${overall.toStringAsFixed(3)}"),
              const SizedBox(height: 8),
              Text(
                data["explanation"]?.toString() ?? "",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}


  Widget _riskHeader(BuildContext context, String risk, double confidence) {
    final pct = (confidence * 100).clamp(0, 100).toStringAsFixed(0);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Predicted risk",
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    risk,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text("Confidence: $pct%"),
                ],
              ),
            ),
            const Icon(Icons.psychology, size: 36),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, dynamic v) {
    String text;
    if (v == null) {
      text = "—";
    } else if (v is num) {
      text = v.toStringAsFixed(2);
    } else {
      text = v.toString();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
