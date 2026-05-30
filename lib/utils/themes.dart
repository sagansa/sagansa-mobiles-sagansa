import 'package:flutter/material.dart';

class AppTheme {
  // Central Brand Colors (easily changeable in one place!)
  static const Color primaryDark = Color(0xFF121212); // Matte Black background
  static const Color cardDark = Color(0xFF1E1E1E);    // Dark Charcoal card
  static const Color goldAccent = Color(0xFFC5A85A);   // Warm Metallic Gold
  static const Color textLight = Colors.white;
  static const Color textMuted = Colors.white70;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: goldAccent,
      scaffoldBackgroundColor: primaryDark,
      
      colorScheme: const ColorScheme.dark(
        primary: goldAccent,
        secondary: goldAccent,
        surface: cardDark,
        onPrimary: primaryDark,
        onSecondary: primaryDark,
        onSurface: textLight,
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: goldAccent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: goldAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),

      // Text theme
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textLight),
        bodyMedium: TextStyle(color: textMuted),
        bodySmall: TextStyle(color: Colors.grey),
        titleLarge: TextStyle(color: goldAccent, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: textLight),
        titleSmall: TextStyle(color: textMuted),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: goldAccent.withValues(alpha: 0.15), width: 0.5),
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: goldAccent,
      ),

      // Drawer theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: primaryDark,
      ),

      // ListTile theme
      listTileTheme: const ListTileThemeData(
        iconColor: goldAccent,
        textColor: textLight,
      ),

      // FloatingActionButton theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: goldAccent,
        foregroundColor: primaryDark,
      ),

      // Input Decoration theme
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: textMuted),
        prefixIconColor: goldAccent,
        suffixIconColor: goldAccent,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: goldAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      ),

      // ElevatedButton theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldAccent,
          foregroundColor: primaryDark,
          minimumSize: const Size(double.infinity, 45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      
      // TextButton theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: goldAccent,
        ),
      ),

      // Bottom Navigation theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: goldAccent,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
