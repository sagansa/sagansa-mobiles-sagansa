import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../models/storage_stock_model.dart';
import '../providers/auth_provider.dart';
import '../services/storage_stock_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/modern_bottom_nav.dart';
import 'create_storage_stock_page.dart';
import 'storage_stock_detail_page.dart';

class StorageStockListPage extends StatefulWidget {
  const StorageStockListPage({super.key});

  @override
  State<StorageStockListPage> createState() => _StorageStockListPageState();
}

class _StorageStockListPageState extends State<StorageStockListPage> {
  final StorageStockService _service = StorageStockService();
  final ScrollController _scrollController = ScrollController();

  List<StorageStockModel> _reports = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;

  /// Apakah user boleh membuat laporan sekarang: belum pernah lapor hari ini
  /// DAN berada dalam window pelaporan (22:00 tgl D-1 s.d. 11:00 tgl D).
  bool _canReport = false;

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _checkCanReport();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _checkCanReport() async {
    final isAdmin = context.read<AuthProvider>().isAdmin;
    if (isAdmin) {
      if (!mounted) return;
      setState(() => _canReport = false);
      return;
    }

    // Window pelaporan: 22:00 tgl D-1 s.d. 11:00 tgl D. Di luar itu (jam 11-22)
    // pelaporan ditutup, FAB disembunyikan.
    final now = DateTime.now();
    final inWindow = now.hour >= 22 || now.hour < 11;

    bool alreadyReported = false;
    try {
      final status = await _service.checkTodayStatus();
      alreadyReported = status['user_store_reported'] == 1;
    } catch (_) {
      // Bila gagal cek, default sembunyikan FAB demi aman.
    }

    if (!mounted) return;
    setState(() => _canReport = inWindow && !alreadyReported);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Listener scroll bisa fire di tengah fase layout; setState langsung
    // di sini → "setState() called during build". Tunda ke post-frame.
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (!_isLoadingMore && _hasMore) _loadMore();
      });
    }
  }

  Future<void> _fetchReports() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _reports = [];
      _hasMore = true;
    });

    try {
      final result = await _service.getStorageStocks(page: _page);
      if (!mounted) return;
      setState(() {
        _reports = result['reports'] as List<StorageStockModel>;
        _hasMore = result['has_more'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getStorageStocks(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _reports.addAll(result['reports'] as List<StorageStockModel>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return AppPageScaffold(
      titleText: 'Riwayat Stok Gudang',
      actions: [
        BarButtonCluster(
          actions: [
            if (_canReport)
              BarButtonSpec(
                icon: Icons.add_rounded,
                iconSize: 22,
                tooltip: 'Tambah Stok Gudang',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateStorageStockPage(),
                    ),
                  );
                  if (result == true) {
                    _fetchReports();
                    _checkCanReport();
                  }
                },
              ),
          ],
        ),
      ],
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      onRetry: _fetchReports,
      isEmpty: _reports.isEmpty,
      emptyState: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppColors.info,
            ),
            AppSpacing.gapVerticalMD,
            Text(
              'Belum ada riwayat laporan stok gudang.',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      bodyPadding: EdgeInsets.zero,
      body: RefreshIndicator(
        onRefresh: _fetchReports,
        child: ListView.builder(
          controller: _scrollController,
          padding: AppSpacing.paddingMD.copyWith(
            top: AppBarInsets.top(context),
            bottom: ModernBottomNav.clearance(context),
          ),
          itemCount: _reports.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, idx) {
            if (idx == _reports.length) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final report = _reports[idx];

            return _buildReportCard(context, report, colorScheme, textTheme);
          },
        ),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    StorageStockModel report,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  StorageStockDetailPage(reportId: report.id),
            ),
          );
        },
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    report.storeName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: AppSpacing.borderRadiusXL,
                    ),
                    child: Text(
                      report.statusText,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVerticalSM,
              Text(
                'Tanggal: ${report.date}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.gapVerticalXS,
              Text(
                'Dilaporkan oleh: ${report.createdByName}',
                style: textTheme.bodySmall?.copyWith(
                  color:
                      colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const Divider(height: 24),
              Text(
                '${report.details.length} jenis item terdata',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
