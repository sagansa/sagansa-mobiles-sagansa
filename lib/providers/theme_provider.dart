import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Initialize theme from shared preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);

      if (savedTheme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedTheme,
          orElse: () => ThemeMode.system,
        );
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing theme: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Set theme mode and save to preferences
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.toString());
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }

  /// Get light theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        onPrimary: AppColors.onPrimary,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondary: AppColors.onSecondary,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        error: AppColors.error,
        errorContainer: AppColors.errorContainer,
        onError: AppColors.onError,
        onErrorContainer: AppColors.onErrorContainer,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        shadow: AppColors.shadow,
        scrim: AppColors.scrim,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
      ),

      // Typography
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.displaySmall,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
      ),

      // App bar theme - Elegant white with black text
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: AppElevation.level1,
        shadowColor: AppColors.shadow.withOpacity(0.1),
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onSurface,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.onSurface,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.onSurface,
          size: 24,
        ),
      ),

      // Card theme - Elegant white cards with subtle shadow
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: AppElevation.level2,
        shadowColor: AppColors.shadow.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          side: BorderSide(
            color: AppColors.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        margin: AppSpacing.paddingMD,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: AppElevation.level1,
          padding:
              AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.outline),
          padding:
              AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding:
              AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalMD,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      // Input decoration theme - Elegant input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: const BorderSide(color: AppColors.outline, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide:
              BorderSide(color: AppColors.outline.withOpacity(0.5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: AppSpacing.paddingMD,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onSurfaceVariant.withOpacity(0.7),
        ),
      ),

      // Bottom navigation bar theme - Elegant white with black accents
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: AppElevation.level3,
        selectedLabelStyle: AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        unselectedLabelStyle: AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w400,
          color: AppColors.onSurfaceVariant,
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: AppElevation.level3,
        shape: CircleBorder(),
      ),

      // Scaffold theme - Clean white background
      scaffoldBackgroundColor: AppColors.background,

      // Divider theme - Subtle dividers
      dividerTheme: DividerThemeData(
        color: AppColors.outlineVariant.withOpacity(0.3),
        thickness: 1,
        space: 1,
      ),

      // List tile theme - Elegant list items
      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.paddingHorizontalMD,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusSM,
        ),
        tileColor: AppColors.surface,
        selectedTileColor: AppColors.primaryContainer.withOpacity(0.1),
        textColor: AppColors.onSurface,
        iconColor: AppColors.onSurfaceVariant,
      ),
    );
  }

  /// Get dark theme data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        onPrimary: AppColors.darkOnPrimary,
        onPrimaryContainer: AppColors.darkOnPrimaryContainer,
        secondary: AppColors.darkSecondary,
        secondaryContainer: AppColors.darkSecondaryContainer,
        onSecondary: AppColors.darkOnSecondary,
        onSecondaryContainer: AppColors.darkOnSecondaryContainer,
        surface: AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        onSurface: AppColors.darkOnSurface,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        error: AppColors.error,
        errorContainer: AppColors.errorContainer,
        onError: AppColors.onError,
        onErrorContainer: AppColors.onErrorContainer,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        shadow: AppColors.shadow,
        scrim: AppColors.scrim,
        inverseSurface: AppColors.surface,
        onInverseSurface: AppColors.onSurface,
        inversePrimary: AppColors.primary,
      ),

      // Typography (same as light theme)
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.displaySmall,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
      ),

      // App bar theme - Elegant dark with white text
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkOnSurface,
        elevation: AppElevation.level1,
        shadowColor: AppColors.shadow.withOpacity(0.3),
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.darkOnSurface,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.darkOnSurface,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.darkOnSurface,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.darkOnSurface,
          size: 24,
        ),
      ),

      // Card theme - Elegant dark cards
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: AppElevation.level2,
        shadowColor: AppColors.shadow.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          side: BorderSide(
            color: AppColors.darkOnSurface.withOpacity(0.1),
            width: 1,
          ),
        ),
        margin: AppSpacing.paddingMD,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkOnPrimary,
          elevation: AppElevation.level1,
          padding:
              AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      // Input decoration theme - Elegant dark input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: BorderSide(
              color: AppColors.darkOnSurface.withOpacity(0.3), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: BorderSide(
              color: AppColors.darkOnSurface.withOpacity(0.2), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: AppSpacing.paddingMD,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.darkOnSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.darkOnSurfaceVariant.withOpacity(0.7),
        ),
      ),

      // Bottom navigation bar theme - Elegant dark with white accents
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.darkOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: AppElevation.level3,
        selectedLabelStyle: AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.darkPrimary,
        ),
        unselectedLabelStyle: AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w400,
          color: AppColors.darkOnSurfaceVariant,
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: AppColors.darkOnPrimary,
        elevation: AppElevation.level3,
        shape: CircleBorder(),
      ),

      // Scaffold theme - Elegant dark background
      scaffoldBackgroundColor: AppColors.darkBackground,

      // Divider theme - Subtle dark dividers
      dividerTheme: DividerThemeData(
        color: AppColors.darkOnSurface.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),

      // List tile theme - Elegant dark list items
      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.paddingHorizontalMD,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusSM,
        ),
        tileColor: AppColors.darkSurface,
        selectedTileColor: AppColors.darkPrimaryContainer.withOpacity(0.2),
        textColor: AppColors.darkOnSurface,
        iconColor: AppColors.darkOnSurfaceVariant,
      ),
    );
  }
}
