import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../pages/leave_page.dart';
import '../../../pages/procurement_workflow_page.dart';
import '../../../providers/home_dashboard_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

/// Banner tindakan admin untuk persetujuan yang menunggu (Pengadaan & Cuti).
///
/// Membaca [HomeProcurementState.pendingCount] dan
/// [HomeLeaveSalaryState.pendingLeavesCount].
/// Bila tidak ada persetujuan yang pending, widget ini mengembalikan [SizedBox.shrink].
class HomePendingApprovalsCard extends StatelessWidget {
  const HomePendingApprovalsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final pendingProcurement = context.select<HomeDashboardProvider, int>(
      (p) => p.procurement.pendingCount,
    );
    final pendingLeaves = context.select<HomeDashboardProvider, int>(
      (p) => p.leaveSalary.pendingLeavesCount,
    );

    final totalPending = pendingProcurement + pendingLeaves;
    if (totalPending == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingSM,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: isDark ? 0.35 : 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_outlined,
                size: 18,
                color: AppColors.warning,
              ),
              AppSpacing.gapHorizontalXS,
              Text(
                'Perlu Persetujuan',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: AppSpacing.borderRadiusFull,
                ),
                child: Text(
                  '$totalPending Menunggu',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.warning : const Color(0xFFB45309),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalXS,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (pendingProcurement > 0)
                _ApprovalChip(
                  icon: Icons.shopping_bag_outlined,
                  label: '$pendingProcurement Pengadaan',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProcurementWorkflowPage(),
                    ),
                  ),
                ),
              if (pendingLeaves > 0)
                _ApprovalChip(
                  icon: Icons.event_note_outlined,
                  label: '$pendingLeaves Cuti Karyawan',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeavePage()),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ApprovalChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surface,
      borderRadius: AppSpacing.borderRadiusSM,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusSM,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusSM,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
