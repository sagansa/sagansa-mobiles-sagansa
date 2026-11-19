import 'package:flutter/material.dart';

/// Inset bawah sistem (Android nav bar / iOS home indicator) dalam logical px.
///
/// Dibaca LANGSUNG dari view engine via [View.of] sehingga **bulletproof**
/// terhadap modifikasi [MediaQuery] oleh ancestor (SafeArea/Scaffold) — yang
/// pernah membuat `MediaQuery.viewPaddingOf` mengembalikan 0 di konteks tertentu
/// (mis. `Scaffold.bottomSheet`) dan menyebabkan bar aksi tertutup nav bar.
///
/// Pakai: `EdgeInsets.only(bottom: context.systemBottomInset)` untuk padding
/// konten custom, atau bungkus bar aksi dengan [SafeBottomBar].
extension SystemBottomInsetX on BuildContext {
  double get systemBottomInset {
    final view = View.of(this);
    return view.viewPadding.bottom / view.devicePixelRatio;
  }
}

/// Bar aksi yang menempel di tepi bawah layar (untuk `Scaffold.bottomSheet`,
/// `bottomNavigationBar`, FAB area, dst.) yang **otomatis** menambahkan inset
/// sistem bawah sehingga isinya tidak pernah tertutup nav bar / home indicator.
///
/// Pakai ini untuk SEMUA bar aksi bawah agar masalah "tertutup nav bar" tidak
/// berulang setiap ada fitur baru.
///
/// JANGAN bungkus [child] dengan `SafeArea` — bar ini sudah menambahkan inset
/// sistem bawah sendiri; SafeArea bersarang membuat inset terhitung dua kali
/// sehingga bar terasa "paddingnya terlalu tinggi". Untuk mencegah hal itu
/// terulang, MediaQuery padding bawah dinolkan untuk child, jadi SafeArea
/// bersarang sekalipun tidak menambahkan inset lagi.
///
/// ```dart
/// Scaffold(
///   bottomSheet: SafeBottomBar(
///     child: Column(mainAxisSize: MainAxisSize.min, children: [ ... ]),
///   ),
/// )
/// ```
class SafeBottomBar extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsets padding;

  /// Tampilkan border atas (pemisah dari konten scroll).
  final bool showTopBorder;

  /// Tampilkan shadow halus di atas bar.
  final bool showShadow;

  /// Nolkan inset sistem bawah. Set true saat bar ini ditata DI ATAS
  /// keyboard (mis. lewat padding viewInsets di AppPageScaffold) — area
  /// home indicator sudah tertutup keyboard; menambahkannya lagi hanya
  /// membuat bar bengkak.
  final bool suppressSystemInset;

  const SafeBottomBar({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.showTopBorder = true,
    this.showShadow = true,
    this.suppressSystemInset = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inset = suppressSystemInset ? 0.0 : context.systemBottomInset;
    return Container(
      width: double.infinity,
      // Padding konten + inset sistem bawah (auto).
      padding: padding.copyWith(bottom: padding.bottom + inset),
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surface,
        border: showTopBorder
            ? Border(
                top:
                    BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
              )
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ]
            : null,
      ),
      // Inset sistem bawah sudah ditambahkan pada padding di atas — nolkan
      // padding bawah MediaQuery untuk child agar SafeArea bersarang tidak
      // menumpuk inset yang sama (penyebab bar terasa terlalu tinggi).
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: child,
      ),
    );
  }
}
