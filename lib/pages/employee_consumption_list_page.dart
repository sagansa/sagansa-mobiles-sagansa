import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../models/employee_consumption_model.dart';
import '../providers/auth_provider.dart';
import '../services/employee_consumption_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/status_badge.dart';
import 'create_employee_consumption_page.dart';
import 'employee_consumption_detail_page.dart';

class EmployeeConsumptionListPage extends StatefulWidget {
  const EmployeeConsumptionListPage({super.key});

  @override
  State<EmployeeConsumptionListPage> createState() =>
      _EmployeeConsumptionListPageState();
}

class _EmployeeConsumptionListPageState
    extends State<EmployeeConsumptionListPage> {
  final EmployeeConsumptionService _service = EmployeeConsumptionService();
  final ScrollController _scrollController = ScrollController();

  List<EmployeeConsumptionModel> _items = [];
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
      final result = await _service.getEmployeeConsumptions(
        page: _page + 1,
        storeId: _selectedStoreId,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(result['reports'] as List<EmployeeConsumptionModel>);
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
      final result = await _service.getEmployeeConsumptions(
        page: _page,
        storeId: _selectedStoreId,
      );
      if (!mounted) return;
      setState(() {
        _items = result['reports'] as List<EmployeeConsumptionModel>;
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
      title: 'Filter Sisa Stok Karyawan',
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

  void _openDetail(EmployeeConsumptionModel item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              EmployeeConsumptionDetailPage(consumptionId: item.id)),
    );
    if (result == true) _fetch();
  }

  void _openForm({EmployeeConsumptionModel? item}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateEmployeeConsumptionPage(consumption: item)),
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('Sisa Stok Karyawan'),
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
                tooltip: 'Tambah Konsumsi Karyawan',
                onTap: () => _openForm(),
              ),
          ]),
        ],
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            Navigator.pop(context);
          }
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildError()
                    : !_hasLoaded
                        ? const Center(child: CircularProgressIndicator())
                        : _items.isEmpty
                            ? _buildEmpty()
                            : _buildList(colorScheme, textTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
            16, AppBarInsets.top(context), 16, ModernBottomNav.clearance(context)),
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

  Widget _buildCard(EmployeeConsumptionModel item, ColorScheme colorScheme,
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
                      Icons.inventory_2_outlined,
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
                  Icon(Icons.category_rounded, size: 13, color: AppColors.info),
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

  Widget _buildEmpty() {
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Belum ada data sisa stok karyawan.',
    );
  }
}
