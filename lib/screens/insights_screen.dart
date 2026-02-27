import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/location_provider.dart';
import '../services/api_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  
  // Autocomplete state
  List<String> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;

  // Analysis state
  bool _isLoading = false;
  String? _error;
  String? _aiInsight;

  @override
  void dispose() {
    _debounce?.cancel();
    _inputCtrl.dispose();
    super.dispose();
  }

  // --- NCBI DIRECT AUTOCOMPLETE LOGIC ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.length < 3) {
      setState(() { _suggestions = []; _isSearching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _fetchNCBISuggestions(query));
  }

Future<void> _fetchNCBISuggestions(String query) async {
  setState(() => _isSearching = true);
  
  try {
    // --- STEP 1: Try your Render Backend First ---
    // This hits the @app.get("/suggest") endpoint in your app.py
    final renderUrl = Uri.parse('https://airguardai.onrender.com/suggest?query=$query');
    final renderRes = await http.get(renderUrl).timeout(const Duration(seconds: 3));

    if (renderRes.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(renderRes.body);
      final List<String> renderSuggestions = List<String>.from(data['suggestions'] ?? []);

      if (renderSuggestions.isNotEmpty) {
        if (mounted) {
          setState(() {
            _suggestions = renderSuggestions;
            _isSearching = false;
          });
          return; // Exit if we found matches in our own DB
        }
      }
    }

    // --- STEP 2: Fallback to NCBI if Render has no matches ---
    final searchUrl = Uri.parse('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=taxonomy&term=$query*&retmode=json&retmax=5');
    final searchRes = await http.get(searchUrl).timeout(const Duration(seconds: 5));
    
    if (searchRes.statusCode == 200) {
      final searchData = json.decode(searchRes.body);
      final ids = List<String>.from(searchData['esearchresult']['idlist'] ?? []);

      if (ids.isNotEmpty) {
        final summaryUrl = Uri.parse('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=taxonomy&id=${ids.join(',')}&retmode=json');
        final summaryRes = await http.get(summaryUrl);
        
        if (summaryRes.statusCode == 200) {
          final summaryData = json.decode(summaryRes.body);
          final result = summaryData['result'] as Map<String, dynamic>;
          final uids = List<String>.from(result['uids'] ?? []);

          List<String> names = [];
          for (var uid in uids) {
            final sciName = result[uid]['scientificname'];
            if (sciName != null) names.add(sciName);
          }

          if (mounted) {
            setState(() { _suggestions = names; _isSearching = false; });
            return;
          }
        }
      }
    }
  } catch (e) {
    debugPrint("Search error: $e");
  }
  
  if (mounted) setState(() => _isSearching = false);
}

  void _selectSuggestion(String value) {
    _inputCtrl.text = value;
    setState(() {
      _suggestions = [];
      _isSearching = false;
    });
  }

// --- AI PREDICTION LOGIC ---
Future<void> _onRunAnalysisPressed() async {
  FocusScope.of(context).unfocus(); 
  setState(() => _suggestions = []); 
  
  final inputRaw = _inputCtrl.text.trim();
  if (inputRaw.isEmpty) {
    setState(() => _error = "Please enter a disease or virus name.");
    return;
  }

  setState(() { 
    _isLoading = true; 
    _error = null; 
    _aiInsight = null;
  });

  try {
    final provider = Provider.of<LocationProvider>(context, listen: false);
    final loc = provider.currentLocation.isEmpty ? "Current Location" : provider.currentLocation;
    
    // --- UPDATED: Extract Temp and Humidity from ApiService instead of LocationProvider ---
    // Make sure these match the static fields or getters in your services/api_service.dart
    final double? currentTemp = ApiService.lastFetchedTemp; 
    final double? currentHumidity = ApiService.lastFetchedHumidity;

    final prompt = """
    Location: $loc.
    Disease: $inputRaw.

    Give me a quick, friendly 3-bullet point list on how to stay safe from $inputRaw in $loc right now.
    Keep it very short. 
    Use friendly language.
    No long explanations.

    Format:
    ### 🚨 Risk: [LOW/MEDIUM/HIGH]
    * [Recommendation 1]
    * [Recommendation 2]
    * [Recommendation 3]
    """;

    const String systemContext = 'You are a friendly health assistant. Provide only short, actionable bullet points. No medical jargon. Keep it brief and encouraging.';

    try {
      // 1. Primary Attempt: Gemini API
      final aiResponse = await ApiService.getGeminiPrediction(prompt, systemContext);
      
      if (mounted) {
        setState(() {
          _aiInsight = aiResponse;
          _isLoading = false;
        });
      }
    } catch (geminiError) {
      debugPrint("Gemini failed, trying local fallback: $geminiError");
      
      // 2. Fallback Attempt: Render Local Model (passing the data from ApiService)
      final fallbackRes = await http.post(
        Uri.parse('https://airguardai.onrender.com/local_insight'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "virus_name": inputRaw,
          "location": loc,
          "temp": currentTemp,      
          "humidity": currentHumidity, 
          "prompt": prompt, 
        }),
      ).timeout(const Duration(seconds: 10));

      if (fallbackRes.statusCode == 200) {
        final data = json.decode(fallbackRes.body);
        if (mounted) {
          setState(() {
            _aiInsight = data['insight'];
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Local fallback failed");
      }
    }

  } catch (e) {
    if (mounted) {
      setState(() {
        _error = "Service unavailable. Please try again later.";
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: const Text("AI Insights", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Search Input Container ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _inputCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  labelText: "Search for an illness (e.g., Influenza, Dengue)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  prefixIcon: const Icon(Icons.health_and_safety_outlined, color: Colors.blueAccent),
                  suffixIcon: _isSearching 
                      ? const UnconstrainedBox(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                ),
                onSubmitted: (_) => _isLoading ? null : _onRunAnalysisPressed(),
              ),
            ),

            // --- RESTORED NCBI SUGGESTIONS LIST ---
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                ),
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_suggestions[index], style: const TextStyle(fontSize: 14)),
                      leading: const Icon(Icons.science, size: 18, color: Colors.blueGrey),
                      onTap: () => _selectSuggestion(_suggestions[index]),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
            
            // --- Location Chip ---
            Consumer<LocationProvider>(
              builder: (context, provider, _) {
                final currentLoc = provider.currentLocation;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    label: Text("Location: $currentLoc", style: const TextStyle(color: Colors.black87)), 
                    avatar: const Icon(Icons.location_on, size: 16, color: Colors.blue)
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            
            // --- Action Button ---
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _onRunAnalysisPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[800],
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.psychology),
                label: Text(_isLoading ? "Asking AI..." : "Get Insights", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),

            // --- Error Display ---
            if (_error != null) 
              Container(
                padding: const EdgeInsets.all(12), 
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200)
                ),
                child: Text("Error: $_error", style: const TextStyle(color: Colors.red)),
              ),

            // --- SIMPLIFIED AI PREDICTION CARD ---
            if (_aiInsight != null) 
              Card(
                elevation: 0,
                color: Colors.blue[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.shade100, width: 1.5)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.health_and_safety, color: Colors.blue[700], size: 24),
                          const SizedBox(width: 12),
                          Text("Health Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue[800])),
                        ],
                      ),
                      Divider(color: Colors.blue.shade200, height: 24),
                      MarkdownBody(
                        data: _aiInsight!,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                          h3: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent), // Pops nicely for Risk Level
                          h4: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), // Cleaner, friendlier subheaders
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}