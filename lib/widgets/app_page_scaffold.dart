import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'glass_app_bar.dart';
import 'safe_bottom_bar.dart';

/// Scaffold halaman standar Sagansa (hasil refactoring standardisasi).
///
/// Menyatukan pola yang sebelumnya tersebar di 98 halaman:
/// - `GlassAppBar` seragam (judul via [titleText], bukan `Text` mentah)
/// - Body selalu dalam `SafeArea` + padding layar standar ([AppSpacing.screenPadding])
/// - State loading/error/kosong terpusat (bukan `CircularProgressIndicator` / `Text` mentah)
/// - Bar aksi bawah selalu via [SafeBottomBar] agar tidak tertutup nav-bar/home-indicator
/// - BottomNav opsional via [bottomNavigationBar]
///
/// [bottomAction] menerima tombol **mentah** (mis. [FilledButton]/`ModernButton`)
/// — padding dan inset sistem bawah (Android nav bar / iOS home indicator)
/// ditangani [SafeBottomBar]. JANGAN bungkus dengan `SafeArea`/padding sendiri;
/// itu membuat inset terhitung dua kali dan bar jadi terlalu tinggi.
///
/// Pakai untuk semua halaman baru dan migrasi bertahap halaman lama:
/// ```dart
/// AppPageScaffold(
///   titleText: 'Dashboard Penjualan',
///   body: ListView(...),
/// )
/// ```
class AppPageScaffold extends StatelessWidget {
  final String titleText;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final Widget? bottomNavigationBar;
  final Widget? bottomAction;
  final Widget? floatingActionButton;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final EdgeInsetsGeometry? bodyPadding;
  final bool useSafeArea;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isEmpty;
  final Widget? emptyState;

  const AppPageScaffold({
    super.key,
    required this.titleText,
    required this.body,
    this.actions,
    this.leading,
    this.bottom,
    this.bottomNavigationBar,
    this.bottomAction,
    this.floatingActionButton,
    this.extendBody = true,
    this.extendBodyBehindAppBar = true,
    this.bodyPadding,
    this.useSafeArea = false,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.isEmpty = false,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Keyboard terbuka = dorong bar aksi ke atasnya. Scaffold menempel
    // bottomNavigationBar di dasar layar sehingga tombol simpan akan
    // tertutup keyboard tanpa ini; body sudah otomatis menyusut
    // (resizeToAvoidBottomInset).
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    Widget content;
    if (isLoading) {
      content = const SafeArea(
        top: true,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (errorMessage != null) {
      content = SafeArea(
        top: true,
        child: Center(
          child: Padding(
            padding: AppSpacing.paddingLG,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: colorScheme.error,
                  semanticLabel: 'Error',
                ),
                AppSpacing.gapVerticalMD,
                Text(
                  errorMessage!,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  AppSpacing.gapVerticalMD,
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } else if (isEmpty && emptyState != null) {
      content = SafeArea(top: true, child: emptyState!);
    } else {
      content = body;
    }

    final padded = Padding(
      padding: bodyPadding ?? AppSpacing.screenPadding,
      child: content,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: GlassAppBar(
        title: Text(titleText),
        actions: actions,
        leading: leading,
        bottom: bottom,
        // Seamless iOS: tanpa garis, warna = scaffoldBackgroundColor.
        showBottomBorder: false,
      ),
      body: useSafeArea
          ? SafeArea(
              // Default false: konten scroll boleh lewat di balik appbar
              // kaca; scrollable halaman wajib memberi padding atas
              // MediaQuery.paddingOf(context).top (lihat pola clearance).
              top: false,
              child: padded,
            )
          : padded,
      bottomNavigationBar: bottomAction != null
          ? Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Horizontal bar menyamai tepi konten body (screenPadding),
                  // vertikal & inset sistem ditangani SafeBottomBar. Saat
                  // keyboard terbuka, inset sistem dinolkan — sudah tertutup
                  // keyboard (lihat suppressSystemInset).
                  SafeBottomBar(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding.horizontal,
                      vertical: 12,
                    ),
                    suppressSystemInset: keyboardInset > 0,
                    child: bottomAction!,
                  ),
                  if (bottomNavigationBar != null) bottomNavigationBar!,
                ],
              ),
            )
          : bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
