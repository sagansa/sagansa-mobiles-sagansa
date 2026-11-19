import 'package:flutter/material.dart';

/// Field pencarian full-width untuk AppBar (glass pill).
///
/// Ditampilkan sebagai [GlassAppBar.title] saat mode pencarian expanded —
/// menggantikan judul halaman. Saat collapsed, panggil [BarButtonCluster]
/// dengan aksi search yang memicu expand dari parent.
///
/// Rebuild mengikuti [controller] (via [ValueListenableBuilder]) sehingga
/// tombol clear muncul/hilang tanpa `setState` dari parent.
class BarSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isLoading;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onScan;
  final bool autofocus;

  const BarSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Cari Nomor Resi...',
    this.isLoading = false,
    this.onSubmitted,
    this.onChanged,
    this.onClear,
    this.onScan,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBg = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.65)
        : colorScheme.surface.withValues(alpha: 0.85);
    final effectiveBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
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
        children: [
          const SizedBox(width: 10),
          Icon(Icons.search,
              size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              onSubmitted:
                  onSubmitted != null ? (v) => onSubmitted!(v) : null,
              onChanged: onChanged,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.7),
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value.text.isNotEmpty)
                      _FieldIconButton(
                        icon: Icons.clear,
                        tooltip: 'Hapus',
                        onPressed: onClear,
                      ),
                    if (onScan != null)
                      _FieldIconButton(
                        icon: Icons.qr_code_scanner,
                        tooltip: 'Scan QR/Barcode',
                        onPressed: onScan,
                      )
                    else
                      const SizedBox(width: 10),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FieldIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _FieldIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 19,
        icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
