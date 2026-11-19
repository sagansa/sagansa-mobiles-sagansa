import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/closing_store_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/status_mappers.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import 'create_payment_receipt_page.dart';

class DailySalaryListPage extends StatefulWidget {
  const DailySalaryListPage({super.key});

  @override
  State<DailySalaryListPage> createState() => _DailySalaryListPageState();
}

class _DailySalaryListPageState extends State<DailySalaryListPage> {
  final ClosingStoreService _service = ClosingStoreService();
  final ScrollController _scrollController = ScrollController();
  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<dynamic> _dailySalaries = [];
  int _currentPage = 1;
  bool _hasMore = true;

  // Role & filter states
  bool _isAdmin = false;
  List<dynamic> _employees = [];
  int? _selectedUserId;
  String? _selectedStatus;
  int? _selectedPaymentType;
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;

  // Bulk selection
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  final Map<String, String> _statusOptions = {
    '1': 'Belum Dibayar',
    '2': 'Sudah Dibayar',
    '3': 'Siap Dibayar',
    '4': 'Perbaiki',
  };

  final Map<int, String> _paymentTypeOptions = {
    1: 'Transfer',
    2: 'Tunai',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserRole();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
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
    } catch (e) {
      // Ignore
    }
    _loadData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final result = await _service.getDailySalaries(
        page: 1,
        userId: _selectedUserId,
        status: _selectedStatus,
        paymentTypeId: _selectedPaymentType,
        dateFrom: _selectedDateFrom,
        dateTo: _selectedDateTo,
      );
      setState(() {
        _dailySalaries = result['data'];
        _hasMore = _currentPage < (result['meta']['last_page'] ?? 1);
        _isLoading = false;
      });

      // Load employees list for admin filter
      if (_isAdmin && _employees.isEmpty) {
        _loadEmployees();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _service.getEmployeesForDailySalary();
      if (mounted) {
        setState(() {
          _employees = employees;
        });
      }
    } catch (e) {
      // Ignore employee load error
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getDailySalaries(
        page: _currentPage + 1,
        userId: _selectedUserId,
        status: _selectedStatus,
        paymentTypeId: _selectedPaymentType,
        dateFrom: _selectedDateFrom,
        dateTo: _selectedDateTo,
      );
      setState(() {
        _dailySalaries.addAll(result['data']);
        _currentPage++;
        _hasMore = _currentPage < (result['meta']['last_page'] ?? 1);
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedUserId = null;
      _selectedStatus = null;
      _selectedPaymentType = null;
      _selectedDateFrom = null;
      _selectedDateTo = null;
    });
    _loadData();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedUserId != null) count++;
    if (_selectedStatus != null) count++;
    if (_selectedPaymentType != null) count++;
    if (_selectedDateFrom != null || _selectedDateTo != null) count++;
    return count;
  }

  void _openFilterSheet() {
    final employees = _employees;
    FilterBottomSheet.show(
      context,
      fields: [
        if (_isAdmin)
          DropdownFilterField<int>(
            label: 'Karyawan',
            value: _selectedUserId,
            options: employees.map((e) => (
              e['id'] as int,
              e['name']?.toString() ?? 'Karyawan #${e['id']}',
            )).toList(),
          ),
        DropdownFilterField<String>(
          label: 'Status',
          value: _selectedStatus,
          options: _statusOptions.entries.map((e) => (e.key, e.value)).toList(),
        ),
        DropdownFilterField<int>(
          label: 'Pembayaran',
          value: _selectedPaymentType,
          options: _paymentTypeOptions.entries.map((e) => (e.key, e.value)).toList(),
        ),
        DateRangeFilterField(
          label: 'Rentang Tanggal',
          value: _selectedDateFrom != null && _selectedDateTo != null
              ? (_selectedDateFrom!, _selectedDateTo!)
              : null,
        ),
      ],
      onApply: (values) {
        setState(() {
          _selectedUserId = values['Karyawan'] as int?;
          _selectedStatus = values['Status'] as String?;
          _selectedPaymentType = values['Pembayaran'] as int?;
          final dateRange = values['Rentang Tanggal'] as (DateTime, DateTime)?;
          _selectedDateFrom = dateRange?.$1;
          _selectedDateTo = dateRange?.$2;
        });
        _loadData();
      },
      onReset: () {
        _clearFilters();
      },
    );
  }

  Future<void> _navigateToPaymentReceipt() async {
    if (_selectedIds.isEmpty) return;

    // Get selected daily salary data (hanya yang masih bisa dibayar —
    // pertahanan bila status berubah setelah refresh).
    final selectedSalaries = _dailySalaries
        .where((s) => _selectedIds.contains(s['id']))
        .where((s) => StatusMappers.isPayableDailySalary(s))
        .toList();

    if (selectedSalaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Tidak ada daily salary yang bisa dibayar pada pilihan.')),
      );
      return;
    }

    // Get unique employee ID from selected items
    final employeeIds = selectedSalaries
        .map((s) => s['created_by']?['id'])
        .where((id) => id != null)
        .toSet()
        .toList();

    if (employeeIds.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih daily salary dari karyawan yang sama.')),
      );
      return;
    }

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePaymentReceiptPage(
          dailySalaries:
              selectedSalaries.map((s) => s as Map<String, dynamic>).toList(),
        ),
      ),
    );

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    if (result == true && mounted) {
      await _loadData();
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    final payableIds = _dailySalaries
        .where((s) => StatusMappers.isPayableDailySalary(s))
        .map((s) => s['id'] as int)
        .toSet();
    setState(() {
      if (_selectedIds.length == payableIds.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(payableIds);
      }
    });
  }

  int get _payableCount => _dailySalaries
      .where((s) => StatusMappers.isPayableDailySalary(s))
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} dipilih')
            : const Text('Daily Salary'),
        leading: _isSelectionMode
            ? IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          BarButtonCluster(actions: [
            if (_isAdmin) ...[
              if (_isSelectionMode) ...[
                BarButtonSpec(
                  icon: _selectedIds.length == _payableCount
                      ? Icons.deselect
                      : Icons.select_all,
                  tooltip: _selectedIds.length == _payableCount
                      ? 'Batalkan Semua'
                      : 'Pilih Semua',
                  onTap: _selectAll,
                ),
                BarButtonSpec(
                  icon: Icons.payment,
                  tooltip: 'Buat Payment Receipt',
                  onTap: _navigateToPaymentReceipt,
                ),
              ] else
                BarButtonSpec(
                  icon: Icons.checklist,
                  tooltip: 'Pilih Data',
                  onTap: _toggleSelectionMode,
                ),
            ],
            if (_isAdmin && !_isSelectionMode)
              BarButtonSpec(
                icon: Icons.tune,
                tooltip: 'Filter',
                badgeCount: _activeFilterCount,
                onTap: _openFilterSheet,
              ),
          ]),
        ],
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _dailySalaries.isEmpty
                        ? _buildEmptyWidget()
                        : _buildListWidget(_dailySalaries),
          ),
        ],
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index != 1) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildErrorWidget() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            AppSpacing.gapVerticalMD,
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            AppSpacing.gapVerticalLG,
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: colorScheme.outline),
          AppSpacing.gapVerticalMD,
          Text('Belum ada data daily salary.', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildListWidget(List<dynamic> displayList) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: displayList.length + (_hasMore ? 1 : 0),
        padding: AppSpacing.paddingMD.copyWith(
            top: AppBarInsets.top(context),
            bottom: ModernBottomNav.clearance(context)),
        itemBuilder: (context, index) {
        if (index == displayList.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final salary = displayList[index];
        final salaryId = salary['id'] as int;
        final employeeName = salary['created_by']?['name'] ?? 'Staff';
        final storeName = salary['store']?['nickname'] ??
            salary['store']?['name'] ??
            '-';
        final shiftStoreName = salary['shift_store']?['name'] ?? '';
        final date = salary['date'] ?? '';
        final amount = double.tryParse(salary['amount'].toString()) ?? 0;
        final status = salary['status'];
        final paymentType = salary['payment_type_id'];

        String statusText;
        Color statusColor;
        if (status == 1 || status == '1') {
          statusText = 'Belum Dibayar';
          statusColor = AppColors.warning;
        } else if (status == 2 || status == '2') {
          statusText = 'Sudah Dibayar';
          statusColor = AppColors.success;
        } else if (status == 3 || status == '3') {
          statusText = 'Siap Dibayar';
          statusColor = AppColors.info;
        } else if (status == 4 || status == '4') {
          statusText = 'Perbaiki';
          statusColor = colorScheme.error;
        } else {
          statusText = 'Status: $status';
          statusColor = AppColors.onSurfaceVariant;
        }

        final String paymentTypeText =
            paymentType == 1 || paymentType == '1' ? 'Transfer' : 'Tunai';

        final isSelected = _selectedIds.contains(salaryId);
        final isPayable = StatusMappers.isPayableDailySalary(salary);

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
          color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
          child: InkWell(
            onTap: _isSelectionMode && isPayable
                ? () => _toggleSelection(salaryId)
                : null,
            borderRadius: AppSpacing.borderRadiusMD,
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Icon(
                            !isPayable
                                ? Icons.block
                                : isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                            color: !isPayable
                                ? colorScheme.outlineVariant
                                : isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outline,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          employeeName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: AppSpacing.borderRadiusSM,
                        ),
                        child: Text(
                          statusText,
                          style: textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalSM,
                  Row(
                    children: [
                      Icon(Icons.store, size: 16, color: AppColors.info),
                      AppSpacing.gapHorizontalSM,
                      Text(storeName, style: textTheme.bodySmall),
                      if (shiftStoreName.isNotEmpty) ...[
                        Text(' • ', style: textTheme.bodySmall),
                        Text(shiftStoreName, style: textTheme.bodySmall),
                      ],
                    ],
                  ),
                  AppSpacing.gapVerticalXS,
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: AppColors.info),
                      AppSpacing.gapHorizontalSM,
                      Text(date, style: textTheme.bodySmall),
                    ],
                  ),
                  AppSpacing.gapVerticalXS,
                  Row(
                    children: [
                      Icon(Icons.payment, size: 14, color: AppColors.info),
                      AppSpacing.gapHorizontalSM,
                      Text(paymentTypeText, style: textTheme.bodySmall),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: textTheme.bodyMedium),
                      Text(
                        currencyFormatter.format(amount),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }
}
