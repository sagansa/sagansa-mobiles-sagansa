import 'package:badges/badges.dart' as badges;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Tombol bar (AppBar/Navigation) bergaya iOS (circular translucent pill).
///
/// Digunakan seragam untuk leading icon (Back/Drawer/Logo) dan trailing actions
/// (Notifikasi, Toggle Tema, Filter, Options) di seluruh aplikasi.
class IosBarButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final int badgeCount;

  const IosBarButton({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.size = 38,
    this.backgroundColor,
    this.borderColor,
    this.badgeCount = 0,
  });

  /// Factory untuk tombol berbasis Icon sederhana.
  factory IosBarButton.icon({
    Key? key,
    required IconData icon,
    required VoidCallback? onTap,
    String? tooltip,
    double size = 38,
    double iconSize = 20,
    Color? color,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return IosBarButton(
      key: key,
      size: size,
      onTap: onTap,
      tooltip: tooltip,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Builder(
        builder: (context) {
          final fg = color ?? Theme.of(context).colorScheme.onSurface;
          return Icon(icon, size: iconSize, color: fg);
        },
      ),
    );
  }

  /// Factory untuk tombol berbasis Icon dengan Badge Counter notifikasi.
  factory IosBarButton.badge({
    Key? key,
    required IconData icon,
    required int badgeCount,
    required VoidCallback? onTap,
    String? tooltip,
    double size = 38,
    double iconSize = 20,
    Color? color,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return IosBarButton(
      key: key,
      size: size,
      onTap: onTap,
      tooltip: tooltip,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      badgeCount: badgeCount,
      child: Builder(
        builder: (context) {
          final fg = color ?? Theme.of(context).colorScheme.onSurface;
          return Icon(icon, size: iconSize, color: fg);
        },
      ),
    );
  }

  /// Factory tombol tambah (+) gaya iOS untuk aksi create di kanan atas
  /// AppBar — standar pengganti floating AddFab/FloatingActionButton.
  ///
  /// ```dart
  /// actions: [
  ///   if (canManage) IosBarButton.add(onTap: _openForm, tooltip: 'Tambah Supplier'),
  /// ]
  /// ```
  factory IosBarButton.add({
    Key? key,
    required VoidCallback? onTap,
    String tooltip = 'Tambah',
    double size = 38,
    double iconSize = 22,
    Color? color,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return IosBarButton.icon(
      key: key,
      icon: Icons.add_rounded,
      onTap: onTap,
      tooltip: tooltip,
      size: size,
      iconSize: iconSize,
      color: color,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
    );
  }

  /// Factory tombol kembali (lingkaran glass) — pengganti `IconButton`
  /// mentah agar konsisten dengan tombol bar lainnya.
  ///
  /// ```dart
  /// leading: IosBarButton.back(onTap: provider.clearSelection),
  /// ```
  factory IosBarButton.back({
    Key? key,
    required VoidCallback? onTap,
    String tooltip = 'Kembali',
    double size = 34,
    double iconSize = 20,
    Color? color,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return IosBarButton(
      key: key,
      size: size,
      onTap: onTap,
      tooltip: tooltip,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Builder(
        builder: (context) {
          final fg = color ?? Theme.of(context).colorScheme.onSurface;
          return Icon(CupertinoIcons.chevron_back,
              size: iconSize, color: fg);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBg = backgroundColor ??
        (isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.65)
            : colorScheme.surface.withValues(alpha: 0.85));
    final effectiveBorder = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08));

    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
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
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    if (badgeCount > 0) {
      return badges.Badge(
        position: badges.BadgePosition.topEnd(top: -2, end: -2),
        badgeContent: Text(
          badgeCount > 99 ? '99+' : '$badgeCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        badgeStyle: const badges.BadgeStyle(
          padding: EdgeInsets.all(4),
        ),
        child: button,
      );
    }

    // onTap null = disabled (mis. sedang proses atau aksi dikunci):
    // redupkan agar status non-aktif terlihat, bukan hanya tak respons.
    if (onTap == null) {
      return Opacity(opacity: 0.35, child: button);
    }

    return button;
  }
}
