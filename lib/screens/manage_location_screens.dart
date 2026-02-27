import 'package:flutter/material.dart';

class ManageLocationsScreen extends StatelessWidget {
  const ManageLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> mockLocations = [
      {"name": "Home", "address": "Ipoh, Perak"},
      {"name": "Office", "address": "Cyberjaya, Selangor"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Saved Locations")),
      body: ListView.builder(
        itemCount: mockLocations.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.place, color: Colors.blueAccent),
              title: Text(mockLocations[index]['name']!),
              subtitle: Text(mockLocations[index]['address']!),
              trailing: const Icon(Icons.delete_outline, color: Colors.red),
              onTap: () {},
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text("Add New"),
        icon: const Icon(Icons.add_location_alt),
      ),
    );
  }
}