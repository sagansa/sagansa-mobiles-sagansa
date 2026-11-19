import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset_issue_model.dart';
import '../models/asset_model.dart';
import '../providers/asset_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import 'asset_check_form_page.dart';
import 'asset_detail_page.dart';
import 'asset_from_product_page.dart';
import 'asset_issue_page.dart';
import 'asset_list_page.dart';

/// Dashboard modul Manajemen Aset: ringkasan (dueToday/overdue/dueWeek/
/// completion/openIssues) + daftar aset yang jatuh tempo hari ini + akses
/// cepat ke Tugas Check, Semua Aset, dan Issue terbuka.
class AssetDashboardPage extends StatefulWidget {
  const AssetDashboardPage({super.key});

  @override
  State<AssetDashboardPage> createState() => _AssetDashboardPageState();
}

class _AssetDashboardPageState extends State<AssetDashboardPage> {
  Map<String, dynamic>? _summary;
  List<AssetModel> _dueToday = [];
  List<AssetIssueModel> _openIssues = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final provider = context.read<AssetProvider>();
      final summary = await provider.loadDashboardSummary();
      final due = await provider.loadAssets(due: 'today');
      final issues = await provider.loadIssues(status: 1);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _dueToday = due;
        _openIssues = issues;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Manajemen Aset'),
        actions: [
          BarButtonCluster(
            actions: [
              BarButtonSpec(
                icon: Icons.add_rounded,
                iconSize: 22,
                tooltip: 'Tambah Aset',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AssetFromProductPage()),
                  );
                  if (result == true) _loadData();
                },
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _ErrorView(
                  message: _errorMessage!,
                  onRetry: _loadData,
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: AppSpacing.screenPadding.copyWith(
                        top: AppBarInsets.top(context),
                        bottom: ModernBottomNav.clearance(context)),
                    children: [
                      _buildSummaryGrid(theme, colorScheme),
                      SizedBox(height: AppSpacing.sectionGap),
                      _buildQuickActions(theme, colorScheme),
                      SizedBox(height: AppSpacing.sectionGap),
                      _buildDueTodaySection(theme, colorScheme),
                      SizedBox(height: AppSpacing.sectionGap),
                      _buildOpenIssuesSection(theme, colorScheme),
                    ],
                  ),
                ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 2,
        onTap: (index) {
          // Tap selain tab saat ini (Stock=2) → kembali ke home untuk
          // navigasi tab lain. Mengikuti pola ProcurementDashboardPage.
          if (index != 2) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildSummaryGrid(ThemeData theme, ColorScheme colorScheme) {
    final data = _summary ?? {};
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.event_available,
              value: data['due_today'] ?? 0,
              label: 'Hari Ini',
              color: AppColors.warning,
              theme: theme,
              colorScheme: colorScheme,
            ),
          ),
          AppSpacing.gapHorizontalXS,
          Expanded(
            child: _StatTile(
              icon: Icons.warning_amber,
              value: data['overdue'] ?? 0,
              label: 'Terlambat',
              color: AppColors.error,
              theme: theme,
              colorScheme: colorScheme,
            ),
          ),
          AppSpacing.gapHorizontalXS,
          Expanded(
            child: _StatTile(
              icon: Icons.date_range,
              value: data['due_this_week'] ?? 0,
              label: 'Minggu Ini',
              color: AppColors.info,
              theme: theme,
              colorScheme: colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: Icons.fact_check_outlined,
            label: 'Tugas Check',
            colorScheme: colorScheme,
            theme: theme,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AssetListPage(initialDue: 'today'),
                ),
              );
              _loadData();
            },
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.inventory_2_outlined,
            label: 'Semua Aset',
            colorScheme: colorScheme,
            theme: theme,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssetListPage()),
              );
              _loadData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDueTodaySection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Perlu Diperiksa Hari Ini',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_dueToday.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssetListPage(initialDue: 'today'),
                    ),
                  );
                  _loadData();
                },
                child: const Text('Lihat semua'),
              ),
          ],
        ),
        AppSpacing.gapVerticalSM,
        if (_dueToday.isEmpty)
          _EmptyHint(
            icon: Icons.check_circle_outline,
            text: 'Tidak ada aset jatuh tempo hari ini.',
            colorScheme: colorScheme,
            theme: theme,
          )
        else
          ..._dueToday.map((a) => _AssetTile(
                asset: a,
                colorScheme: colorScheme,
                theme: theme,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AssetDetailPage(assetId: a.id),
                    ),
                  );
                  _loadData();
                },
                onCheck: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AssetCheckFormPage(assetId: a.id),
                    ),
                  );
                  if (result == true) _loadData();
                },
              )),
      ],
    );
  }

  Widget _buildOpenIssuesSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Issue Terbuka',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_openIssues.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssetIssuePage(),
                    ),
                  );
                  _loadData();
                },
                child: const Text('Lihat semua'),
              ),
          ],
        ),
        AppSpacing.gapVerticalSM,
        if (_openIssues.isEmpty)
          _EmptyHint(
            icon: Icons.task_alt,
            text: 'Tidak ada issue terbuka.',
            colorScheme: colorScheme,
            theme: theme,
          )
        else
          ..._openIssues.take(5).map((i) => _IssueTile(
                issue: i,
                colorScheme: colorScheme,
                theme: theme,
                onTap: () async {
                  if (i.assetId != 0) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssetDetailPage(assetId: i.assetId),
                      ),
                    );
                    _loadData();
                  }
                },
              )),
      ],
    );
  }
}

// ---- Komponen kecil ----------------------------------------------------

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.theme,
    required this.colorScheme,
  });

  final IconData icon;
  final dynamic value;
  final String label;
  final Color color;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Tinggi fixed — tidak ada kalkulasi aspect ratio, tidak bisa overflow.
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha:0.4),
        borderRadius: AppSpacing.borderRadiusSM,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha:0.4),
        ),
      ),
      child: Row(
        children: [
          // Lingkaran kecil berwarna dengan icon.
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          AppSpacing.gapHorizontalSM,
          // Angka + label bertumpuk, mainAxisSize.min.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value ?? 0}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
      borderRadius: AppSpacing.borderRadiusLG,
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              AppSpacing.gapVerticalXS,
              Text(
                label,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
    required this.onCheck,
  });

  final AssetModel asset;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onCheck;

  Color _dueColor() {
    switch (asset.dueStatus) {
      case 'overdue':
        return AppColors.error;
      case 'today':
        return AppColors.warning;
      case 'upcoming':
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.itemGap),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMD,
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.listItemPadding,
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _dueColor().withValues(alpha:0.15),
                child: Icon(Icons.inventory_2, color: _dueColor(), size: 16),
              ),
              SizedBox(width: AppSpacing.rowGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapVerticalXS,
                    Text(
                      '${asset.code} • ${asset.assetCategoryName ?? '-'} • ${asset.conditionText}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                onPressed: onCheck,
                icon: const Icon(Icons.fact_check, size: 18),
                tooltip: 'Mulai check',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({
    required this.issue,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  final AssetIssueModel issue;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;

  Color _severityColor() {
    switch (issue.severity) {
      case 4:
        return AppColors.error;
      case 3:
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.itemGap),
      child: ListTile(
        contentPadding: AppSpacing.listItemPadding,
        dense: true,
        onTap: onTap,
        title: Text(
          issue.assetName ?? 'Aset #${issue.assetId}',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          issue.description ?? 'Tidak ada deskripsi',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: _severityColor().withValues(alpha:0.15),
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          child: Text(
            issue.severityText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _severityColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.text,
    required this.colorScheme,
    required this.theme,
  });

  final IconData icon;
  final String text;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLG,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.info),
          AppSpacing.gapVerticalSM,
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Bungkus dengan SingleChildScrollView agar konten yang lebih tinggi dari
    // area body (mis. saat bottom nav menyita ruang) tidak overflow.
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            AppSpacing.gapVerticalMD,
            Text(message, textAlign: TextAlign.center),
            AppSpacing.gapVerticalLG,
            ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
