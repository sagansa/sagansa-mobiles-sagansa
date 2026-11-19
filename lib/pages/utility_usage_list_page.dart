import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../models/utility_usage_model.dart';
import '../providers/auth_provider.dart';
import '../services/utility_usage_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/status_badge.dart';
import 'utility_usage_detail_page.dart';
import 'utility_usage_form_page.dart';

class UtilityUsageListPage extends StatefulWidget {
  const UtilityUsageListPage({super.key});

  @override
  State<UtilityUsageListPage> createState() => _UtilityUsageListPageState();
}

class _UtilityUsageListPageState extends State<UtilityUsageListPage> {
  final UtilityUsageService _service = UtilityUsageService();
  final ScrollController _scrollController = ScrollController();

  List<UtilityUsageModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _hasLoaded = false;
  bool _canManage = false;
  String? _errorMessage;

  // Filters - hierarchical: Store -> Category -> Utility
  int? _selectedStoreId;
  int? _selectedCategory;
  int? _selectedUtilityId;
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _utilities = [];

  // Helper getters for hierarchical filtering
  List<Map<String, dynamic>> get _filteredUtilities {
    if (_selectedStoreId == null && _selectedCategory == null) {
      return _utilities;
    }
    return _utilities.where((u) {
      final matchStore =
          _selectedStoreId == null || u['store_id'] == _selectedStoreId;
      final matchCategory =
          _selectedCategory == null || u['category'] == _selectedCategory;
      return matchStore && matchCategory;
    }).toList();
  }

  // Fixed, manual category options (independent of store)
  List<Map<String, dynamic>> get _filteredCategories => const [
        {'id': 1, 'label': 'Listrik'},
        {'id': 2, 'label': 'Air'},
        {'id': 3, 'label': 'Internet'},
      ];

  bool get _hasActiveFilters =>
      _selectedStoreId != null ||
      _selectedCategory != null ||
      _selectedUtilityId != null;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStoreId != null) count++;
    if (_selectedCategory != null) count++;
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
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getUtilityUsagesPaged(
        page: _page + 1,
        storeId: _selectedStoreId,
        category: _selectedCategory,
        utilityId: _selectedUtilityId,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(result['data'] as List<UtilityUsageModel>);
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
      final result = await _service.getUtilityUsagesPaged(
        page: _page,
        storeId: _selectedStoreId,
        category: _selectedCategory,
        utilityId: _selectedUtilityId,
      );
      if (!mounted) return;
      setState(() {
        _items = result['data'] as List<UtilityUsageModel>;
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
      _selectedCategory = null;
      _selectedUtilityId = null;
    });
    _fetch();
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter Pemakaian Utility',
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
          label: 'Jenis Utility',
          value: _selectedCategory,
          options: _filteredCategories
              .map((c) => (
                    c['id'] as int,
                    c['label'] as String,
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
                    u['name']?.toString() ?? 'Utility #${u['id']}',
                  ))
              .toList(),
        ),
      ],
      onApply: (values) {
        setState(() {
          _selectedStoreId = values['Toko'] as int?;
          _selectedCategory = values['Jenis Utility'] as int?;
          _selectedUtilityId = values['Utility'] as int?;
        });
        _fetch();
      },
      onReset: () {
        _clearFilters();
      },
    );
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

  void _openDetail(UtilityUsageModel item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => UtilityUsageDetailPage(usageId: item.id)),
    );
    if (result == true) _fetch();
  }

  void _openForm({UtilityUsageModel? item}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UtilityUsageFormPage(usage: item)),
    );
    if (result == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Pemakaian Utility'),
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
                tooltip: 'Tambah Pemakaian Utility',
                onTap: () => _openForm(),
              ),
          ]),
        ],
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 4, // Ops tab
        onTap: (index) {},
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildError()
                      : !_hasLoaded
                          ? const Center(child: CircularProgressIndicator())
                          : _items.isEmpty
                              ? _buildEmpty(colorScheme)
                              : _buildList(colorScheme, textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, ModernBottomNav.clearance(context)),
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
      UtilityUsageModel item, ColorScheme colorScheme, TextTheme textTheme) {
    final statusType = _statusType(item.status);
    final resultText = item.unitName != null
        ? '${_formatNumber(item.result)} ${item.unitName}'
        : _formatNumber(item.result);

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
                  Icons.electrical_services_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.utilityDisplayName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StatusBadge(
                          label: item.statusText,
                          type: statusType,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.speed_rounded,
                            size: 13, color: AppColors.info),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          resultText,
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.createdAt != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: AppColors.info),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _formatDate(item.createdAt!),
                              style: textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (item.storeNickname != null) ...[
                      Row(
                        children: [
                          Icon(Icons.store_rounded,
                              size: 11, color: AppColors.info),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            item.storeNickname!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
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

  String _formatNumber(String value) {
    try {
      final num = double.parse(value);
      if (num == num.roundToDouble()) {
        return num.toInt().toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]}.',
            );
      }
      return num.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    } catch (_) {
      return value;
    }
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
        'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildError() {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: _errorMessage!,
      subtitle: 'Terjadi kesalahan saat memuat data',
      action: ElevatedButton.icon(
        onPressed: _fetch,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Coba Lagi'),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return EmptyState(
      icon: Icons.electrical_services_rounded,
      title: 'Belum ada data pemakaian utility.',
    );
  }
}
