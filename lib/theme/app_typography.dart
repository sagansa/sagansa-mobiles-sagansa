import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography scale following Material Design 3 principles
class AppTypography {
  // Display styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
  );

  // Headline styles
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.29,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.33,
  );

  // Title styles
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.27,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.50,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );

  // Label styles
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  // Body styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.50,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  // Button styles
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.25,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.33,
  );

  // Caption and overline
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    height: 1.6,
  );

  // Utility methods for colored text
  static TextStyle displayLargeOnSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return displayLarge.copyWith(
      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
    );
  }

  static TextStyle headlineMediumOnSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return headlineMedium.copyWith(
      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
    );
  }

  static TextStyle titleLargeOnSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return titleLarge.copyWith(
      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
    );
  }

  static TextStyle bodyLargeOnSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return bodyLarge.copyWith(
      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
    );
  }

  static TextStyle bodyMediumOnSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return bodyMedium.copyWith(
      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
    );
  }

  static TextStyle labelLargeOnSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return labelLarge.copyWith(
      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
    );
  }

  // Error text styles
  static TextStyle bodyMediumError(BuildContext context) {
    return bodyMedium.copyWith(color: AppColors.error);
  }

  static TextStyle labelMediumError(BuildContext context) {
    return labelMedium.copyWith(color: AppColors.error);
  }

  // Success text styles
  static TextStyle bodyMediumSuccess(BuildContext context) {
    return bodyMedium.copyWith(color: AppColors.success);
  }

  static TextStyle labelMediumSuccess(BuildContext context) {
    return labelMedium.copyWith(color: AppColors.success);
  }
}
