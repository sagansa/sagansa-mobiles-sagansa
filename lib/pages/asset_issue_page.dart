import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset_issue_model.dart';
import '../providers/asset_provider.dart';
import '../services/asset_issue_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_app_bar.dart';
import 'asset_detail_page.dart';

/// Daftar issue (default: open) + aksi tutup issue.
class AssetIssuePage extends StatefulWidget {
  const AssetIssuePage({super.key});

  @override
  State<AssetIssuePage> createState() => _AssetIssuePageState();
}

class _AssetIssuePageState extends State<AssetIssuePage> {
  final AssetIssueService _issueService = AssetIssueService();
  final ScrollController _scrollController = ScrollController();
  List<AssetIssueModel> _issues = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;
  int _statusFilter = 1; // default open

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
      _issues = [];
      _hasMore = true;
    });
    try {
      final result =
          await _issueService.getIssuesPaged(status: _statusFilter, page: _page);
      if (!mounted) return;
      setState(() {
        _issues = result['data'] as List<AssetIssueModel>;
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
      final result = await _issueService.getIssuesPaged(
          status: _statusFilter, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _issues.addAll(result['data'] as List<AssetIssueModel>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Issue Aset'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xs, vertical: AppSpacing.xs),
            child: Row(
              children: [
                _FilterTab(
                    label: 'Open',
                    selected: _statusFilter == 1,
                    colorScheme: colorScheme,
                    onTap: () {
                      setState(() => _statusFilter = 1);
                      _fetch();
                    }),
                AppSpacing.gapHorizontalSM,
                _FilterTab(
                    label: 'Closed',
                    selected: _statusFilter == 2,
                    colorScheme: colorScheme,
                    onTap: () {
                      setState(() => _statusFilter = 2);
                      _fetch();
                    }),
              ],
            ),
          ),
        ),
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
              : _issues.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.task_alt_rounded,
                              size: 48,
                              color: AppColors.info
                                  .withValues(alpha:0.5)),
                          AppSpacing.gapVerticalSM,
                          Text(
                            _statusFilter == 1
                                ? 'Tidak ada issue terbuka.'
                                : 'Tidak ada issue yang sudah closed.',
                            style: theme.textTheme.bodyMedium,
                          ),
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
                        itemCount: _issues.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _issues.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final issue = _issues[i];
                          return Card(
                            margin: EdgeInsets.only(bottom: AppSpacing.itemGap),
                            child: ListTile(
                              onTap: () {
                                if (issue.assetId != 0) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AssetDetailPage(
                                          assetId: issue.assetId),
                                    ),
                                  );
                                }
                              },
                              title: Text(
                                issue.assetName ?? 'Aset #${issue.assetId}',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    issue.description ??
                                        'Tidak ada deskripsi',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  AppSpacing.gapVerticalXS,
                                  Text(
                                    issue.isOpen
                                        ? 'Dilaporkan: ${issue.createdAt ?? '-'}'
                                        : 'Ditutup: ${issue.resolvedAt ?? '-'}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: issue.isOpen
                                  ? TextButton(
                                      onPressed: () async {
                                        try {
                                          await context.read<AssetProvider>().closeIssue(issue.id);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Issue ditutup.')),
                                          );
                                          _fetch();
                                        } catch (e) {
                                          _showError(e
                                              .toString()
                                              .replaceFirst(
                                                  'Exception: ', ''));
                                        }
                                      },
                                      child: const Text('Tutup'),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withValues(alpha:0.15),
                                        borderRadius:
                                            AppSpacing.borderRadiusMD,
                                      ),
                                      child: Text(
                                        'Closed',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: AppColors.success,
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

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: AppSpacing.borderRadiusXL,
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color:
                selected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
