import 'dart:async';
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

  // Optional: if you have a known set of virus names, put them here.
  // You can expand this list anytime.
  final List<String> _knownViruses = const [
    "SARS-CoV-2",
    "COVID",
    "Influenza A",
    "Influenza B",
    "Flu",
    "RSV",
    "Adenovirus",
    "Rhinovirus",
    "Norovirus",
    "Ebola",
    "Dengue",
    "Zika",
    "MERS",
    "H1N1",
    "H5N1",
  ];

  Timer? _debounce;
  String _query = "";

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
    final cleaned =
        sb.toString().replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    return cleaned;
  }

  @override
  void initState() {
    super.initState();
    future = api.fetchEnvPrediction();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _proteinCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => future = api.fetchEnvPrediction());
  }

  void _onVirusChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      setState(() => _query = v.trim());
    });
  }

  Future<void> _predict() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final input = _proteinCtrl.text.trim();
      if (input.isEmpty) {
        setState(() => _error = "Please enter a virus name or protein sequence.");
        return;
      }

      final seq = sanitizeProteinInput(input);
      final loc = _locationCtrl.text.trim().isEmpty
          ? "Kuala Lumpur"
          : _locationCtrl.text.trim();

      final res = await api.fetchVirusPrediction(
        proteinSequence: seq,
        location: loc,
      );

      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Iterable<String> _suggest(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return const Iterable<String>.empty();

    // Prioritize "startsWith" matches, then "contains" matches.
    final starts = _knownViruses
        .where((s) => s.toLowerCase().startsWith(query))
        .toList();
    final contains = _knownViruses
        .where((s) =>
            !s.toLowerCase().startsWith(query) &&
            s.toLowerCase().contains(query))
        .toList();

    return [...starts, ...contains].take(8);
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
          // ✅ Compact search + predicted results
          _VirusAutocompleteField(
            controller: _proteinCtrl,
            hintText: "Type a virus (e.g., Flu, RSV, SARS-CoV-2)…",
            onChanged: _onVirusChanged,
            optionsBuilder: () => _suggest(_query),
            onPicked: (picked) {
              _proteinCtrl.text = picked;
              _onVirusChanged(picked);
            },
            onSearch: _predict,
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
            onPressed: _loading ? null : _predict,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
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
                child: Text(
                  "Error: $_error",
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),

          if (_result != null) _buildResultCards(context, _result!),
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
                Text(
                    "Influenza-like probability: ${(p * 100).toStringAsFixed(1)}%"),
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
}

/// A compact Autocomplete field with a custom dropdown.
class _VirusAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final void Function(String) onChanged;
  final Iterable<String> Function() optionsBuilder;
  final void Function(String) onPicked;
  final VoidCallback onSearch;

  const _VirusAutocompleteField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.optionsBuilder,
    required this.onPicked,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (_) => optionsBuilder(),
      onSelected: onPicked,
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        // Use the shared controller so your existing logic stays intact.
        // Sync Autocomplete’s internal controller with yours.
        if (textCtrl.text != controller.text) {
          textCtrl.value = controller.value;
        }

        return SizedBox(
          height: 44, // ✅ compact height
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: hintText,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? IconButton(
                      tooltip: "Search",
                      onPressed: onSearch,
                      icon: const Icon(Icons.arrow_forward),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: "Clear",
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            controller.clear();
                            onChanged("");
                            FocusScope.of(context).requestFocus(focusNode);
                          },
                        ),
                        IconButton(
                          tooltip: "Search",
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: onSearch,
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final opts = options.toList();
        if (opts.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 520),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: opts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final option = opts[i];
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    leading: const Icon(Icons.bubble_chart_outlined),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
