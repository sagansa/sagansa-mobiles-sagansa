import 'package:flutter/material.dart';
import '../models/asset_check_model.dart';
import '../services/asset_check_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_sheet.dart';

/// Riwayat semua pemeriksaan (cross-aset). Tap baris → bottom sheet detail.
class AssetCheckListPage extends StatefulWidget {
  const AssetCheckListPage({super.key, this.assetId});

  final int? assetId;

  @override
  State<AssetCheckListPage> createState() => _AssetCheckListPageState();
}

class _AssetCheckListPageState extends State<AssetCheckListPage> {
  final AssetCheckService _checkService = AssetCheckService();
  final ScrollController _scrollController = ScrollController();
  List<AssetCheckModel> _checks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetch();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _checks = [];
      _hasMore = true;
    });

    try {
      final result = await _checkService.getChecksPaged(
        assetId: widget.assetId,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _checks = result['data'] as List<AssetCheckModel>;
        _hasMore = result['has_more'] as bool;
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _checkService.getChecksPaged(
        assetId: widget.assetId,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _checks.addAll(result['data'] as List<AssetCheckModel>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Color _severityColor(int s) {
    switch (s) {
      case 1:
        return AppColors.success;
      case 2:
        return AppColors.info;
      case 3:
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  void _showDetail(AssetCheckModel c) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ModernBottomSheet.show(
      context: context,
      title: 'Pemeriksaan ${c.checkDate}',
      child: _buildCheckDetail(c, theme, colorScheme),
    );
  }

  Widget _buildCheckDetail(AssetCheckModel c, ThemeData theme, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pemeriksa: ${c.checkedByName ?? '-'}',
            style: theme.textTheme.bodyMedium),
        Text('Severity: ${c.severityText}',
            style: theme.textTheme.bodyMedium),
        if (c.latitude != null && c.longitude != null)
          Text('Lokasi: ${c.latitude}, ${c.longitude}',
              style: theme.textTheme.bodySmall),
        if (c.photos.isNotEmpty) ...[
          AppSpacing.gapVerticalSM,
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: c.photos.length,
              separatorBuilder: (_, __) => AppSpacing.gapHorizontalSM,
              itemBuilder: (context, i) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: AppSpacing.borderRadiusSM,
                ),
                child: const Icon(Icons.image),
              ),
            ),
          ),
        ],
        if (c.items.isNotEmpty) ...[
          AppSpacing.gapVerticalSM,
          Text('Checklist:',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          ...c.items.map((it) => Row(
                children: [
                  Icon(
                    it.isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: it.isOk
                        ? AppColors.success
                        : AppColors.error,
                    size: 18,
                  ),
                  AppSpacing.gapHorizontalXS,
                  Expanded(child: Text(it.label)),
                ],
              )),
        ],
        if (c.notes != null && c.notes!.isNotEmpty) ...[
          AppSpacing.gapVerticalSM,
          Text('Catatan: ${c.notes!}',
              style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Riwayat Pemeriksaan'),
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
                          onPressed: _fetch, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _checks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history,
                              size: 48,
                              color: AppColors.info
                                  .withValues(alpha:0.5)),
                          AppSpacing.gapVerticalSM,
                          Text('Belum ada riwayat pemeriksaan.',
                              style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: AppSpacing.screenPadding.copyWith(
                          top: AppBarInsets.top(context),
                        ),
                        itemCount: _checks.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, idx) {
                          if (idx == _checks.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final c = _checks[idx];
                          return Card(
                            margin: EdgeInsets.only(bottom: AppSpacing.itemGap),
                            child: ListTile(
                              onTap: () => _showDetail(c),
                              title: Text(c.checkDate,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${c.checkedByName ?? '-'} • ${c.severityText}',
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color:
                                      _severityColor(c.severity).withValues(alpha:0.15),
                                  borderRadius: AppSpacing.borderRadiusMD,
                                ),
                                child: Text(
                                  '${c.items.where((e) => !e.isOk).length} not-ok',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _severityColor(c.severity),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
