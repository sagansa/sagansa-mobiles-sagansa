import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Helper terpusat untuk styling tombol (FilledButton, ElevatedButton, OutlinedButton, TextButton).
/// Memastikan tidak akan pernah terjadi teks hitam di atas background hitam (atau putih di atas putih).
class AppButtonStyle {
  AppButtonStyle._();

  /// Menghitung warna foreground (teks & ikon) dengan kontras tinggi secara otomatis
  /// berdasarkan brightness warna latar belakang [bgColor].
  static Color foregroundFor(
    Color bgColor, {
    Color? onDarkColor,
    Color? onLightColor,
  }) {
    final brightness = ThemeData.estimateBrightnessForColor(bgColor);
    if (brightness == Brightness.dark) {
      return onDarkColor ?? Colors.white;
    } else {
      return onLightColor ?? AppColors.primary;
    }
  }

  /// Utility membuat `ButtonStyle` untuk `FilledButton` dengan garansi kontras warna.
  static ButtonStyle filled({
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry? borderRadius,
    Size? minimumSize,
    double? elevation,
  }) {
    final bg = backgroundColor ?? AppColors.primary;
    final fg = foregroundColor ?? foregroundFor(bg);
    return FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: elevation ?? 0,
      padding: padding ??
          (AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? AppSpacing.borderRadiusMD,
      ),
      minimumSize: minimumSize,
      textStyle: AppTypography.buttonMedium,
    );
  }

  /// Utility membuat `ButtonStyle` untuk `ElevatedButton` dengan garansi kontras warna.
  static ButtonStyle elevated({
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry? borderRadius,
    Size? minimumSize,
    double? elevation,
  }) {
    final bg = backgroundColor ?? AppColors.primary;
    final fg = foregroundColor ?? foregroundFor(bg);
    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: elevation ?? AppElevation.level1,
      padding: padding ??
          (AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? AppSpacing.borderRadiusMD,
      ),
      minimumSize: minimumSize,
      textStyle: AppTypography.buttonMedium,
    );
  }

  /// Utility membuat `ButtonStyle` untuk `TextButton` (aksi teks padat).
  ///
  /// Semua parameter opsional dipetakan 1:1 ke `TextButton.styleFrom` agar
  /// konversi dari gaya mentah tidak mengubah tampilan/density.
  ///
  /// `foregroundColor` null (default) TIDAK menimpa warna tema — tombol
  /// memakai `textButtonTheme` per-mode (light: AppColors.primary,
  /// dark: AppColors.darkPrimary). Hardcode default light-mode pernah
  /// membuat teks "Tambah" tak terlihat di dark mode.
  static ButtonStyle text({
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
  }) {
    return TextButton.styleFrom(
      foregroundColor: foregroundColor,
      padding: padding,
      minimumSize: minimumSize,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      textStyle: AppTypography.buttonMedium,
    );
  }

  /// Utility membuat `ButtonStyle` untuk `OutlinedButton`.
  static ButtonStyle outlined({    Color? foregroundColor,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry? borderRadius,
    Size? minimumSize,
  }) {
    final fg = foregroundColor ?? AppColors.primary;
    return OutlinedButton.styleFrom(
      foregroundColor: fg,
      side: BorderSide(
        color: borderColor ?? fg.withValues(alpha: 0.5),
      ),
      padding: padding ??
          (AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? AppSpacing.borderRadiusMD,
      ),
      minimumSize: minimumSize,
      textStyle: AppTypography.buttonMedium,
    );
  }
}
