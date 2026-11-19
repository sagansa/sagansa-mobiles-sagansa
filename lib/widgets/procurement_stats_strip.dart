import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Stats horizontal strip di bawah AppBar halaman procurement workflow.
///
/// Menampilkan 3 metrik action:
///   0 = pending approval (request dengan item pending admin approval)
///   1 = siap invoice (request yang belum jadi invoice)
///   2 = siap bayar (invoice siap dibuat payment receipt)
class ProcurementStatsStrip extends StatelessWidget {
  final int pendingApprovalCount;
  final int siapInvoiceCount;
  final int siapBayarCount;
  final void Function(int chipIndex)? onChipTap;

  const ProcurementStatsStrip({
    super.key,
    required this.pendingApprovalCount,
    required this.siapInvoiceCount,
    required this.siapBayarCount,
    this.onChipTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _buildChip(
            context: context,
            index: 0,
            icon: Icons.pending_actions_rounded,
            count: pendingApprovalCount,
            label: 'approval',
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            index: 1,
            icon: Icons.receipt_long_rounded,
            count: siapInvoiceCount,
            label: 'siap invoice',
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            index: 2,
            icon: Icons.payment_rounded,
            count: siapBayarCount,
            label: 'siap bayar',
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required int index,
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    final hasCount = count > 0;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: hasCount ? () => onChipTap?.call(index) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: hasCount
              ? color.withValues(alpha: 0.12)
              : cs.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasCount
                ? color.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: hasCount ? color : cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                color: hasCount ? color : cs.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: hasCount ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
