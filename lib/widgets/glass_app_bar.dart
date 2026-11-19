import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'ios_bar_button.dart';

/// AppBar with iOS-style glassmorphism effect (frosted glass).
///
/// Wraps a standard [AppBar] with [BackdropFilter] to create
/// an authentic iOS translucent frosted-glass appearance with
/// subtle hairline bottom border and centered title by default.
///
/// ```dart
/// Scaffold(
///   extendBodyBehindAppBar: true,
///   appBar: GlassAppBar(title: Text('My Page')),
///   body: ...,
/// )
/// ```
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double blurSigma;

  /// Opasitas tint kaca. null = otomatis (0.72 light / 0.55 dark).
  /// Isi eksplisit untuk mengatur intensitas blur-tint.
  final double? opacity;

  /// Bila diisi, appbar jadi SOLID dengan warna ini (tanpa blur) —
  /// dipakai viewer fullscreen dsb. null = kaca translusen default.
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final PreferredSizeWidget? bottom;
  final double? leadingWidth;
  final bool centerTitle;
  final bool showBottomBorder;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final double? toolbarHeight;

  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.blurSigma = 25,
    this.opacity,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
    this.bottom,
    this.leadingWidth,
    this.centerTitle = true,
    // iOS look: tanpa hairline/shadow. Set true hanya bila butuh divider.
    this.showBottomBorder = false,
    this.systemOverlayStyle,
    this.toolbarHeight,
  });

  double get effectiveToolbarHeight =>
      toolbarHeight ?? (title == null ? 44.0 : kToolbarHeight);

  @override
  Size get preferredSize {
    final height = effectiveToolbarHeight + (bottom?.preferredSize.height ?? 0);
    return Size.fromHeight(height);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final effectiveFg = foregroundColor ??
        (isDark ? AppColors.darkOnSurface : colorScheme.onSurface);

    final canPop = ModalRoute.of(context)?.canPop ?? false;
    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && automaticallyImplyLeading && canPop) {
      // Standar global: lingkaran glass + chevron iOS + tooltip 'Kembali',
      // sama seperti IosBarButton.back() di halaman lain. Padding kiri 14px
      // menyamakan inset dengan BarButtonCluster di sisi kanan.
      effectiveLeading = Padding(
        padding: const EdgeInsets.only(left: 14),
        child: IosBarButton.back(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.maybePop(context);
          },
          color: effectiveFg,
        ),
      );
    }

    final effectiveSystemOverlay = systemOverlayStyle ??
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          // Di iOS: Brightness.light berarti background terang -> status bar teks/sinyal GELAP
          // Brightness.dark berarti background gelap -> status bar teks/sinyal TERANG (putih)
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        );

    // Bila backgroundColor eksplisit → appbar SOLID (viewer fullscreen dsb),
    // tanpa blur. Default: kaca translusen di atas konten.
    if (backgroundColor != null) {
      return AppBar(
        systemOverlayStyle: effectiveSystemOverlay,
        toolbarHeight: effectiveToolbarHeight,
        title: title,
        centerTitle: centerTitle,
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 17,
          letterSpacing: -0.4,
          color: effectiveFg,
        ),
        actions: actions,
        leading: effectiveLeading,
        leadingWidth:
            leadingWidth ?? (effectiveLeading != null ? 48 : null),
        automaticallyImplyLeading: false,
        backgroundColor: backgroundColor,
        foregroundColor: effectiveFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        bottom: bottom,
      );
    }

    // iOS liquid glass: appbar translusen + blur — konten scroll TERLIHAT
    // di baliknya (butuh extendBodyBehindAppBar: true di Scaffold halaman).
    // Tint disamakan dengan background dari main (AppColors.background / AppColors.darkBackground)
    final effectiveOpacity =
        (opacity ?? (isDark ? 0.45 : 0.60)).clamp(0.0, 1.0);
    final tint = isDark ? AppColors.darkBackground : AppColors.background;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: effectiveOpacity),
            border: showBottomBorder
                ? Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.darkOnSurface.withValues(alpha: 0.12)
                          : AppColors.onSurface.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: AppBar(
            systemOverlayStyle: effectiveSystemOverlay,
            toolbarHeight: effectiveToolbarHeight,
            title: title,
            centerTitle: centerTitle,
            titleTextStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              letterSpacing: -0.4,
              color: effectiveFg,
            ),
            actions: actions,
            leading: effectiveLeading,
            leadingWidth:
                leadingWidth ?? (effectiveLeading != null ? 48 : null),
            automaticallyImplyLeading: false, // Handled above for iOS style
            backgroundColor: Colors.transparent,
            foregroundColor: effectiveFg,
            elevation: 0,
            scrolledUnderElevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            bottom: bottom,
          ),
        ),
      ),
    );
  }
}
