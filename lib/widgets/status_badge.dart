import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum StatusType { success, warning, error, info, neutral }

enum BadgeSize { small, medium }

/// Style variant untuk StatusBadge.
/// - [filled]: background tinted (default, paling umum).
/// - [outline]: border-only, transparent background.
enum StatusBadgeStyle { filled, outline }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final BadgeSize size;
  final StatusBadgeStyle style;

  const StatusBadge({
    super.key,
    String? label,
    String? text,
    this.type = StatusType.neutral,
    this.size = BadgeSize.small,
    this.style = StatusBadgeStyle.filled,
  }) : label = label ?? text ?? '';

  Color _textColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case StatusType.success:
        return AppColors.success;
      case StatusType.warning:
        return AppColors.warning;
      case StatusType.error:
        return cs.error;
      case StatusType.info:
      case StatusType.neutral:
        return AppColors.onSurfaceVariant;
    }
  }

  Color _bgColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case StatusType.success:
        return AppColors.successContainer;
      case StatusType.warning:
        return AppColors.warningContainer;
      case StatusType.error:
        return cs.errorContainer.withValues(alpha: 0.3);
      case StatusType.info:
      case StatusType.neutral:
        return AppColors.surfaceVariant;
    }
  }

  Color _borderColor(BuildContext context) {
    // Outline style pakai warna text dengan alpha.
    return _textColor(context).withValues(alpha: 0.4);
  }

  EdgeInsets _padding() {
    switch (size) {
      case BadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
      case BadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isOutline = style == StatusBadgeStyle.outline;

    return Container(
      padding: _padding(),
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : _bgColor(context),
        borderRadius: AppSpacing.borderRadiusXL,
        border: isOutline
            ? Border.all(color: _borderColor(context), width: 1)
            : null,
      ),
      child: Text(
        label,
        style: (size == BadgeSize.small ? textTheme.labelSmall : textTheme.labelMedium)?.copyWith(
          color: _textColor(context),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
