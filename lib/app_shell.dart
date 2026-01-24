import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/trend_screen.dart';
import 'screens/insights_screen.dart';
//import 'screens/alerts_screen.dart';//
//import 'screens/impact_screen.dart';//

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final screens = const [
    DashboardScreen(),
    TrendsScreen(),
    InsightsScreen(),
    //AlertsScreen(),//
    //ImpactScreen(),//
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "Trends"),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: "AI Insights"),
        ],
      ),
    );
  }
}
