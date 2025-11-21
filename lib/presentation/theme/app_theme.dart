import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData.light().copyWith(
      primaryColor: Colors.teal,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: Colors.teal,
      colorScheme: const ColorScheme.dark(
        primary: Colors.teal, 
        secondary: Colors.tealAccent
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1F1F1F)),
      cardColor: const Color(0xFF1F1F1F),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Color(0xFF2C2C2C),
      ),
    );
  }
}