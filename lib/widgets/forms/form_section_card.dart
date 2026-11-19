import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// Kontainer kartu section form yang elegan dan kompak.
///
/// Menyediakan judul terpadu dengan ikon opsional, tombol aksi di kanan (trailing),
/// serta margin/padding yang konsisten di seluruh form aplikasi Sagansa Mobile.
class FormSectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget? child;
  final List<Widget>? children;
  final double fieldSpacing;
  final EdgeInsetsGeometry? padding;

  const FormSectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.child,
    this.children,
    this.fieldSpacing = 10.0,
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
          items.add(SizedBox(height: fieldSpacing));
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
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      size: 18,
                      color: iconColor ?? colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (title != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title!,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
          ],
          content,
        ],
      ),
    );
  }
}
