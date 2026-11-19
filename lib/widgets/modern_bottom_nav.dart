import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/presence_model.dart';
import '../pages/home_page.dart';
import '../pages/hrd_dashboard_page.dart';
import '../pages/operational_dashboard_page.dart';
import '../pages/stock_dashboard_page.dart';
import '../pages/transaction_dashboard_page.dart';
import '../theme/app_spacing.dart';
import 'safe_bottom_bar.dart';

/// Tab bar melayang (floating pill capsule) dengan estetika Glassmorphism modern:
/// - Berbentuk kapsul melayang (pill) dengan radius stadium penuh.
/// - Efek kaca beku (frosted glass) translusen dengan blur mendalam (BackdropFilter).
/// - Border specular highlight halus ala Apple glass material.
/// - Floating capsule indicator pada item aktif dengan transisi animasi halus.
/// - Jarak melayang aman dari tepi bawah layar (home indicator / gesture bar).
class ModernBottomNav extends StatelessWidget {
  /// Tinggi konten floating capsule bar (66pt standar floating bar).
  static const double height = 66.0;

  /// Jarak melayang bar dari tepi bawah layar.
  static double bottomMarginOf(BuildContext context) {
    final bottomInset = context.systemBottomInset;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return isIOS
        ? (bottomInset > 0 ? 20.0 : 12.0)
        : (bottomInset > 0 ? bottomInset + 8.0 : 12.0);
  }

  /// Clearance bawah yang WAJIB dipakai sebagai padding bawah scrollable
  /// di semua halaman `extendBody` ber-nav floating, agar item terakhir
  /// tidak tertutup tab bar saat scroll mentok:
  /// ```dart
  /// padding: EdgeInsets.only(
  ///   bottom: ModernBottomNav.clearance(context),
  /// ),
  /// ```
  static double clearance(BuildContext context) =>
      height + bottomMarginOf(context) + context.systemBottomInset;

  final int currentIndex;
  final Function(int) onTap;
  final List<PresenceModel>? presences;

  const ModernBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.presences,
  });

  void _handleNavigation(BuildContext context, int index) {
    if (index == currentIndex) {
      if (Navigator.canPop(context)) {
        HapticFeedback.selectionClick();
        onTap(index);
        Navigator.pop(context);
      }
      return;
    }

    HapticFeedback.selectionClick();
    onTap(index);
    if (!context.mounted) return;

    Widget targetPage;
    switch (index) {
      case 0:
        targetPage = const HomePage();
        break;
      case 1:
        targetPage = const HRDDashboardPage();
        break;
      case 2:
        targetPage = const StockDashboardPage();
        break;
      case 3:
        targetPage = const TransactionDashboardPage();
        break;
      case 4:
        targetPage = const OperationalDashboardPage();
        break;
      default:
        return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final selectedColor = colorScheme.primary;

    // Warna ikon & teks unselected
    final unselectedIconColor = isDark
        ? const Color(0xFFEBEBF5).withValues(alpha: 0.85)
        : const Color(0xFF1C1C1E).withValues(alpha: 0.80);
    final unselectedTextColor = isDark
        ? const Color(0xFFEBEBF5).withValues(alpha: 0.70)
        : const Color(0xFF1C1C1E).withValues(alpha: 0.75);

    // Alpha latar belakang dan blur untuk efek glassmorphism mendalam
    final backgroundAlpha = isDark ? 0.38 : 0.55;
    const blurSigma = 25.0;

    final navItems = [
      (
        icon: CupertinoIcons.house,
        activeIcon: CupertinoIcons.house_fill,
        label: 'Home',
      ),
      (
        icon: CupertinoIcons.person_2,
        activeIcon: CupertinoIcons.person_2_fill,
        label: 'HRD',
      ),
      (
        icon: CupertinoIcons.cube_box,
        activeIcon: CupertinoIcons.cube_box_fill,
        label: 'Stok',
      ),
      (
        icon: CupertinoIcons.doc_text,
        activeIcon: CupertinoIcons.doc_text_fill,
        label: 'Transaksi',
      ),
      (
        icon: CupertinoIcons.gear,
        activeIcon: CupertinoIcons.gear_solid,
        label: 'Ops',
      ),
    ];

    final bottomMargin = bottomMarginOf(context);
    final pillHeight = height - 9.0;
    final pillRadius = pillHeight / 2;

    return SafeArea(
      top: false,
      bottom: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            bottomMargin,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      color: isDark
                          ? const Color(0xFF1C1C1E).withValues(alpha: backgroundAlpha)
                          : Colors.white.withValues(alpha: backgroundAlpha),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.70),
                        width: 0.75,
                      ),
                    ),
                    // Border 0.75 atas+bawah + padding vertikal wajib total 9.0
                    // agar tinggi pill = height - 9.0 (sinkron dgn pillRadius).
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3.75,
                    ),
                    child: Row(
                      children: List.generate(navItems.length, (index) {
                        final item = navItems[index];
                        final isSelected = index == currentIndex;

                        return Expanded(
                          flex: isSelected ? 13 : 10,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _handleNavigation(context, index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark
                                        ? Colors.white.withValues(alpha: 0.20)
                                        : Colors.white.withValues(alpha: 0.88))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(pillRadius),
                                border: isSelected
                                    ? Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.90),
                                        width: 0.5,
                                      )
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.25 : 0.06,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSelected ? item.activeIcon : item.icon,
                                      size: 24,
                                      color: isSelected
                                          ? selectedColor
                                          : unselectedIconColor,
                                    ),
                                    const SizedBox(height: 2),
                                    Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 4),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 10,
                                            height: 1.1,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? selectedColor
                                                : unselectedTextColor,
                                            letterSpacing: -0.24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
