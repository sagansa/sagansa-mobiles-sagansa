import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../models/utility_bill_model.dart';
import '../providers/auth_provider.dart';
import '../services/utility_bill_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/modern_bottom_nav.dart';
import 'utility_bill_detail_page.dart';
import 'utility_bill_form_page.dart';

class UtilityBillListPage extends StatefulWidget {
  const UtilityBillListPage({super.key});

  @override
  State<UtilityBillListPage> createState() => _UtilityBillListPageState();
}

class _UtilityBillListPageState extends State<UtilityBillListPage> {
  final UtilityBillService _service = UtilityBillService();
  final ScrollController _scrollController = ScrollController();

  List<UtilityBillModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _hasLoaded = false;
  bool _canManage = false;
  String? _errorMessage;

  // Filters: Store -> Utility
  int? _selectedStoreId;
  int? _selectedUtilityId;
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _utilities = [];

  List<Map<String, dynamic>> get _filteredUtilities {
    if (_selectedStoreId == null) {
      return _utilities;
    }
    return _utilities.where((u) => u['store_id'] == _selectedStoreId).toList();
  }

  bool get _hasActiveFilters =>
      _selectedStoreId != null || _selectedUtilityId != null;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStoreId != null) count++;
    if (_selectedUtilityId != null) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _canManage = context
        .read<AuthProvider>()
        .hasAnyRole(['admin', 'super_admin', 'supervisor', 'staff']);
    _loadFilterData();
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
      final result = await _service.getUtilityBillsPaged(
        page: _page + 1,
        storeId: _selectedStoreId,
        utilityId: _selectedUtilityId,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(result['data'] as List<UtilityBillModel>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadFilterData() async {
    try {
      final results = await Future.wait([
        _service.getStores(),
        _service.getUtilities(),
      ]);
      if (!mounted) return;
      setState(() {
        _stores = results[0];
        _utilities = results[1];
      });
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
      final result = await _service.getUtilityBillsPaged(
        page: _page,
        storeId: _selectedStoreId,
        utilityId: _selectedUtilityId,
      );
      if (!mounted) return;
      setState(() {
        _items = result['data'] as List<UtilityBillModel>;
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
    setState(() {
      _selectedStoreId = null;
      _selectedUtilityId = null;
    });
    _fetch();
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter Tagihan Utility',
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
        DropdownFilterField<int>(
          label: 'Utility',
          value: _selectedUtilityId,
          options: _filteredUtilities
              .map((u) => (
                    u['id'] is int
                        ? u['id'] as int
                        : int.parse(u['id'].toString()),
                    u['utility_name']?.toString() ?? 'Utility #${u['id']}',
                  ))
              .toList(),
        ),
      ],
      onApply: (values) {
        setState(() {
          _selectedStoreId = values['Toko'] as int?;
          _selectedUtilityId = values['Utility'] as int?;
        });
        _fetch();
      },
      onReset: () {
        _clearFilters();
      },
    );
  }

  void _openDetail(UtilityBillModel item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UtilityBillDetailPage(billId: item.id)),
    );
    if (result == true) _fetch();
  }

  void _openForm({UtilityBillModel? item}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UtilityBillFormPage(bill: item)),
    );
    if (result == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppPageScaffold(
      titleText: 'Tagihan Utility',
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
              tooltip: 'Tambah Tagihan Utility',
              onTap: () => _openForm(),
            ),
        ]),
      ],
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 4, // Ops tab
        onTap: (index) {},
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

  Widget _buildCard(
      UtilityBillModel item, ColorScheme colorScheme, TextTheme textTheme) {
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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: AppSpacing.borderRadiusSM,
                  color: colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.utilityDisplayName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const ExcludeSemantics(
                          child: Icon(
                            Icons.payments_rounded,
                            size: 16,
                            color: AppColors.info,
                            semanticLabel: null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            item.formattedAmount,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const ExcludeSemantics(
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: AppColors.info,
                            semanticLabel: null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            item.formattedDate,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.storeNickname != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const ExcludeSemantics(
                            child: Icon(
                              Icons.store_rounded,
                              size: 16,
                              color: AppColors.info,
                              semanticLabel: null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              item.storeNickname!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: AppColors.info),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return EmptyState(
      icon: Icons.receipt_long_rounded,
      title: 'Belum ada data tagihan utility.',
    );
  }
}
