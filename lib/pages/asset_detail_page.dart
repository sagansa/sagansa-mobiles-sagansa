import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../models/asset_check_model.dart';
import '../models/asset_issue_model.dart';
import '../models/asset_model.dart';
import '../providers/asset_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_fab.dart';
import 'asset_check_form_page.dart';

/// Detail profil aset: info, kondisi, jadwal, riwayat check & issue.
class AssetDetailPage extends StatefulWidget {
  const AssetDetailPage({super.key, required this.assetId});

  final int assetId;

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  AssetModel? _asset;
  List<AssetCheckModel> _checks = [];
  List<AssetIssueModel> _issues = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _load();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final userData = json.decode(userString);
      final roles = List<String>.from(userData['roles'] ?? []);
      if (mounted) setState(() => _isAdmin = roles.contains('admin'));
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final provider = context.read<AssetProvider>();
      final asset = await provider.loadAssetDetail(widget.assetId);
      // Fetch eksplisit checks & issues untuk aset ini.
      final checks = await provider.loadChecks(assetId: widget.assetId);
      final issues = await provider.loadIssues(assetId: widget.assetId);
      if (!mounted) return;
      setState(() {
        _asset = asset;
        _checks = checks;
        _issues = issues;
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

  void _showError(String msg) {
    if (!mounted) return;
    showAppSnackBar(
      context,
      msg,
      background: Theme.of(context).colorScheme.error,
    );
  }

  Future<void> _confirmDelete() async {
    final provider = context.read<AssetProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Aset?'),
        content: Text(
            'Yakin hapus "${_asset?.name}" (${_asset?.code})? Riwayat '
            'pemeriksaan & issue terkait juga akan dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await provider.deleteAsset(widget.assetId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aset berhasil dihapus.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
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
        title: const Text('Detail Aset'),
        actions: [
          if (_isAdmin && _asset != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.error),
                      AppSpacing.gapHorizontalSM,
                      const Text('Hapus Aset'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      SizedBox(height: AppSpacing.sectionGap),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _asset == null
                  ? const Center(child: Text('Aset tidak ditemukan.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: AppSpacing.screenPadding.copyWith(
                          top: AppBarInsets.top(context),
                        ),
                        children: [
                          _buildHeader(theme, colorScheme),
                          SizedBox(height: AppSpacing.sectionGap),
                          _buildInfoGrid(theme, colorScheme),
                          SizedBox(height: AppSpacing.sectionGap),
                          _buildChecksSection(theme, colorScheme),
                          SizedBox(height: AppSpacing.sectionGap),
                          _buildIssuesSection(theme, colorScheme),
                        ],
                      ),
                    ),
      floatingActionButton: _asset != null
          ? CustomFAB(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AssetCheckFormPage(assetId: widget.assetId),
                  ),
                );
                if (result == true) _load();
              },
              icon: Icons.fact_check_rounded,
              tooltip: 'Mulai Check',
            )
          : null,
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final a = _asset!;
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              child: a.photo != null
                  ? ClipRRect(
                      borderRadius: AppSpacing.borderRadiusXXL,
                      child: Image.network(
                        '${ApiConstants.baseUrl.replaceFirst('/api', '')}/media/${a.photo}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.inventory_2),
                      ),
                    )
                  : Icon(Icons.inventory_2, color: AppColors.info),
            ),
            SizedBox(width: AppSpacing.rowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.gapVerticalXS,
                  Text(
                    '${a.code} • ${a.assetCategoryName ?? '-'}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(ThemeData theme, ColorScheme colorScheme) {
    final a = _asset!;
    String fmtDate(DateTime? d) =>
        d == null ? '-' : '${d.day}/${d.month}/${d.year}';

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informasi Aset',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: AppSpacing.sectionGap),
            _infoRow(theme, colorScheme, 'Kondisi', a.conditionText),
            _infoRow(theme, colorScheme, 'Status', a.statusText),
            _infoRow(theme, colorScheme, 'Store', a.storeName ?? '-'),
            _infoRow(
                theme, colorScheme, 'Check Terakhir', fmtDate(a.lastCheckAt)),
            _infoRow(theme, colorScheme, 'Next Check', fmtDate(a.nextCheckAt)),
            if (a.notes != null && a.notes!.isNotEmpty)
              _infoRow(theme, colorScheme, 'Catatan', a.notes!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, ColorScheme cs, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.itemGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildChecksSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Riwayat Pemeriksaan',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapVerticalSM,
        if (_checks.isEmpty)
          Text('Belum ada riwayat pemeriksaan.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant))
        else
          ..._checks.take(5).map((c) => Card(
                margin: EdgeInsets.only(bottom: AppSpacing.itemGap),
                child: ListTile(
                  title: Text('${c.checkDate} • ${c.severityText}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    c.notes?.isNotEmpty == true
                        ? c.notes!
                        : 'Oleh: ${c.checkedByName ?? '-'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    c.severity == 1 ? Icons.check_circle_rounded : Icons.warning_rounded,
                    color: c.severity == 1 ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildIssuesSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Issue (${_issues.length})',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapVerticalSM,
        if (_issues.isEmpty)
          Text('Tidak ada issue.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant))
        else
          ..._issues.map((i) => Card(
                margin: EdgeInsets.only(bottom: AppSpacing.itemGap),
                child: ListTile(
                  title: Text('${i.severityText} • ${i.statusText}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    i.description ?? 'Tidak ada deskripsi',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: i.isOpen
                      ? TextButton(
                          onPressed: () async {
                            try {
                              await context.read<AssetProvider>().closeIssue(i.id);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Issue ditutup.')),
                              );
                              _load();
                            } catch (e) {
                              _showError(
                                  e.toString().replaceFirst('Exception: ', ''));
                            }
                          },
                          child: const Text('Tutup'),
                        )
                      : null,
                ),
              )),
      ],
    );
  }
}
