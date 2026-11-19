import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../models/procurement_model.dart';
import '../services/closing_store_service.dart';
import '../services/procurement_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/status_mappers.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/ios_segmented_control.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/payment_receipt_card.dart';
import 'create_payment_receipt_page.dart';
import 'daily_salary_form_page.dart';
import 'edit_payment_receipt_page.dart';
import 'payment_receipt_detail_page.dart';

class DailySalaryPage extends StatefulWidget {
  const DailySalaryPage({super.key});

  @override
  State<DailySalaryPage> createState() => _DailySalaryPageState();
}

class _DailySalaryPageState extends State<DailySalaryPage> {
  int _activeTab = 0;
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

  // Ringkasan dari meta (mengikuti filter aktif, dihitung server-side).
  int _totalCount = 0;
  int _totalAmount = 0;

  // Role & filter states
  bool _isAdmin = false;
  int? _currentUserId;
  List<dynamic> _employees = [];
  int? _selectedUserId;
  String? _selectedEmployeeRole; // 'active' | 'former' (null = semua)
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

  final ProcurementService _procurementService = ProcurementService();
  List<PaymentReceipt> _receipts = [];
  bool _isLoadingReceipts = false;
  bool _hasMoreReceipts = true;
  int _receiptPage = 1;
  bool _isLoadingMoreReceipts = false;
  final ScrollController _receiptScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAdmin();
    _scrollController.addListener(_onScroll);
    _receiptScrollController.addListener(_onReceiptScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _receiptScrollController.removeListener(_onReceiptScroll);
    _receiptScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final userData = json.decode(userString);
        final userRoles = List<String>.from(userData['roles'] ?? []);
        final rawId = userData['id'];
        setState(() {
          _isAdmin = userRoles.contains('admin') || userRoles.contains('super_admin');
          _currentUserId = rawId is int
              ? rawId
              : int.tryParse(rawId?.toString() ?? '');
        });
        // Tab "Pembayaran" hanya untuk admin — muat receipt begitu role
        // diketahui (mirror fuel_service_page), bukan menunggu pull-to-refresh.
        if (_isAdmin) {
          _fetchReceipts();
        }
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
        employeeRole: _selectedEmployeeRole,
        status: _selectedStatus,
        paymentTypeId: _selectedPaymentType,
        dateFrom: _selectedDateFrom,
        dateTo: _selectedDateTo,
      );
      setState(() {
        _dailySalaries = result['data'];
        _hasMore = _currentPage < (result['meta']['last_page'] ?? 1);
        _totalCount = int.tryParse('${result['meta']['total'] ?? 0}') ?? 0;
        _totalAmount =
            int.tryParse('${result['meta']['total_amount'] ?? 0}') ?? 0;
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
        employeeRole: _selectedEmployeeRole,
        status: _selectedStatus,
        paymentTypeId: _selectedPaymentType,
        dateFrom: _selectedDateFrom,
        dateTo: _selectedDateTo,
      );
      setState(() {
        _dailySalaries.addAll(result['data']);
        _currentPage++;
        _hasMore = _currentPage < (result['meta']['last_page'] ?? 1);
        _totalCount = int.tryParse('${result['meta']['total'] ?? 0}') ?? 0;
        _totalAmount =
            int.tryParse('${result['meta']['total_amount'] ?? 0}') ?? 0;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedUserId = null;
      _selectedEmployeeRole = null;
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
    if (_selectedEmployeeRole != null) count++;
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
        if (_isAdmin) ...[
          DropdownFilterField<String>(
            label: 'Status Karyawan',
            value: _selectedEmployeeRole,
            options: const [
              ('active', 'Karyawan Aktif'),
              ('former', 'Mantan Karyawan'),
            ],
          ),
          DropdownFilterField<int>(
            label: 'Karyawan',
            value: _selectedUserId,
            options: employees.map((e) {
              final name = e['name']?.toString() ?? 'Karyawan #${e['id']}';
              final isFormer = e['is_former_employee'] == true ||
                  e['is_former_employee'] == 1;
              return (
                e['id'] as int,
                isFormer ? '$name (Mantan Karyawan)' : name,
              );
            }).toList(),
            // Opsi Karyawan mengikuti pilihan Status Karyawan.
            dependsOn: 'Status Karyawan',
            optionFilter: (options, status) => status == null
                ? options
                : options
                    .where((opt) => _employees.any((e) =>
                        e['id'] == opt.$1 &&
                        (status == 'former') ==
                            (e['is_former_employee'] == true ||
                                e['is_former_employee'] == 1)))
                    .toList(),
          ),
        ],
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
          _selectedEmployeeRole = values['Status Karyawan'] as String?;
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
      // Receipt baru saja dibuat — segarkan tab Pembayaran juga.
      if (_isAdmin) {
        _fetchReceipts();
      }
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

  /// Bisa diedit/dihapus bila milik sendiri (atau admin) dan belum dibayar.
  bool _canModify(Map<String, dynamic> salary) {
    final status = salary['status'];
    if (status == 2 || status == '2') return false;

    final ownerId = salary['created_by']?['id'];
    return _isAdmin || ownerId == _currentUserId;
  }

  Future<void> _openDailySalaryForm([Map<String, dynamic>? record]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailySalaryFormPage(dailySalary: record),
      ),
    );
    if (result == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _confirmDeleteDailySalary(Map<String, dynamic> salary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Gaji Harian'),
        content: const Text(
            'Yakin ingin menghapus daily salary ini? Tindakan tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteDailySalary(salary['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily salary berhasil dihapus.')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _onReceiptScroll() {
    if (_receiptScrollController.position.pixels >=
        _receiptScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMoreReceipts &&
        _hasMoreReceipts) {
      _loadMoreReceipts();
    }
  }

  Future<void> _fetchReceipts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingReceipts = true;
      _receiptPage = 1;
      _receipts = [];
      _hasMoreReceipts = true;
    });
    try {
      // payment_for=2 → hanya receipt DailySalary. Backend GET /payment-receipts
      // default-nya mengembalikan receipt InvoicePurchase (3), jadi tanpa param
      // ini tab Pembayaran akan selalu kosong (filter client-side sebelumnya
      // menutupi masalah ini tapi tidak menangani pagination dengan benar).
      final result = await _procurementService.getPaymentReceipts(
        page: _receiptPage,
        paymentFor: '2',
      );
      if (!mounted) return;
      setState(() {
        _receipts = result.items;
        _hasMoreReceipts = result.hasMore;
        _isLoadingReceipts = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingReceipts = false);
    }
  }

  Future<void> _loadMoreReceipts() async {
    if (_isLoadingMoreReceipts || !_hasMoreReceipts) return;
    setState(() => _isLoadingMoreReceipts = true);
    try {
      final result = await _procurementService.getPaymentReceipts(
        page: _receiptPage + 1,
        paymentFor: '2',
      );
      if (!mounted) return;
      setState(() {
        _receiptPage++;
        _receipts.addAll(result.items);
        _hasMoreReceipts = result.hasMore;
        _isLoadingMoreReceipts = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMoreReceipts = false);
    }
  }

  Widget _buildAdminOnlyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.outline),
          AppSpacing.gapVerticalMD,
          Text('Hanya dapat diakses oleh admin.'),
        ],
      ),
    );
  }

  /// Hapus receipt gaji harian dari tab Pembayaran. Server mengembalikan
  /// status semua daily salary ter-attach menjadi siap dibayar (3), jadi
  /// kedua tab di-refresh.
  Future<void> _confirmDeleteReceipt(PaymentReceipt receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Payment Receipt'),
        content: const Text(
            'Yakin ingin menghapus payment receipt ini? Semua daily salary ter-attach akan dikembalikan menjadi "Siap Dibayar".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: AppButtonStyle.filled(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _procurementService.deletePaymentReceipt(receipt.id);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Payment receipt dihapus. Status gaji dikembalikan.',
        background: AppColors.success,
      );
      _fetchReceipts();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _buildPaymentReceiptTab() {
    if (_isLoadingReceipts) {
      return const Center(child: CircularProgressIndicator());
    }
    final topPadding = AppBarInsets.top(context, bottom: 52) + 8;
    final bottomPadding = ModernBottomNav.clearance(context) + 16;
    if (_receipts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchReceipts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64,
                      color: Theme.of(context).colorScheme.outline),
                  AppSpacing.gapVerticalMD,
                  const Text('Belum ada pembayaran gaji harian.'),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchReceipts,
      child: ListView.builder(
        controller: _receiptScrollController,
        padding: AppSpacing.paddingMD.copyWith(
          top: topPadding,
          bottom: bottomPadding,
        ),
        itemCount: _receipts.length + (_hasMoreReceipts ? 1 : 0),
        itemBuilder: (context, idx) {
          if (idx == _receipts.length) {
            return const Padding(
              padding: AppSpacing.paddingMD,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final receipt = _receipts[idx];
          return PaymentReceiptCard(
            receipt: receipt,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentReceiptDetailPage(receiptId: receipt.id),
                ),
              ).then((_) {
                // Status gaji bisa berubah (edit/hapus dari halaman detail).
                _fetchReceipts();
                _loadData();
              });
            },
            onEdit: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditPaymentReceiptPage(receipt: receipt),
                ),
              );
              if (mounted) {
                _fetchReceipts();
                _loadData();
              }
            },
            onDelete: () => _confirmDeleteReceipt(receipt),
          );
        },
      ),
    );
  }

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
              ] else if (_activeTab == 0)
                BarButtonSpec(
                  icon: Icons.checklist,
                  tooltip: 'Pilih Data',
                  onTap: _toggleSelectionMode,
                ),
            ],
            if (_isAdmin && !_isSelectionMode && _activeTab == 0)
              BarButtonSpec(
                icon: Icons.tune,
                tooltip: 'Filter',
                badgeCount: _activeFilterCount,
                onTap: _openFilterSheet,
              ),
            if (_activeTab == 0 && !_isSelectionMode)
              BarButtonSpec(
                icon: Icons.add_rounded,
                iconSize: 22,
                tooltip: 'Tambah Gaji Harian',
                onTap: () => _openDailySalaryForm(),
              ),
          ]),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: IosSegmentedControl<int>(
            segments: const {
              0: 'Gaji Harian',
              1: 'Pembayaran',
            },
            groupValue: _activeTab,
            onValueChanged: (v) => setState(() {
              _activeTab = v;
              if (_isSelectionMode) _toggleSelectionMode();
            }),
          ),
        ),
      ),
      body: IndexedStack(
        index: _activeTab,
        children: [
          _buildDailySalaryTab(),
          _isAdmin ? _buildPaymentReceiptTab() : _buildAdminOnlyWidget(),
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

  Widget _buildDailySalaryTab() {
    final topPadding = AppBarInsets.top(context, bottom: 52) + 8;
    final bottomPadding = ModernBottomNav.clearance(context) + 16;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          children: [_buildErrorWidget()],
        ),
      );
    }
    if (_dailySalaries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            _buildEmptyWidget(),
          ],
        ),
      );
    }

    return Stack(
      children: [
        _buildListWidget(_dailySalaries, topPadding, bottomPadding),
        if (_activeFilterCount > 0)
          Positioned(
            top: AppBarInsets.top(context, bottom: 52),
            left: 0,
            right: 0,
            child: _buildSummaryBar(),
          ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$_totalCount data',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Total: ${currencyFormatter.format(_totalAmount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
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

  Widget _buildListWidget(List<dynamic> displayList, double topPadding, double bottomPadding) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: displayList.length + (_hasMore ? 1 : 0),
        padding: AppSpacing.paddingMD.copyWith(
          top: topPadding + (_activeFilterCount > 0 ? 44 : 0),
          bottom: bottomPadding,
        ),
      itemBuilder: (context, index) {
        if (index == displayList.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;
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
                      if (!_isSelectionMode && _canModify(salary))
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              color: colorScheme.onSurfaceVariant),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openDailySalaryForm(
                                  Map<String, dynamic>.from(salary));
                            } else if (value == 'delete') {
                              _confirmDeleteDailySalary(
                                  Map<String, dynamic>.from(salary));
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Edit'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.delete_outline),
                                title: Text('Hapus'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
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