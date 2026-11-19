import 'package:flutter/material.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Varian tombol yang konsisten dengan tema Champagne / Obsidian Gold.
/// - [filled]   : tombol utama (bg charcoal + text gold di light,
///                bg gold + text charcoal di dark) via colorScheme.
/// - [outlined] : border + teks mengikuti outlinedButtonTheme.
/// - [text]     : teks mengikuti textButtonTheme.
enum ModernButtonVariant { filled, outlined, text }

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final ModernButtonVariant variant;
  final bool fullWidth;
  final double? height;

  const ModernButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.variant = ModernButtonVariant.filled,
    this.fullWidth = true,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color effectiveBg;
    final Color resolvedForeground;

    switch (variant) {
      case ModernButtonVariant.filled:
        effectiveBg = backgroundColor ?? colorScheme.primary;
        resolvedForeground = foregroundColor ??
            AppButtonStyle.foregroundFor(
              effectiveBg,
              onDarkColor: isDark ? colorScheme.onPrimary : AppColors.gold,
              onLightColor: isDark ? AppColors.darkOnPrimary : AppColors.primary,
            );
        break;
      case ModernButtonVariant.outlined:
        effectiveBg = backgroundColor ?? Colors.transparent;
        resolvedForeground = foregroundColor ??
            (isDark ? colorScheme.onSurface : colorScheme.primary);
        break;
      case ModernButtonVariant.text:
        effectiveBg = backgroundColor ?? Colors.transparent;
        resolvedForeground = foregroundColor ??
            (isDark ? colorScheme.primary : colorScheme.primary);
        break;
    }

    final Widget content = isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: resolvedForeground,
              strokeWidth: 2.5,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: resolvedForeground),
                AppSpacing.gapHorizontalSM,
              ],
              // Flexible + ellipsis: label panjang menyusut rapi, bukan
              // overflow kecil saat ruang tombol mepet (mis. bar aksi bawah).
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: resolvedForeground),
                ),
              ),
            ],
          );

    final baseStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(
        Size(fullWidth ? double.infinity : 0, height ?? 48),
      ),
      // Padding horizontal wajib: tanpa ini tombol non-fullWidth (mis.
      // "Tambah Item" di FormSectionCard) ikon/teksnya menempel garis
      // border sehingga tampak terpotong. Standar sama dengan AppButtonStyle.
      padding: WidgetStateProperty.all(
        AppSpacing.paddingVerticalMD + AppSpacing.paddingHorizontalLG,
      ),
      backgroundColor: variant == ModernButtonVariant.filled
          ? WidgetStateProperty.all(effectiveBg)
          : (backgroundColor != null
              ? WidgetStateProperty.all(backgroundColor)
              : null),
      foregroundColor: WidgetStateProperty.all(resolvedForeground),
      textStyle: WidgetStateProperty.all(
        TextStyle(color: resolvedForeground),
      ),
    );

    switch (variant) {
      case ModernButtonVariant.outlined:
        return OutlinedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  if (!isLoading) onPressed!();
                },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: resolvedForeground),
          ).merge(baseStyle),
          child: content,
        );
      case ModernButtonVariant.text:
        return TextButton(
          onPressed: onPressed == null
              ? null
              : () {
                  if (!isLoading) onPressed!();
                },
          style: baseStyle,
          child: content,
        );
      case ModernButtonVariant.filled:
        return ElevatedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  if (!isLoading) onPressed!();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveBg,
            foregroundColor: resolvedForeground,
          ).merge(baseStyle),
          child: content,
        );
    }
  }
}
