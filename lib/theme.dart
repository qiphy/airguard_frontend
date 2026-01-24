import 'package:flutter/material.dart';

ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1976D2),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F8FA),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),

    // ✅ Use CardThemeData for newer Flutter versions
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(0),
    ),
  );
}
