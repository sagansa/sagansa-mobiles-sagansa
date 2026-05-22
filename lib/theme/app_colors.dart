import 'package:flutter/material.dart';

/// Elegant black and white color palette
class AppColors {
  // Primary Colors - Elegant Black
  static const Color primary = Color(0xFF000000);
  static const Color primaryContainer = Color(0xFF2C2C2C);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);

  // Secondary Colors - Elegant Gray
  static const Color secondary = Color(0xFF424242);
  static const Color secondaryContainer = Color(0xFFF5F5F5);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF000000);

  // Surface Colors - Clean White/Gray
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F8F8);
  static const Color onSurface = Color(0xFF000000);
  static const Color onSurfaceVariant = Color(0xFF666666);

  // Background Colors - Pure White
  static const Color background = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF000000);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successContainer = Color(0xFFE8F5E8);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color onSuccessContainer = Color(0xFF1B5E20);

  static const Color warning = Color(0xFFFF9800);
  static const Color warningContainer = Color(0xFFFFF3E0);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color onWarningContainer = Color(0xFFE65100);

  static const Color error = Color(0xFFF44336);
  static const Color errorContainer = Color(0xFFFFEDEA);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFFBA1A1A);

  static const Color info = Color(0xFF2196F3);
  static const Color infoContainer = Color(0xFFE3F2FD);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color onInfoContainer = Color(0xFF0D47A1);

  // Neutral Colors
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);
  static const Color shadow = Color(0xFF000000);
  static const Color scrim = Color(0xFF000000);
  static const Color inverseSurface = Color(0xFF313033);
  static const Color inverseOnSurface = Color(0xFFF4EFF4);
  static const Color inversePrimary = Color(0xFF9ECAFF);

  // Dark Theme Colors - Elegant Dark
  static const Color darkPrimary = Color(0xFFFFFFFF);
  static const Color darkPrimaryContainer = Color(0xFF424242);
  static const Color darkOnPrimary = Color(0xFF000000);
  static const Color darkOnPrimaryContainer = Color(0xFFFFFFFF);

  static const Color darkSecondary = Color(0xFFE0E0E0);
  static const Color darkSecondaryContainer = Color(0xFF2C2C2C);
  static const Color darkOnSecondary = Color(0xFF000000);
  static const Color darkOnSecondaryContainer = Color(0xFFFFFFFF);

  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceVariant = Color(0xFF1E1E1E);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkOnSurfaceVariant = Color(0xFFB0B0B0);

  static const Color darkBackground = Color(0xFF000000);
  static const Color darkOnBackground = Color(0xFFFFFFFF);

  // Gradient Colors - Elegant Black/Gray Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF2C2C2C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, Color(0xFF616161)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF388E3C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Elegant card gradient
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F8F8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Opacity variants
  static Color primaryWithOpacity(double opacity) =>
      primary.withOpacity(opacity);
  static Color secondaryWithOpacity(double opacity) =>
      secondary.withOpacity(opacity);
  static Color surfaceWithOpacity(double opacity) =>
      surface.withOpacity(opacity);
  static Color onSurfaceWithOpacity(double opacity) =>
      onSurface.withOpacity(opacity);
}
