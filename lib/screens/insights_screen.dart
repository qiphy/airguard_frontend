import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart'; // Import
import '../widgets/top_viruses_card.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final _locationService = LocationService();

  Map<String, dynamic>? _result;
  String? _error;
  bool _loading = false;

  final api = ApiService(const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://airguardai.onrender.com',
  ));

  final List<String> _knownViruses = const [
    "SARS-CoV-2", "COVID", "Influenza A", "Influenza B", "Flu", "RSV",
    "Adenovirus", "Rhinovirus", "Norovirus", "Ebola", "Dengue", "Zika",
    "MERS", "H1N1", "H5N1",
  ];

  Timer? _debounce;
  String _query = "";

  late Future<Map<String, dynamic>> future;

  String sanitizeProteinInput(String raw) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final sb = StringBuffer();
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('>')) continue; 
      sb.write(t);
    }
    return sb.toString().replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    future = api.fetchEnvPrediction();
    _autoDetectLocation();
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
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _predict() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final raw = _proteinCtrl.text.trim();
      if (raw.isEmpty) {
        throw Exception("Please enter a virus name or protein sequence.");
      }

      final bool isLikelyName = raw.contains(' ') || raw.length < 25;
      final seq = isLikelyName ? raw : sanitizeProteinInput(raw);

      final loc = _locationCtrl.text.trim().isEmpty
          ? "Kuala Lumpur"
          : _locationCtrl.text.trim();

      final res = await api.fetchVirusPrediction(
        proteinSequence: seq,
        location: loc,
      );

      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _autoDetectLocation() async {
    // Silent check on init
    final city = await _locationService.getCurrentCity(requestPermission: false);
    if (city != null && mounted) {
      _locationCtrl.text = city;
    }
  }

  Future<void> _manualDetectLocation() async {
    // Explicit check on button press
    final city = await _locationService.getCurrentCity(requestPermission: true);
    if (city != null && mounted) {
      _locationCtrl.text = city;
    }
  }

  Iterable<String> _suggest(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return const Iterable<String>.empty();

    final starts = _knownViruses.where((s) => s.toLowerCase().startsWith(query));
    final contains = _knownViruses.where((s) => 
        !s.toLowerCase().startsWith(query) && s.toLowerCase().contains(query));

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
            decoration: InputDecoration(
              labelText: "Location",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Detect location',
                icon: const Icon(Icons.my_location),
                onPressed: _manualDetectLocation,
              ),
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _loading ? null : _predict,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
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

    return LayoutBuilder(builder: (context, constraints) {
      const double minCardWidth = 260;
      const double spacing = 12;
      final double maxW = constraints.maxWidth;

      int perRow = 1;
      if (maxW >= (minCardWidth * 3 + spacing * 2)) {
        perRow = 3;
      } else if (maxW >= (minCardWidth * 2 + spacing)) {
        perRow = 2;
      }

      final double itemWidth = (maxW - spacing * (perRow - 1)) / perRow;

      Widget cardItem(Widget child) => SizedBox(
            width: itemWidth,
            child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: child)),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              cardItem(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Virus similarity", style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text("Influenza-like probability: ${(p * 100).toStringAsFixed(1)}%"),
                ],
              )),
              cardItem(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Environment (AQICN)", style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text("AQI: $aqi"),
                  Text("PM2.5: $pm25"),
                  const SizedBox(height: 8),
                  Text("Env multiplier: ${m.toStringAsFixed(2)}"),
                ],
              )),
              cardItem(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Combined", style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text("Overall risk score: ${overall.toStringAsFixed(3)}"),
                  const SizedBox(height: 8),
                  Text(
                    data["explanation"]?.toString() ?? "",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )),
            ],
          ),
          const SizedBox(height: 12),
          TopVirusesCard(
            data: data['top_viruses'] as List<dynamic>?,
            onRefresh: _reload,
          ),
        ],
      );
    });
  }
}

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
      // Fixed: Use fieldViewBuilder to control the text field properly
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        
        // Only sync if empty to avoid fighting the cursor
        if (textCtrl.text.isEmpty && controller.text.isNotEmpty) {
           textCtrl.text = controller.text;
        }

        return SizedBox(
          height: 44,
          child: TextField(
            controller: textCtrl, // Use Autocomplete's controller here
            focusNode: focusNode,
            onChanged: (val) {
              controller.text = val; // Sync back to parent manually
              onChanged(val);
            },
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: hintText,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: "Search",
                icon: const Icon(Icons.arrow_forward),
                onPressed: onSearch,
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 300), // Fixed width constraint
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
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