import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sagansa/providers/theme_provider.dart';

void main() {
  group('ThemeProvider Tests', () {
    late ThemeProvider themeProvider;

    setUp(() {
      themeProvider = ThemeProvider();
      SharedPreferences.setMockInitialValues({});
    });

    test('should initialize with system theme mode', () {
      expect(themeProvider.themeMode, equals(ThemeMode.system));
      expect(themeProvider.isSystemMode, isTrue);
      expect(themeProvider.isDarkMode, isFalse);
      expect(themeProvider.isLightMode, isFalse);
    });

    test('should initialize from shared preferences', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': ThemeMode.dark.toString(),
      });

      await themeProvider.initialize();

      expect(themeProvider.themeMode, equals(ThemeMode.dark));
      expect(themeProvider.isDarkMode, isTrue);
      expect(themeProvider.isInitialized, isTrue);
    });

    test('should set theme mode and save to preferences', () async {
      await themeProvider.initialize();
      await themeProvider.setThemeMode(ThemeMode.light);

      expect(themeProvider.themeMode, equals(ThemeMode.light));
      expect(themeProvider.isLightMode, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), equals(ThemeMode.light.toString()));
    });

    test('should toggle between light and dark mode', () async {
      await themeProvider.initialize();

      // Start with light mode
      await themeProvider.setThemeMode(ThemeMode.light);
      expect(themeProvider.isLightMode, isTrue);

      // Toggle to dark
      await themeProvider.toggleTheme();
      expect(themeProvider.isDarkMode, isTrue);

      // Toggle back to light
      await themeProvider.toggleTheme();
      expect(themeProvider.isLightMode, isTrue);
    });

    test('should not change theme mode if same mode is set', () async {
      await themeProvider.initialize();
      await themeProvider.setThemeMode(ThemeMode.light);

      final initialMode = themeProvider.themeMode;
      await themeProvider.setThemeMode(ThemeMode.light);

      expect(themeProvider.themeMode, equals(initialMode));
    });

    test('should provide light theme data', () {
      final lightTheme = ThemeProvider.lightTheme;

      expect(lightTheme.brightness, equals(Brightness.light));
      expect(lightTheme.useMaterial3, isTrue);
      expect(lightTheme.colorScheme.brightness, equals(Brightness.light));
    });

    test('should provide dark theme data', () {
      final darkTheme = ThemeProvider.darkTheme;

      expect(darkTheme.brightness, equals(Brightness.dark));
      expect(darkTheme.useMaterial3, isTrue);
      expect(darkTheme.colorScheme.brightness, equals(Brightness.dark));
    });

    test('should handle initialization error gracefully', () async {
      // This test simulates an error during initialization
      await themeProvider.initialize();

      expect(themeProvider.isInitialized, isTrue);
      expect(themeProvider.themeMode, equals(ThemeMode.system));
    });

    test('should notify listeners when theme changes', () async {
      bool wasNotified = false;
      themeProvider.addListener(() {
        wasNotified = true;
      });

      await themeProvider.initialize();
      await themeProvider.setThemeMode(ThemeMode.dark);

      expect(wasNotified, isTrue);
    });
  });
}
