import 'package:flutter/material.dart';

/// Sumber tunggal inset atas untuk halaman ber-appbar transparan
/// (`extendBodyBehindAppBar: true` + `GlassAppBar`).
///
/// Bila dipanggil dari konteks DI DALAM body Scaffold, Scaffold sudah
/// menyuntikkan tinggi appbar (toolbar + widget `bottom`) ke
/// `MediaQuery.padding.top` — nilai itu dipakai apa adanya.
///
/// Bila dipanggil dari konteks halaman (DI ATAS Scaffold, mis. helper
/// State), tinggi appbar belum ada di MediaQuery — dipakai estimasi
/// `kToolbarHeight` di atas status bar.
///
/// Pakai untuk padding atas scrollable teratas agar item pertama tidak
/// tertutup appbar, namun tetap bisa lewat di balik appbar kaca saat
/// di-scroll:
///
/// ```dart
/// ListView(
///   padding: AppSpacing.paddingMD.copyWith(
///     top: AppBarInsets.top(context),
///     bottom: ModernBottomNav.clearance(context),
///   ),
/// )
/// ```
class AppBarInsets {
  AppBarInsets._();

  static double top(BuildContext context, {double bottom = 0.0}) {
    final scaffold = Scaffold.maybeOf(context);
    final mediaTop = MediaQuery.paddingOf(context).top;
    if (scaffold != null && scaffold.hasAppBar) {
      return mediaTop;
    }
    return mediaTop + kToolbarHeight + bottom;
  }
}
