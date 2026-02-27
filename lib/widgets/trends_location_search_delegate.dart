import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  // Use your current production backend URL
  final String backendUrl = "https://us-central1-airguardai.cloudfunctions.net/api";

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.length < 2) {
      return const Center(child: Text("Enter at least 2 characters to search"));
    }

    return FutureBuilder<List<dynamic>>(
      future: _performSearch(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No locations found"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final result = snapshot.data![index];
            return ListTile(
              title: Text(result['name'] ?? "Unknown Station"),
              subtitle: Text("Current AQI: ${result['aqi'] ?? 'N/A'}"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => close(context, result),
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>> _performSearch(String keyword) async {
    try {
      final response = await http.get(Uri.parse("$backendUrl?keyword=$keyword"));
      if (response.statusCode == 200) {
        return json.decode(response.body)['results'];
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
    return [];
  }
}