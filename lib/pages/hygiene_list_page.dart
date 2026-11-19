import 'package:flutter/material.dart';

import '../models/hygiene_model.dart';
import '../services/hygiene_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import 'home_page.dart';
import 'hrd_dashboard_page.dart';
import 'hygiene_detail_page.dart';
import 'hygiene_page.dart';
import 'stock_dashboard_page.dart';
import 'transaction_dashboard_page.dart';

class HygieneListPage extends StatefulWidget {
  const HygieneListPage({super.key});

  @override
  State<HygieneListPage> createState() => _HygieneListPageState();
}

class _HygieneListPageState extends State<HygieneListPage> {
  final HygieneService _service = HygieneService();
  final ScrollController _scrollController = ScrollController();
  List<HygieneModel> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
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

  void _handleNavigation(BuildContext context, int index) {
    if (index == 4) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HRDDashboardPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StockDashboardPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TransactionDashboardPage(),
          ),
        );
        break;
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = true;
    });
    try {
      final result = await _service.getHistory(page: 1);
      if (!mounted) return;
      setState(() {
        _items = result['data'];
        _lastPage = result['meta']['last_page'] ?? 1;
        _hasMore = _currentPage < _lastPage;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat daftar kebersihan: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getHistory(page: _currentPage + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(result['data']);
        _currentPage++;
        _lastPage = result['meta']['last_page'] ?? _currentPage;
        _hasMore = _currentPage < _lastPage;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return AppColors.warning;
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.error;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('List Kebersihan Toko'),
        actions: [
          BarButtonCluster(
            actions: [
              BarButtonSpec(
                icon: Icons.add_rounded,
                iconSize: 22,
                tooltip: 'Tambah Kebersihan',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HygienePage()),
                  );
                  _load();
                },
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.paddingLG,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: colorScheme.error)),
                        AppSpacing.gapVerticalMD,
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cleaning_services_outlined,
                              size: 56,
                              color: AppColors.info
                                  .withValues(alpha: 0.5)),
                          AppSpacing.gapVerticalMD,
                          Text(
                            'Belum ada laporan kebersihan.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.md)
                            .copyWith(
                                top: AppBarInsets.top(context),
                                bottom: ModernBottomNav.clearance(context)),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, idx) {
                          if (idx == _items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = _items[idx];
                          final photos = item.rooms
                              .where((r) => r.imageUrl != null)
                              .map((r) => r.imageUrl!)
                              .toList();
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HygieneDetailPage(
                                        hygiene: item),
                                  ),
                                );
                                if (changed == true) _load();
                              },
                              child: Padding(
                                padding: AppSpacing.paddingSM,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                AppSpacing.borderRadiusSM,
                                          ),
                                          child: Icon(
                                            Icons
                                                .cleaning_services_outlined,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        AppSpacing.gapHorizontalSM,
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.storeName ?? 'Toko',
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                item.createdByName ?? '-',
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                              Text(
                                                _formatDateTime(item.createdAt),
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            AppSpacing.gapVerticalXS,
                                            Text(
                                              item.statusLabel,
                                              style: theme
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                color: _statusColor(item.status),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (photos.isNotEmpty) ...[
                                      AppSpacing.gapVerticalSM,
                                      SizedBox(
                                        height: 72,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: photos.length,
                                          separatorBuilder: (_, __) =>
                                              AppSpacing.gapHorizontalXS,
                                          itemBuilder: (context, pidx) {
                                            return ClipRRect(
                                              borderRadius:
                                                  AppSpacing.borderRadiusSM,
                                              child: Image.network(
                                                photos[pidx],
                                                width: 72,
                                                height: 72,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  width: 72,
                                                  height: 72,
                                                  color: colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.3),
                                                  child: Icon(
                                                    Icons
                                                        .image_not_supported_outlined,
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ] else ...[
                                      AppSpacing.gapVerticalXS,
                                      Text(
                                        'Tanpa foto',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 4,
        onTap: (index) => _handleNavigation(context, index),
      ),
    );
  }
}
