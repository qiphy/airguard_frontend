import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'manage_location_screens.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // This state persists as long as the widget is in the navigation stack
  bool _isLoggedIn = false; 
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account"), 
        centerTitle: true,
        elevation: 0,
      ),
      // Automatically switches view based on the boolean state
      body: _isLoggedIn ? _buildProfileView() : _buildGuestView(),
    );
  }

  Widget _buildGuestView() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle_outlined, size: 100, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            "Unlock Personal Insights", 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 12),
          const Text(
            "Sign in to save your home location, receive custom AI alerts, and sync data across devices.",
            textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.grey, fontSize: 16)
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () async {
                // Wait for AuthScreen to pop and return a value
                final bool? success = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );

                // If the user successfully logged in (returned true)
                if (success == true) {
                  setState(() {
                    _isLoggedIn = true;
                  });
                  
                  // Optional: Show a nice success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Welcome back, Ahmad!")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Login or Create Account", style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const CircleAvatar(
          radius: 45, 
          backgroundColor: Colors.blueAccent, 
          child: Icon(Icons.person, size: 45, color: Colors.white)
        ),
        const SizedBox(height: 12),
        const Text("Ahmad Razak", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text("ahmad.razak@email.com", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 30),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const Text(
                "PREFERENCES", 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: Colors.grey[100],
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Location Alerts"),
                      secondary: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent),
                      value: _notificationsEnabled,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                    ),
                    ListTile(
                      leading: const Icon(Icons.map_outlined, color: Colors.blueAccent),
                      title: const Text("Manage Saved Locations"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const ManageLocationsScreen())
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Sign Out", style: TextStyle(color: Colors.red)),
                onTap: () {
                  setState(() {
                    _isLoggedIn = false;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}