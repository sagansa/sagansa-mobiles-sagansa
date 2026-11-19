import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/salary_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_dropdown.dart';
import 'salary_detail_page.dart';

class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key});

  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final ScrollController _scrollController = ScrollController();

  final SalaryService _salaryService = SalaryService();
  List<Map<String, dynamic>> salaryHistory = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Role & filters
  bool _isAdmin = false;
  List<Map<String, dynamic>> _employees = [];
  int? _selectedUserId;
  String? _selectedPeriod; // YYYY-MM, null = semua
  String? _selectedStatus; // null=Semua, draft/processing/paid

  // Pagination (admin)
  int _currentPage = 1;
  bool _hasMore = true;

  // Selection mode & generate (admin)
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};
  bool _isGenerating = false;

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
        // NOTE: super_admin sengaja TIDAK diakui sebagai admin untuk fitur gaji
        // (keputusan spesifik). Jangan tambahkan super_admin di sini.
        if (mounted) {
          setState(() {
            _isAdmin = userRoles.contains('admin');
          });
        }
      }
    } catch (_) {}
    await _loadData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        _isAdmin) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      List<Map<String, dynamic>> data;
      if (_isAdmin) {
        final result = await _salaryService.getSalaryHistoryAdmin(
          page: 1,
          userId: _selectedUserId,
          period: _selectedPeriod,
          status: _selectedStatus,
        );
        data = (result['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final meta = result['meta'] as Map<String, dynamic>;
        _hasMore = _currentPage < (meta['last_page'] ?? 1);
        // Load employees list for filter (once)
        if (_employees.isEmpty) _loadEmployees();
      } else {
        data = await _salaryService.getSalaryHistory();
      }
      if (!mounted) return;
      setState(() {
        salaryHistory = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat riwayat gaji: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _salaryService.getEmployeesForSalary();
      if (mounted) setState(() => _employees = employees);
    } catch (_) {
      // Abaikan; dropdown tetap "Semua"
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _salaryService.getSalaryHistoryAdmin(
        page: _currentPage + 1,
        userId: _selectedUserId,
        period: _selectedPeriod,
        status: _selectedStatus,
      );
      final data = (result['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final meta = result['meta'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        salaryHistory.addAll(data);
        _currentPage++;
        _hasMore = _currentPage < (meta['last_page'] ?? 1);
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedUserId = null;
      _selectedPeriod = null;
      _selectedStatus = null;
    });
    _loadData();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedUserId != null) count++;
    if (_selectedPeriod != null) count++;
    if (_selectedStatus != null) count++;
    return count;
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter Gaji',
      fields: [
        if (_isAdmin)
          DropdownFilterField<int>(
            label: 'Karyawan',
            value: _selectedUserId,
            options: _employees.map((e) => (
              e['id'] as int,
              e['name']?.toString() ?? 'Karyawan #${e['id']}',
            )).toList(),
          ),
        DropdownFilterField<String>(
          label: 'Periode',
          value: _selectedPeriod,
          options: List.generate(12, (i) {
            final d = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
            final period = '${d.year}-${d.month.toString().padLeft(2, '0')}';
            return (period, DateFormat('MMMM yyyy', 'id_ID').format(d));
          }),
        ),
        DropdownFilterField<String>(
          label: 'Status',
          value: _selectedStatus,
          options: const [
            ('draft', 'Draft'),
            ('pending', 'Menunggu Persetujuan'),
            ('approved', 'Disetujui'),
            ('rejected', 'Ditolak'),
            ('paid', 'Dibayar'),
          ],
        ),
      ],
      onApply: (values) {
        setState(() {
          _selectedUserId = values['Karyawan'] as int?;
          _selectedPeriod = values['Periode'] as String?;
          _selectedStatus = values['Status'] as String?;
        });
        _loadData();
      },
      onReset: () {
        _clearFilters();
      },
    );
  }

  void _showGenerateDialog() {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
      'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Generate/Regenerate Payroll'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModernDropdown<int>(
                  value: selectedMonth,
                  labelText: 'Bulan',
                  hint: 'Pilih bulan...',
                  items: List.generate(12, (i) => i + 1),
                  getLabel: (i) => months[i - 1],
                  onChanged: (v) => setDialogState(() => selectedMonth = v!),
                ),
                AppSpacing.gapVerticalSM,
                ModernDropdown<int>(
                  value: selectedYear,
                  labelText: 'Tahun',
                  hint: 'Pilih tahun...',
                  items: List.generate(7, (i) => 2024 + i),
                  getLabel: (y) => '$y',
                  onChanged: (v) => setDialogState(() => selectedYear = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              FilledButton(
                onPressed: _isGenerating
                    ? null
                    : () async {
                        setDialogState(() => _isGenerating = true);
                        try {
                          final result = await _salaryService.generatePayroll(
                              month: selectedMonth, year: selectedYear);
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(result['message'] ?? 'Selesai.')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() => _isGenerating = false);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      e.toString().replaceAll('Exception: ', ''))),
                            );
                          }
                        }
                      },
                child: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Generate'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _bulkApprove() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text('Approve ${_selectedIds.length} slip?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final count =
          await _salaryService.bulkApproveSalaries(_selectedIds.toList());
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$count slip di-approve.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
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

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    final bool isDark = colorScheme.brightness == Brightness.dark;
    switch (status) {
      case 'draft':
        return isDark
            ? AppColors.darkOnSurfaceVariant
            : colorScheme.outline;
      case 'paid':
        return isDark ? AppColors.success : AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.info;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'paid':
        return 'Dibayarkan';
      case 'pending':
        return 'Menunggu';
      case 'processing':
        return 'Diproses';
      default:
        return 'Unknown';
    }
  }

  Widget _buildSalaryCard(Map<String, dynamic> salary) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final DateTime periodDate = _resolvePeriodDate(salary['period']);
    final DateTime? paymentDate = salary['paymentDate'] != null
        ? DateTime.parse(salary['paymentDate'])
        : null;
    final String userName = salary['user_name'] ?? '';
    final int salaryId = salary['id'];
    final bool isSelected = _selectedIds.contains(salaryId);

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: _isSelectionMode
            ? () => _toggleSelection(salaryId)
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SalaryDetailPage(
                      salaryId: salaryId,
                      userName: _isAdmin ? userName : null,
                    ),
                  ),
                );
              },
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            children: [
              if (_isAdmin && userName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 18, color: AppColors.info),
                      AppSpacing.gapHorizontalSM,
                      Expanded(
                        child: Text(
                          userName,
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outline,
                          ),
                        ),
                      Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(periodDate),
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: _getStatusColor(salary['status'], colorScheme)
                          .withValues(alpha: 0.1),
                      borderRadius: AppSpacing.borderRadiusMD,
                    ),
                    child: Text(
                      _getStatusText(salary['status']),
                      style: textTheme.labelMedium?.copyWith(
                        color: _getStatusColor(salary['status'], colorScheme),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sectionGap),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currencyFormatter.format(salary['amount']),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.brightness == Brightness.dark
                          ? colorScheme.onSurface
                          : AppColors.primary,
                    ),
                  ),
                  if (paymentDate != null)
                    Text(
                      'Dibayar: ${DateFormat('dd/MM/yyyy').format(paymentDate)}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: Text(_isSelectionMode
            ? '${_selectedIds.length} dipilih'
            : 'Riwayat Gaji'),
        actions: [
          BarButtonCluster(
            actions: [
              if (_isAdmin) ...[
                if (_isSelectionMode) ...[
                  BarButtonSpec(
                    icon: Icons.check_circle,
                    tooltip: 'Bulk Approve',
                    onTap: _bulkApprove,
                  ),
                  BarButtonSpec(
                    icon: Icons.close,
                    tooltip: 'Tutup',
                    onTap: _toggleSelectionMode,
                  ),
                ] else ...[
                  BarButtonSpec(
                    icon: Icons.auto_graph,
                    tooltip: 'Generate Payroll',
                    onTap: _showGenerateDialog,
                  ),
                  BarButtonSpec(
                    icon: Icons.checklist,
                    tooltip: 'Pilih untuk Bulk Approve',
                    onTap: _toggleSelectionMode,
                  ),
                ],
              ],
              if (_isAdmin && !_isSelectionMode)
                BarButtonSpec(
                  icon: Icons.tune,
                  tooltip: 'Filter',
                  badgeCount: _activeFilterCount,
                  onTap: _openFilterSheet,
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
          children: [
            if (!_isAdmin)
              Container(
                padding: AppSpacing.paddingMD,
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info),
                    AppSpacing.gapHorizontalSM,
                    Expanded(
                      child: Text(
                        'Gaji bulanan dihitung berdasarkan periode cut-off yang dikonfigurasi HRD.',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildBody(colorScheme, textTheme),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLG,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
              AppSpacing.gapVerticalMD,
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (salaryHistory.isEmpty) {
      return Center(
        child: Text('Belum ada riwayat slip gaji bulanan.'),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: salaryHistory.length + (_hasMore && _isAdmin ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == salaryHistory.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildSalaryCard(salaryHistory[index]);
      },
    );
  }

  /// Resolve salary period date: jika tanggal >= 26 (cutoff),
  /// bulan gaji adalah bulan berikutnya (e.g. 26 Mei → Juni).
  DateTime _resolvePeriodDate(dynamic period) {
    final dt = DateTime.parse(period.toString());
    if (dt.day >= 26) {
      return DateTime(dt.year, dt.month + 1, 1);
    }
    return DateTime(dt.year, dt.month, 1);
  }
}
