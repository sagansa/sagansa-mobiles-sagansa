import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 3-tab stage fixed: Request | Invoice | Payment.
///
/// Index:
///   0 = Request
///   1 = Invoice
///   2 = Payment
class ProcurementStageTabs extends StatelessWidget {
  final int activeStage;
  final int requestCount;
  final int invoiceCount;
  final int paymentCount;
  final void Function(int stageIndex)? onTabTap;

  const ProcurementStageTabs({
    super.key,
    required this.activeStage,
    required this.requestCount,
    required this.invoiceCount,
    required this.paymentCount,
    this.onTabTap,
  });

  static const _stageColors = [
    AppColors.warning, // amber - Request
    AppColors.info,    // muted blue - Invoice
    AppColors.success, // green - Payment
  ];

  static const _stageLabels = ['Request', 'Invoice', 'Payment'];
  static const _stageIcons = [
    Icons.shopping_bag_outlined,
    Icons.receipt_long_outlined,
    Icons.payments_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(3, (i) => _buildTab(context, i)),
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isActive = activeStage == index;
    final stageColor = _stageColors[index];
    final count = [requestCount, invoiceCount, paymentCount][index];

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTabTap?.call(index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActive ? stageColor : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _stageIcons[index],
                  size: 15,
                  color: isActive ? stageColor : cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
                Text(
                  _stageLabels[index],
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? stageColor : cs.onSurfaceVariant,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? stageColor.withValues(alpha: 0.15)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? stageColor : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
