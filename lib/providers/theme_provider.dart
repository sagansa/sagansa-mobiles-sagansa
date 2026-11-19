import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;
  Brightness _platformBrightness = Brightness.light;

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Resolves actual dark mode state considering system preference
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return _platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  bool get isLightMode => !isDarkMode;

  ThemeProvider() {
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
      updateSystemOverlayStyle();
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing theme: $e');
      _isInitialized = true;
      updateSystemOverlayStyle();
      notifyListeners();
    }
  }

  /// Synchronize system UI status bar overlay style (transparent status bar,
  /// proper contrast for iOS/Android, nav bar transparan edge-to-edge)
  void updateSystemOverlayStyle() {
    final isDark = isDarkMode;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        // Nav bar transparan: background apps yang terlihat di baliknya
        // (dipasangkan dengan SystemUiMode.edgeToEdge di main()).
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void didChangePlatformBrightness() {
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    // Only notify if in system mode so consumers using isDarkMode update
    if (_themeMode == ThemeMode.system) {
      updateSystemOverlayStyle();
      notifyListeners();
    }
  }

  /// Set theme mode and save to preferences
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    updateSystemOverlayStyle();
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

      // Penting: di Material 3, ThemeData.primaryColor TIDAK otomatis
      // derive dari colorScheme.primary. Kita set eksplisit agar semua
      // widget legacy yang masih memakai Theme.of(context).primaryColor
      // (login_page, menu_card, modern_date_range_picker, dll.) tetap
      // konsisten dengan colorScheme.
      primaryColor: AppColors.primary,

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

      // Typography (warna teks sudah di-inject via lightTextTheme).
      // Ubah AppTypography.lightTextColor / lightMutedColor untuk menyesuaikan.
      textTheme: AppTypography.lightTextTheme,

      // App bar theme - Seragam dengan scaffold background (main)
      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
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
        shadowColor: AppColors.shadow.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          side: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        margin: AppSpacing.paddingMD,
      ),

      // Menu popup (⋮/aksi) — kartu rounded ala grup iOS drawer: sudut
      // membulat, hairline border, shadow lembut; konsisten di seluruh app.
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        elevation: 3,
        shadowColor: AppColors.shadow.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.14),
            width: 0.8,
          ),
        ),
        menuPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.lightTextTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.gold,
          elevation: AppElevation.level1,
          padding:
              AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      // Filled button theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.gold,
          elevation: 0,
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
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
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
          borderSide: BorderSide(
              color: AppColors.outline.withValues(alpha: 0.5), width: 1.5),
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
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),

      // Bottom navigation bar theme - Elegant white with black accents
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: AppElevation.level3,
        // selectedIconTheme dibesarkan sedikit agar item aktif jelas
        // terlihat baik di light maupun dark mode.
        selectedIconTheme: const IconThemeData(
          color: AppColors.primary,
          size: 26,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.onSurfaceVariant,
          size: 24,
        ),
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
        foregroundColor: AppColors.gold,
        elevation: AppElevation.level3,
        shape: CircleBorder(),
      ),

      // Scaffold theme - Clean white background
      scaffoldBackgroundColor: AppColors.background,

      // Divider theme - Subtle dividers
      dividerTheme: DividerThemeData(
        color: AppColors.outlineVariant.withValues(alpha: 0.3),
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
        selectedTileColor: AppColors.primaryContainer.withValues(alpha: 0.1),
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

      // Lihat catatan di lightTheme: set eksplisit agar widget legacy
      // yang memakai Theme.of(context).primaryColor tetap konsisten.
      primaryColor: AppColors.darkPrimary,

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
        error: AppColors.darkError,
        errorContainer: AppColors.darkErrorContainer,
        onError: AppColors.darkOnError,
        onErrorContainer: AppColors.darkOnErrorContainer,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        shadow: AppColors.shadow,
        scrim: AppColors.scrim,
        inverseSurface: AppColors.surface,
        onInverseSurface: AppColors.onSurface,
        inversePrimary: AppColors.primary,
      ),

      // Typography (warna teks sudah di-inject via darkTextTheme).
      // Ubah AppTypography.darkTextColor / darkMutedColor untuk menyesuaikan.
      textTheme: AppTypography.darkTextTheme,

      // App bar theme - Seragam dengan scaffold background (main)
      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
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
        shadowColor: AppColors.shadow.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          side: BorderSide(
            color: AppColors.darkOnSurface.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        margin: AppSpacing.paddingMD,
      ),

      // Menu popup (⋮/aksi) — kartu rounded ala grup iOS drawer (dark).
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.darkSurfaceVariant,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        menuPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.darkTextTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.darkOnSurface,
          ),
        ),
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

      // Filled button theme (dark)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkOnPrimary,
          elevation: 0,
          padding:
              AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      // Outlined button theme (dark) - charcoal text/border
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkOnSurface,
          side: BorderSide(
            color: AppColors.darkOnSurface.withValues(alpha: 0.5),
          ),
          padding:
              AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      // Text button theme (dark)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          padding:
              AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalMD,
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
              color: AppColors.darkOnSurface.withValues(alpha: 0.3),
              width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: BorderSide(
              color: AppColors.darkOnSurface.withValues(alpha: 0.2),
              width: 1.5),
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
          color: AppColors.darkOnSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),

      // Bottom navigation bar theme - Elegant dark with white accents
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.darkOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: AppElevation.level3,
        // selectedIconTheme dibesarkan sedikit agar item aktif jelas
        // terlihat baik di light maupun dark mode.
        selectedIconTheme: const IconThemeData(
          color: AppColors.darkPrimary,
          size: 26,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.darkOnSurfaceVariant,
          size: 24,
        ),
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
        color: AppColors.darkOnSurface.withValues(alpha: 0.2),
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
        selectedTileColor:
            AppColors.darkPrimaryContainer.withValues(alpha: 0.2),
        textColor: AppColors.darkOnSurface,
        iconColor: AppColors.darkOnSurfaceVariant,
      ),
    );
  }
}
