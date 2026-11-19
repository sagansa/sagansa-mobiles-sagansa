import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';

import 'ios_bar_button.dart';

/// Spesifikasi satu tombol di dalam [BarButtonCluster].
class BarButtonSpec {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final double iconSize;

  /// Jumlah badge (mis. filter aktif). 0 = tanpa badge.
  final int badgeCount;

  /// Bila diisi, segmen menjadi tombol popup-menu (⋮) dengan item-item ini.
  final List<PopupMenuEntry<String>>? popupItems;
  final ValueChanged<String>? onPopupSelected;

  bool get isPopup => popupItems != null;

  const BarButtonSpec({
    required this.icon,
    this.tooltip,
    this.onTap,
    this.iconSize = 20,
    this.badgeCount = 0,
    this.popupItems,
    this.onPopupSelected,
  });
}

/// Kelompok tombol bar gaya iOS dengan glassmorphism.
///
/// - Satu aksi → lingkaran glass ([IosBarButton]).
/// - Lebih dari satu aksi → kapsul glass berisi deretan ikon + divider.
///
/// Padding tepi 14px (kiri untuk leading, kanan untuk actions) agar tombol
/// tidak menempel ke edge layar.
///
/// ```dart
/// actions: [
///   BarButtonCluster(actions: [
///     BarButtonSpec(icon: Icons.search, tooltip: 'Cari', onTap: _expand),
///     BarButtonSpec(icon: Icons.add_rounded, tooltip: 'Tambah', onTap: _create),
///   ]),
/// ],
/// ```
class BarButtonCluster extends StatelessWidget {
  final List<BarButtonSpec> actions;
  final bool isLeading;
  final double size;

  const BarButtonCluster({
    super.key,
    required this.actions,
    this.isLeading = false,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final edgePadding = EdgeInsets.only(
      left: isLeading ? 14 : 0,
      right: isLeading ? 0 : 14,
    );

    if (actions.length == 1) {
      final a = actions.first;
      // Jalur cepat untuk tombol polos; bila ada badge/popup pakai
      // lingkaran yang mendukung keduanya agar konsisten.
      if (a.badgeCount == 0 && !a.isPopup) {
        return Padding(
          padding: edgePadding,
          child: Center(
            child: IosBarButton.icon(
              icon: a.icon,
              onTap: a.onTap,
              tooltip: a.tooltip,
              size: size,
              iconSize: a.iconSize,
            ),
          ),
        );
      }
      return Padding(
        padding: edgePadding,
        child: Center(child: _CircleButton(spec: a, size: size)),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBg = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.65)
        : colorScheme.surface.withValues(alpha: 0.85);
    final effectiveBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Padding(
      padding: edgePadding,
      child: Center(
        child: Container(
          height: size,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            color: effectiveBg,
            border: Border.all(color: effectiveBorder, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 0.8,
                    height: 20,
                    color: effectiveBorder,
                  ),
                _CapsuleButton(spec: actions[i], size: size),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  /// Lingkaran glass 38pt untuk SATU aksi ber-badge/popup.
  final BarButtonSpec spec;
  final double size;

  const _CircleButton({required this.spec, required this.size});

  @override
  Widget build(BuildContext context) {
    Widget circle = spec.badgeCount > 0
        ? IosBarButton.badge(
            icon: spec.icon,
            badgeCount: spec.badgeCount,
            onTap: spec.isPopup ? null : spec.onTap,
            tooltip: spec.tooltip,
            size: size,
            iconSize: spec.iconSize,
          )
        : IosBarButton.icon(
            icon: spec.icon,
            onTap: spec.isPopup ? null : spec.onTap,
            tooltip: spec.isPopup ? null : spec.tooltip,
            size: size,
            iconSize: spec.iconSize,
          );
    if (spec.isPopup) {
      circle = PopupMenuButton<String>(
        tooltip: spec.tooltip,
        padding: EdgeInsets.zero,
        onSelected: spec.onPopupSelected,
        itemBuilder: (_) => spec.popupItems!,
        child: circle,
      );
    }
    return circle;
  }
}

class _CapsuleButton extends StatelessWidget {
  final BarButtonSpec spec;
  final double size;

  const _CapsuleButton({required this.spec, required this.size});

  /// Ikon segmen dengan badge opsional (gaya FilterAppBarAction).
  Widget _icon(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final cs = Theme.of(context).colorScheme;
    final icon = Icon(spec.icon, size: spec.iconSize, color: fg);
    if (spec.badgeCount <= 0) return icon;
    return badges.Badge(
      position: badges.BadgePosition.topEnd(top: -4, end: -4),
      badgeContent: Text(
        spec.badgeCount > 9 ? '9+' : spec.badgeCount.toString(),
        style: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      badgeStyle: badges.BadgeStyle(
        badgeColor: cs.primary,
        padding: const EdgeInsets.all(4),
      ),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular((size - 8) / 2);

    if (spec.isPopup) {
      return PopupMenuButton<String>(
        tooltip: spec.tooltip,
        padding: EdgeInsets.zero,
        onSelected: spec.onPopupSelected,
        itemBuilder: (_) => spec.popupItems!,
        child: SizedBox(
          width: size - 4,
          height: size,
          child: Center(child: _icon(context)),
        ),
      );
    }

    Widget button = Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: spec.onTap,
        child: SizedBox(
          width: size - 4,
          height: size,
          child: Center(child: _icon(context)),
        ),
      ),
    );

    if (spec.tooltip != null) {
      button = Tooltip(message: spec.tooltip!, child: button);
    }
    return button;
  }
}
