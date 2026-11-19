import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// Kontainer kartu section detail yang kompak dan rapi untuk halaman detail order & transaksi.
///
/// Menyediakan header dengan ikon berlatar warna halus, judul, opsional trailing widget
/// (mis. status badge atau tombol aksi), serta padding yang teroptimasi tanpa dead space.
class DetailSectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget? child;
  final List<Widget>? children;
  final double itemSpacing;
  final EdgeInsetsGeometry? padding;

  const DetailSectionCard({
    super.key,
    this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.child,
    this.children,
    this.itemSpacing = 8.0,
    this.padding,
  }) : assert(child != null || children != null,
            'Harus menyediakan salah satu dari child atau children');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final hasHeader = title != null || icon != null || trailing != null;

    Widget content;
    if (children != null) {
      final items = <Widget>[];
      for (var i = 0; i < children!.length; i++) {
        items.add(children![i]);
        if (i < children!.length - 1) {
          items.add(SizedBox(height: itemSpacing));
        }
      }
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: items,
      );
    } else {
      content = child!;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      padding: padding ?? const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (iconColor ?? colorScheme.primary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 17,
                      color: iconColor ?? colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10),
          ],
          content,
        ],
      ),
    );
  }
}
