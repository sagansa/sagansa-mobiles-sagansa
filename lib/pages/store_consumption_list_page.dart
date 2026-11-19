import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../models/store_consumption_model.dart';
import '../providers/auth_provider.dart';
import '../services/store_consumption_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/status_badge.dart';
import 'create_store_consumption_page.dart';
import 'store_consumption_detail_page.dart';

class StoreConsumptionListPage extends StatefulWidget {
  const StoreConsumptionListPage({super.key});

  @override
  State<StoreConsumptionListPage> createState() =>
      _StoreConsumptionListPageState();
}

class _StoreConsumptionListPageState extends State<StoreConsumptionListPage> {
  final StoreConsumptionService _service = StoreConsumptionService();
  final ScrollController _scrollController = ScrollController();

  List<StoreConsumptionModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _hasLoaded = false;
  bool _canManage = false;
  String? _errorMessage;

  int? _selectedStoreId;
  List<Map<String, dynamic>> _stores = [];

  bool get _hasActiveFilters => _selectedStoreId != null;

  int get _activeFilterCount => _selectedStoreId != null ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _canManage = context
        .read<AuthProvider>()
        .hasAnyRole(['admin', 'super_admin', 'supervisor', 'staff']);
    _loadStores();
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
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (!_isLoadingMore && _hasMore) _loadMore();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getStoreConsumptions(
        page: _page + 1,
        storeId: _selectedStoreId,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(result['reports'] as List<StoreConsumptionModel>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadStores() async {
    try {
      final stores = await _service.getStores();
      if (!mounted) return;
      setState(() => _stores = stores);
    } catch (_) {}
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _items = [];
      _hasMore = true;
    });

    try {
      final result = await _service.getStoreConsumptions(
        page: _page,
        storeId: _selectedStoreId,
      );
      if (!mounted) return;
      setState(() {
        _items = result['reports'] as List<StoreConsumptionModel>;
        _hasMore = result['has_more'] as bool;
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  void _clearFilters() {
    setState(() => _selectedStoreId = null);
    _fetch();
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter Konsumsi Toko',
      fields: [
        DropdownFilterField<int>(
          label: 'Toko',
          value: _selectedStoreId,
          options: _stores
              .map((s) => (
                    s['id'] is int
                        ? s['id'] as int
                        : int.parse(s['id'].toString()),
                    s['nickname']?.toString() ?? 'Toko #${s['id']}',
                  ))
              .toList(),
        ),
      ],
      onApply: (values) {
        setState(() => _selectedStoreId = values['Toko'] as int?);
        _fetch();
      },
      onReset: () {
        _clearFilters();
      },
    );
  }

  void _openDetail(StoreConsumptionModel item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => StoreConsumptionDetailPage(consumptionId: item.id)),
    );
    if (result == true) _fetch();
  }

  void _openForm({StoreConsumptionModel? item}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateStoreConsumptionPage(consumption: item)),
    );
    if (result == true) _fetch();
  }

  StatusType _statusType(int status) {
    switch (status) {
      case 2:
        return StatusType.success;
      case 3:
        return StatusType.neutral;
      case 4:
        return StatusType.error;
      default:
        return StatusType.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppPageScaffold(
      titleText: 'Konsumsi Toko',
      actions: [
        BarButtonCluster(actions: [
          if (_hasActiveFilters)
            BarButtonSpec(
              icon: Icons.filter_list_off,
              tooltip: 'Hapus Filter',
              onTap: _clearFilters,
            ),
          BarButtonSpec(
            icon: Icons.tune,
            tooltip: 'Filter',
            badgeCount: _activeFilterCount,
            onTap: _openFilterSheet,
          ),
          if (_canManage)
            BarButtonSpec(
              icon: Icons.add_rounded,
              iconSize: 22,
              tooltip: 'Tambah Konsumsi Toko',
              onTap: () => _openForm(),
            ),
        ]),
      ],
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            Navigator.pop(context);
          }
        },
      ),
      isLoading: _isLoading || !_hasLoaded,
      errorMessage: _errorMessage,
      onRetry: _fetch,
      isEmpty: _items.isEmpty,
      emptyState: _buildEmpty(),
      bodyPadding: EdgeInsets.zero,
      body: _buildList(colorScheme, textTheme),
    );
  }

  Widget _buildList(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppBarInsets.top(context),
          AppSpacing.md,
          ModernBottomNav.clearance(context),
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, idx) {
          if (idx == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildCard(_items[idx], colorScheme, textTheme);
        },
      ),
    );
  }

  Widget _buildCard(StoreConsumptionModel item, ColorScheme colorScheme,
      TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: () => _openDetail(item),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: AppSpacing.borderRadiusSM,
                      color: colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.point_of_sale_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.storeName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(item.date),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(
                    label: item.statusText,
                    type: _statusType(item.status),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.category_rounded,
                      size: 16,
                      color: AppColors.info,
                      semanticLabel: null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${item.details.length} jenis item',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (item.createdByName.isNotEmpty)
                    Flexible(
                      child: Text(
                        'oleh ${item.createdByName}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildEmpty() {
    return EmptyState(
      icon: Icons.point_of_sale_outlined,
      title: 'Belum ada data konsumsi toko.',
    );
  }
}
