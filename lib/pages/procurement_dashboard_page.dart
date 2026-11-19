import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/procurement_model.dart';
import '../../models/store_model.dart';
import '../../services/procurement_service.dart';
import '../../services/store_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_bar_insets.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../widgets/modern_bottom_nav.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/glass_app_bar.dart';
import 'create_procurement_page.dart';
import 'procurement_detail_page.dart';

class ProcurementDashboardPage extends StatefulWidget {
  const ProcurementDashboardPage({super.key});

  @override
  State<ProcurementDashboardPage> createState() => _ProcurementDashboardPageState();
}

class _ProcurementDashboardPageState extends State<ProcurementDashboardPage> with SingleTickerProviderStateMixin {
  final ProcurementService _procurementService = ProcurementService();
  final StoreService _storeService = StoreService();
  final ScrollController _scrollController = ScrollController();
  List<RequestPurchase> _requests = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;
  late TabController _tabController;
  bool _isAdmin = false;
  int? _selectedStoreId;
  List<StoreModel> _stores = [];

  bool get _hasActiveFilter => _selectedStoreId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadFilterData();
    _loadUserRoleAndRequests();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
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

  Future<void> _loadUserRoleAndRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final userData = json.decode(userString);
        final userRoles = List<String>.from(userData['roles'] ?? []);
        setState(() {
          _isAdmin = userRoles.contains('admin') || userRoles.contains('super_admin');
        });
      }
    } catch (_) {}
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _requests = [];
      _hasMore = true;
    });

    try {
      final result = await _procurementService.getRequestsPaged(
          page: _page, storeId: _selectedStoreId);
      if (!mounted) return;
      setState(() {
        _requests = result['data'] as List<RequestPurchase>;
        _hasMore = result['has_more'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat request belanja: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _procurementService.getRequestsPaged(
          page: _page + 1, storeId: _selectedStoreId);
      if (!mounted) return;
      setState(() {
        _page++;
        _requests.addAll(result['data'] as List<RequestPurchase>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadFilterData() async {
    try {
      final stores = await _storeService.getStores();
      if (!mounted) return;
      setState(() => _stores = stores);
    } catch (_) {}
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter Request',
      fields: [
        DropdownFilterField<int>(
          label: 'Toko',
          value: _selectedStoreId,
          options: _stores
              .map((s) => (s.id, s.nickname))
              .toList(),
        ),
      ],
      onApply: (values) {
        setState(() => _selectedStoreId = values['Toko'] as int?);
        _fetchRequests();
      },
      onReset: () {
        setState(() => _selectedStoreId = null);
        _fetchRequests();
      },
    );
  }

  void _clearFilters() {
    setState(() => _selectedStoreId = null);
    _fetchRequests();
  }

  List<RequestPurchase> _getFilteredRequests(int tabIndex) {
    switch (tabIndex) {
      case 1: // Pending Approval
        return _requests.where((r) => r.detailRequests.any((item) => item.statusEnum.isPending)).toList();
      case 2: // Approved
        return _requests.where((r) => r.detailRequests.any((item) => item.statusEnum.isPartiallyApproved) && 
                                      !r.detailRequests.any((item) => item.statusEnum.isPending)).toList();
      case 3: // Done
        return _requests.where((r) => r.detailRequests.isNotEmpty && r.detailRequests.every((item) => item.statusEnum.isDone)).toList();
      case 4: // Kosong / Tanpa Item
        return _requests.where((r) => r.detailRequests.isEmpty).toList();
      default: // Semua
        return _requests;
    }
  }

  Color _getStatusColor(String statusText) {
    switch (statusText) {
      case 'Pending Approval':
        return AppColors.warning;
      case 'Partially Approved':
      case 'Approved':
        return AppColors.info;
      case 'Done':
        return AppColors.success;
      case 'Rejected':
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
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Request & Purchase'),
        actions: [
          BarButtonCluster(actions: [
            if (_hasActiveFilter)
              BarButtonSpec(
                icon: Icons.filter_list_off,
                tooltip: 'Hapus Filter',
                onTap: _clearFilters,
              ),
            BarButtonSpec(
              icon: Icons.tune,
              tooltip: 'Filter',
              badgeCount: _selectedStoreId != null ? 1 : 0,
              onTap: _openFilterSheet,
            ),
            BarButtonSpec(
              icon: Icons.add_rounded,
              iconSize: 22,
              tooltip: 'Tambah Request',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateProcurementPage(),
                  ),
                );
                if (result == true) {
                  _fetchRequests();
                }
              },
            ),
          ]),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Selesai'),
            Tab(text: 'Kosong'),
          ],
        ),
      ),
      body: Builder(
        builder: (bodyContext) => _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: AppSpacing.paddingLG,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_errorMessage!,
                              style: TextStyle(color: colorScheme.error)),
                          AppSpacing.gapVerticalMD,
                          ElevatedButton(
                            onPressed: _fetchRequests,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: List.generate(5, (index) {
                      final requests = _getFilteredRequests(index);
                      if (requests.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 48,
                                color: AppColors.info,
                              ),
                              AppSpacing.gapVerticalMD,
                              Text(
                                'Tidak ada data request belanja.',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: _fetchRequests,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: AppSpacing.paddingMD.copyWith(
                              top: AppBarInsets.top(bodyContext),
                              bottom: ModernBottomNav.clearance(context)),
                        itemCount: requests.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, idx) {
                          if (idx == requests.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final request = requests[idx];
                          final overallStatus = request.overallStatusText;

                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
                            child: InkWell(
                              borderRadius: AppSpacing.borderRadiusLG,
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProcurementDetailPage(requestId: request.id),
                                  ),
                                );
                                if (result == true) {
                                  _fetchRequests();
                                }
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
                                          request.storeName,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(overallStatus).withValues(alpha: 0.1),
                                            borderRadius: AppSpacing.borderRadiusXL,
                                          ),
                                          child: Text(
                                            overallStatus,
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: _getStatusColor(overallStatus),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    AppSpacing.gapVerticalSM,
                                    Text(
                                      'Tanggal: ${request.date}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (_isAdmin) ...[
                                      AppSpacing.gapVerticalXS,
                                      Text(
                                        'Diminta oleh: ${request.userName}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                    const Divider(height: 24),
                                    Text(
                                      'Detail Item:',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    AppSpacing.gapVerticalXS,
                                    ...request.detailRequests.take(2).map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '- ${item.productName}',
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                            Text(
                                              '${item.quantityPlan.toStringAsFixed(0)} ${item.unitName}',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    if (request.detailRequests.length > 2)
                                      Text(
                                        '... dan ${request.detailRequests.length - 2} item lainnya',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  })),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index != 3) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
