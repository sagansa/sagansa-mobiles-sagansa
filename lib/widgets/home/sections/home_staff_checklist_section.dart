import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../pages/asset_list_page.dart';
import '../../../pages/closing_store_page.dart';
import '../../../pages/readiness_page.dart';
import '../../../providers/home_dashboard_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

/// Section Checklist Operasional Harian untuk Staff Toko.
///
/// Menampilkan status kesiapan toko (readiness), pengecekan aset, dan closing store.
class HomeStaffChecklistSection extends StatelessWidget {
  const HomeStaffChecklistSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final checklist = context.select<HomeDashboardProvider, HomeStaffChecklistState>(
      (p) => p.staffChecklist,
    );
    final assetState = context.select<HomeDashboardProvider, HomeAssetState>(
      (p) => p.asset,
    );

    final bool isReadinessDone = checklist.hasSubmittedReadiness;
    final bool hasAssetIssue = assetState.overdueCount > 0 || assetState.dueTodayCount > 0;
    final bool hasClosingDraft = checklist.hasActiveClosingDraft;

    return Container(
      padding: AppSpacing.paddingSM,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rtl_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              AppSpacing.gapHorizontalXS,
              Text(
                'Checklist Operasional Harian',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalSM,
          Row(
            children: [
              // 1. Kesiapan Toko
              Expanded(
                child: _ChecklistItem(
                  title: 'Kesiapan',
                  statusText: isReadinessDone ? 'Selesai' : 'Belum Diisi',
                  isSuccess: isReadinessDone,
                  icon: isReadinessDone ? Icons.check_circle : Icons.error_outline,
                  color: isReadinessDone ? AppColors.success : AppColors.warning,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReadinessPage()),
                    );
                    if (context.mounted) {
                      context.read<HomeDashboardProvider>().loadStaffChecklist();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 2. Pengecekan Aset
              Expanded(
                child: _ChecklistItem(
                  title: 'Cek Aset',
                  statusText: assetState.overdueCount > 0
                      ? '${assetState.overdueCount} Lewat'
                      : assetState.dueTodayCount > 0
                          ? '${assetState.dueTodayCount} Hari Ini'
                          : 'Aman',
                  isSuccess: !hasAssetIssue,
                  icon: hasAssetIssue ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: assetState.overdueCount > 0
                      ? colorScheme.error
                      : assetState.dueTodayCount > 0
                          ? AppColors.warning
                          : AppColors.success,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AssetListPage()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 3. Tutup Toko
              Expanded(
                child: _ChecklistItem(
                  title: 'Tutup Toko',
                  statusText: hasClosingDraft ? 'Draft Aktif' : 'Buka',
                  isSuccess: hasClosingDraft,
                  icon: hasClosingDraft ? Icons.edit_note : Icons.store_outlined,
                  color: hasClosingDraft ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ClosingStorePage()),
                    );
                    if (context.mounted) {
                      context.read<HomeDashboardProvider>().loadStaffChecklist();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String title;
  final String statusText;
  final bool isSuccess;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ChecklistItem({
    required this.title,
    required this.statusText,
    required this.isSuccess,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : colorScheme.surfaceContainerLowest,
      borderRadius: AppSpacing.borderRadiusMD,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMD,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusMD,
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icon, size: 13, color: color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                statusText,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
