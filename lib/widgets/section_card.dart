import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Jarak vertikal setelah divider header (default [AppSpacing.md]).
  /// Halaman padat (mis. detail multi-seksi) boleh mengecilkan.
  final double headerSpacing;
  final VoidCallback? onTap;
  final List<Widget>? actions;

  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
    this.padding,
    this.margin,
    this.headerSpacing = AppSpacing.md,
    this.onTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final card = Card(
      color: colorScheme.surface,
      elevation: 0,
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: padding ?? AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || icon != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (iconColor ?? colorScheme.primary)
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: iconColor ?? colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      AppSpacing.gapHorizontalSM,
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
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            if ((title != null || icon != null) && child is! Divider)
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            if ((title != null || icon != null)) ...[
              SizedBox(height: headerSpacing),
              child,
            ] else
              child,
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLG,
        child: card,
      );
    }

    return card;
  }
}
