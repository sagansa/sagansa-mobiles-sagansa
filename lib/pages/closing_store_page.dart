import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/store_model.dart';
import '../providers/auth_provider.dart';
import '../services/closing_store_service.dart';
import '../services/presence_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/forms/form_add_button.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_text_form_field.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/status_badge.dart';
import 'fuel_service_form_page.dart';

class ClosingStorePage extends StatefulWidget {
  /// Bila true, langsung buka draft Tutup Shift aktif (dipakai saat user
  /// diarahkan dari guard check-out `CLOSING_STORE_REQUIRED`).
  final bool autoStartDraft;

  const ClosingStorePage({super.key, this.autoStartDraft = false});

  @override
  State<ClosingStorePage> createState() => _ClosingStorePageState();
}

class _ClosingStorePageState extends State<ClosingStorePage> {
  final ClosingStoreService _service = ClosingStoreService();
  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoading = false;
  String? _errorMessage;

  bool _isCreatingOrEditing = false;
  List<Map<String, dynamic>> _stores = [];
  bool _isListLoading = true;
  String? _listErrorMessage;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _scrollController = ScrollController();

  // Filter riwayat tutup shift.
  int? _filterStoreId;
  (DateTime, DateTime)? _filterDateRange;
  int? _filterStatus; // 1=belum diperiksa, 2=disetujui, 3=ditolak
  bool _isAdminUser = false;
  List<StoreModel> _storeOptions = [];

  // Active Draft Data
  Map<String, dynamic>? _closingData;
  List<dynamic> _cashlessList = [];

  // Available unpaid transactions for checkboxes
  List<dynamic> _availableFuelServices = [];
  List<dynamic> _availableDailySalaries = [];
  List<dynamic> _availableInvoicePurchases = [];

  // Selected IDs
  final Set<int> _selectedFuelServiceIds = {};
  final Set<int> _selectedDailySalaryIds = {};
  final Set<int> _selectedInvoicePurchaseIds = {};

  // Controllers
  final TextEditingController _cashForTomorrowController =
      TextEditingController(text: '0');
  final TextEditingController _totalCashTransferController =
      TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  final Map<int, TextEditingController> _cashlessControllers = {};

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _isAdminUser = Provider.of<AuthProvider>(context, listen: false).isAdmin;
    if (_isAdminUser) {
      _loadStoreOptions();
    }
    if (widget.autoStartDraft) {
      _loadData();
    } else {
      _loadClosingStores();
    }
    _scrollController.addListener(_onScroll);
  }

  /// Daftar toko untuk dropdown filter (admin saja — staff hanya melihat
  /// closing miliknya sendiri sesuai guard backend).
  Future<void> _loadStoreOptions() async {
    try {
      final stores = await PresenceService().getStores();
      if (!mounted) return;
      setState(() {
        _storeOptions = stores.where((s) => s.id > 0).toList();
      });
    } catch (_) {
      // Filter toko opsional; biarkan kosong bila gagal dimuat.
    }
  }

  int get _activeFilterCount {
    var count = 0;
    if (_filterStoreId != null) count++;
    if (_filterDateRange != null) count++;
    if (_filterStatus != null) count++;
    return count;
  }

  void _openFilterSheet() {
    final fields = <FilterField>[
      if (_isAdminUser)
        DropdownFilterField<int?>(
          label: 'Toko',
          value: _filterStoreId,
          options: [
            for (final s in _storeOptions) (s.id, s.nickname),
          ],
        ),
      DateRangeFilterField(
        label: 'Periode',
        value: _filterDateRange,
      ),
      DropdownFilterField<int?>(
        label: 'Status',
        value: _filterStatus,
        options: const [
          (1, 'Belum Diperiksa'),
          (2, 'Disetujui'),
          (3, 'Ditolak'),
        ],
      ),
    ];
    FilterBottomSheet.show(
      context,
      title: 'Filter Riwayat',
      fields: fields,
      onApply: (values) {
        setState(() {
          _filterStoreId = values['Toko'] as int?;
          _filterDateRange = values['Periode'] as (DateTime, DateTime)?;
          _filterStatus = values['Status'] as int?;
        });
        _loadClosingStores();
      },
      onReset: () {
        setState(() {
          _filterStoreId = null;
          _filterDateRange = null;
          _filterStatus = null;
        });
        _loadClosingStores();
      },
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _cashForTomorrowController.dispose();
    _totalCashTransferController.dispose();
    _notesController.dispose();
    for (var ctrl in _cashlessControllers.values) {
      ctrl.dispose();
    }
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

  Future<void> _loadClosingStores() async {
    if (!mounted) return;
    setState(() {
      _isListLoading = true;
      _listErrorMessage = null;
      _page = 1;
      _stores = [];
      _hasMore = true;
    });

    try {
      final result = await _service.getClosingStoresPaged(
        page: _page,
        storeId: _filterStoreId,
        dateFrom: _filterDateRange?.$1,
        dateTo: _filterDateRange?.$2,
        status: _filterStatus,
      );
      if (!mounted) return;
      setState(() {
        _stores = result['data'] as List<Map<String, dynamic>>;
        _hasMore = result['has_more'] as bool;
        _isListLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listErrorMessage = e.toString().replaceAll('Exception: ', '');
        _isListLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getClosingStoresPaged(
        page: _page + 1,
        storeId: _filterStoreId,
        dateFrom: _filterDateRange?.$1,
        dateTo: _filterDateRange?.$2,
        status: _filterStatus,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _stores.addAll(result['data'] as List<Map<String, dynamic>>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Widget _buildClosingStoreItem(dynamic item) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final dateStr = item['date'] ?? '';
    final storeName = item['store']?['nickname'] ?? 'Toko';
    final shiftName = item['shift_store']?['name'] ?? 'Shift';
    final totalTransfer =
        double.tryParse((item['total_cash_transfer'] ?? 0).toString()) ?? 0;
    final cashForTomorrow =
        double.tryParse((item['cash_for_tomorrow'] ?? 0).toString()) ?? 0;
    final cashFromYesterday =
        double.tryParse((item['cash_from_yesterday'] ?? 0).toString()) ?? 0;
    final creatorName =
        item['created_by']?['name'] ?? item['created_by_id']?.toString() ?? '-';

    String displayDate = dateStr;
    try {
      final parsedDate = DateTime.parse(dateStr);
      displayDate = DateFormat('dd MMMM yyyy', 'id_ID').format(parsedDate);
    } catch (_) {}

    final status = item['status'] ?? 1;
    String statusLabel = 'Belum Diperiksa';
    StatusType statusType = StatusType.warning;

    if (status == 2) {
      statusLabel = 'Disetujui';
      statusType = StatusType.success;
    } else if (status == 3) {
      statusLabel = 'Ditolak';
      statusType = StatusType.error;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: () {
          _loadSpecificClosingStore(item['id'] as int);
        },
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: AppSpacing.borderRadiusSM,
                          ),
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                        ),
                        AppSpacing.gapHorizontalSM,
                        Expanded(
                          child: Text(
                            storeName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHorizontalSM,
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: AppSpacing.borderRadiusSM,
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      shiftName,
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
                displayDate,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Divider(
                height: 20,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Setoran Kas',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormatter.format(totalTransfer),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kas Hari Sebelumnya',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormatter.format(cashFromYesterday),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Kas Besok',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormatter.format(cashForTomorrow),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Divider(
                height: 20,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      AppSpacing.gapHorizontalXS,
                      Text(
                        creatorName,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  StatusBadge(
                    label: statusLabel,
                    type: statusType,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isCreatingOrEditing = true;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Get active draft
      final draft = await _service.getActiveDraft();

      // 2. Get unpaid transactions
      final unpaid = await _service.getUnpaidTransactions();

      setState(() {
        _closingData = draft;
        _cashlessList = draft['cashlesses'] ?? [];

        // Pre-fill controllers
        _cashForTomorrowController.text =
            _moneyText(draft['cash_for_tomorrow']);
        _totalCashTransferController.text =
            _moneyText(draft['total_cash_transfer']);
        _notesController.text = FormatUtils.stripHtml(draft['notes'] ?? '');

        for (var c in _cashlessList) {
          final id = c['id'] as int;
          _cashlessControllers[id] = TextEditingController(
            text: _moneyText(c['bruto_apl']),
          );
          // Add listener to rebuild/recalculate on change
          _cashlessControllers[id]!.addListener(() {
            setState(() {});
          });
        }

        // Set selected IDs based on draft
        _selectedFuelServiceIds.clear();
        if (draft['fuel_services'] != null) {
          for (var f in draft['fuel_services']) {
            _selectedFuelServiceIds.add(f['id'] as int);
          }
        }

        _selectedDailySalaryIds.clear();
        if (draft['daily_salaries'] != null) {
          for (var s in draft['daily_salaries']) {
            _selectedDailySalaryIds.add(s['id'] as int);
          }
        }

        _selectedInvoicePurchaseIds.clear();
        if (draft['invoice_purchases'] != null) {
          for (var i in draft['invoice_purchases']) {
            _selectedInvoicePurchaseIds.add(i['id'] as int);
          }
        }

        // Load available lists (and merge currently selected ones to make sure they are in the list)
        final Map<int, dynamic> fuelMap = {};
        for (var f in unpaid['fuel_services'] ?? []) {
          fuelMap[f['id'] as int] = f;
        }
        if (draft['fuel_services'] != null) {
          for (var f in draft['fuel_services']) {
            fuelMap[f['id'] as int] = f;
          }
        }
        _availableFuelServices = fuelMap.values.toList();

        final Map<int, dynamic> salaryMap = {};
        for (var s in unpaid['daily_salaries'] ?? []) {
          salaryMap[s['id'] as int] = s;
        }
        if (draft['daily_salaries'] != null) {
          for (var s in draft['daily_salaries']) {
            salaryMap[s['id'] as int] = s;
          }
        }
        _availableDailySalaries = salaryMap.values.toList();

        final Map<int, dynamic> invoiceMap = {};
        for (var i in unpaid['invoice_purchases'] ?? []) {
          invoiceMap[i['id'] as int] = i;
        }
        if (draft['invoice_purchases'] != null) {
          for (var i in draft['invoice_purchases']) {
            invoiceMap[i['id'] as int] = i;
          }
        }
        _availableInvoicePurchases = invoiceMap.values.toList();

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSpecificClosingStore(int id) async {
    setState(() {
      _isCreatingOrEditing = true;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _service.getClosingStore(id);
      final draft = res['closing_store'];

      setState(() {
        _closingData = draft;
        _cashlessList = draft['cashlesses'] ?? [];

        // Pre-fill controllers
        _cashForTomorrowController.text =
            _moneyText(draft['cash_for_tomorrow']);
        _totalCashTransferController.text =
            _moneyText(draft['total_cash_transfer']);
        _notesController.text = FormatUtils.stripHtml(draft['notes'] ?? '');

        _cashlessControllers.clear();
        for (var c in _cashlessList) {
          final cid = c['id'] as int;
          _cashlessControllers[cid] = TextEditingController(
            text: _moneyText(c['bruto_apl']),
          );
          _cashlessControllers[cid]!.addListener(() {
            setState(() {});
          });
        }

        _selectedFuelServiceIds.clear();
        if (draft['fuel_services'] != null) {
          for (var f in draft['fuel_services']) {
            _selectedFuelServiceIds.add(f['id'] as int);
          }
        }

        _selectedDailySalaryIds.clear();
        if (draft['daily_salaries'] != null) {
          for (var s in draft['daily_salaries']) {
            _selectedDailySalaryIds.add(s['id'] as int);
          }
        }

        _selectedInvoicePurchaseIds.clear();
        if (draft['invoice_purchases'] != null) {
          for (var i in draft['invoice_purchases']) {
            _selectedInvoicePurchaseIds.add(i['id'] as int);
          }
        }

        final Map<int, dynamic> fuelMap = {};
        for (var f in res['fuel_services'] ?? []) {
          fuelMap[f['id'] as int] = f;
        }
        _availableFuelServices = fuelMap.values.toList();

        final Map<int, dynamic> salaryMap = {};
        for (var s in res['daily_salaries'] ?? []) {
          salaryMap[s['id'] as int] = s;
        }
        _availableDailySalaries = salaryMap.values.toList();

        final Map<int, dynamic> invoiceMap = {};
        for (var i in res['invoice_purchases'] ?? []) {
          invoiceMap[i['id'] as int] = i;
        }
        _availableInvoicePurchases = invoiceMap.values.toList();

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Calculations
  String _moneyText(dynamic value) =>
      FormatUtils.formatAmount(double.tryParse(value?.toString() ?? '') ?? 0);

  double get _cashFromYesterday =>
      double.tryParse((_closingData?['cash_from_yesterday'] ?? 0).toString()) ??
      0;
  double get _cashForTomorrow =>
      parseAmount(_cashForTomorrowController.text) ?? 0;
  double get _totalCashTransfer =>
      parseAmount(_totalCashTransferController.text) ?? 0;

  bool get _isEditable {
    final status = _closingData?['status'];
    if (status != null && status != 1) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.hasAnyRole(['staff'])) {
        return false;
      }
    }
    return true;
  }

  double get _totalCashless {
    double total = 0;
    for (var ctrl in _cashlessControllers.values) {
      total += parseAmount(ctrl.text) ?? 0;
    }
    return total;
  }

  double get _spendingTotalCash {
    double total = 0;
    for (var f in _availableFuelServices) {
      if (_selectedFuelServiceIds.contains(f['id'])) {
        total += double.tryParse(f['amount'].toString()) ?? 0;
      }
    }
    for (var s in _availableDailySalaries) {
      if (_selectedDailySalaryIds.contains(s['id'])) {
        total += double.tryParse(s['amount'].toString()) ?? 0;
      }
    }
    for (var i in _availableInvoicePurchases) {
      if (_selectedInvoicePurchaseIds.contains(i['id'])) {
        total += double.tryParse(i['total_price'].toString()) ?? 0;
      }
    }
    return total;
  }

  double get _totalCash {
    return _cashForTomorrow -
        _cashFromYesterday +
        _spendingTotalCash +
        _totalCashTransfer;
  }

  double get _totalOmzet {
    return _totalCash + _totalCashless;
  }

  Future<void> _submit() async {
    if (_closingData == null) return;

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'id': _closingData!['id'],
        'cash_for_tomorrow': _cashForTomorrow,
        'total_cash_transfer': _totalCashTransfer,
        'notes': _notesController.text,
        'cashlesses': _cashlessList.map((c) {
          final id = c['id'] as int;
          return {
            'id': id,
            'bruto_apl': parseAmount(_cashlessControllers[id]?.text ?? '') ?? 0,
          };
        }).toList(),
        'fuel_service_ids': _selectedFuelServiceIds.toList(),
        'daily_salary_ids': _selectedDailySalaryIds.toList(),
        'invoice_purchase_ids': _selectedInvoicePurchaseIds.toList(),
      };

      await _service.saveClosingStore(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Laporan Closing Store berhasil disimpan.')),
      );
      setState(() {
        _isCreatingOrEditing = false;
        _isSubmitting = false;
      });
      _loadClosingStores();
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Gagal Menyimpan',
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Theme.of(ctx).colorScheme.error)),
          content: Text(e.toString().replaceAll('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showAddFuelServiceBottomSheet() async {
    if (_closingData == null) return;

    final newFs = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => FuelServiceFormPage(
          closingStoreId: _closingData!['id'] as int,
          isCashOnly: true,
        ),
      ),
    );

    if (newFs != null && mounted) {
      setState(() {
        _availableFuelServices.insert(0, newFs);
        _selectedFuelServiceIds.add(newFs['id'] as int);
      });
      showSuccessSnackBar(
        context,
        'Pengeluaran ${newFs['fuel_service'] == 1 ? 'bensin' : 'servis'} berhasil ditambahkan ke shift.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (!_isCreatingOrEditing) {
      return Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: const Text('Riwayat Tutup Shift'),
          actions: [
            BarButtonCluster(
              actions: [
                BarButtonSpec(
                  icon: Icons.tune,
                  tooltip: 'Filter Riwayat',
                  badgeCount: _activeFilterCount,
                  onTap: _openFilterSheet,
                ),
                BarButtonSpec(
                  icon: Icons.add_rounded,
                  iconSize: 22,
                  tooltip: 'Tambah Closing Store',
                  onTap: _loadData,
                ),
              ],
            ),
          ],
        ),
        body: _isListLoading
            ? const Center(child: CircularProgressIndicator())
            : _listErrorMessage != null
                ? Center(
                    child: Padding(
                      padding: AppSpacing.paddingLG,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: AppColors.error),
                          AppSpacing.gapVerticalMD,
                          Text(
                            _listErrorMessage!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge,
                          ),
                          AppSpacing.gapVerticalLG,
                          ElevatedButton(
                            onPressed: _loadClosingStores,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _stores.isEmpty
                    ? const EmptyState(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'Belum ada laporan tutup shift.',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadClosingStores,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: AppSpacing.paddingMD
                              .copyWith(top: AppBarInsets.top(context)),
                          itemCount: _stores.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _stores.length) {
                              return const Padding(
                                padding: EdgeInsets.all(AppSpacing.md),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            return _buildClosingStoreItem(_stores[index]);
                          },
                        ),
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

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: GlassAppBar(
          title: const Text('Tutup Shift Toko'),
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isCreatingOrEditing = false;
              });
              _loadClosingStores();
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLG,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: AppColors.error),
                AppSpacing.gapVerticalMD,
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
                AppSpacing.gapVerticalLG,
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final storeName = _closingData?['store']?['nickname'] ?? 'Toko';
    final shiftName = _closingData?['shift_store']?['name'] ?? 'Shift';
    final closingDate = _closingData?['date'] ?? '-';
    final creatorName = _closingData?['created_by']?['name'] ??
        _closingData?['created_by_id']?.toString() ??
        '-';

    String displayDate = closingDate;
    try {
      final parsedDate = DateTime.parse(closingDate);
      displayDate = DateFormat('dd MMMM yyyy', 'id_ID').format(parsedDate);
    } catch (_) {}

    final status = _closingData?['status'] ?? 1;
    String statusLabel = 'Belum Diperiksa';
    StatusType statusType = StatusType.warning;

    if (status == 2) {
      statusLabel = 'Disetujui';
      statusType = StatusType.success;
    } else if (status == 3) {
      statusLabel = 'Ditolak';
      statusType = StatusType.error;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _isCreatingOrEditing = false;
        });
        _loadClosingStores();
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: const Text('Tutup Shift Toko'),
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isCreatingOrEditing = false;
              });
              _loadClosingStores();
            },
          ),
          actions: [
            BarButtonCluster(
              actions: [
                BarButtonSpec(
                  icon: Icons.refresh,
                  tooltip: 'Muat ulang',
                  onTap: _loadData,
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _isEditable
            ? SafeBottomBar(
                child: ModernButton(
                  text: 'Simpan & Selesaikan Shift',
                  onPressed: _isSubmitting ? null : _submit,
                  isLoading: _isSubmitting,
                  height: 52,
                ),
              )
            : null,
        body: SingleChildScrollView(
          padding:
              AppSpacing.paddingMD.copyWith(top: AppBarInsets.top(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isEditable)
                Container(
                  width: double.infinity,
                  padding: AppSpacing.paddingMD,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: AppSpacing.borderRadiusMD,
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          color: AppColors.warning, size: 20),
                      AppSpacing.gapHorizontalMD,
                      Expanded(
                        child: Text(
                          'Laporan Closing Store ini telah diperiksa oleh admin dan tidak dapat diedit lagi.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Header Section Card
              DetailSectionCard(
                icon: Icons.storefront_outlined,
                title: 'Informasi Toko & Shift',
                trailing: StatusBadge(
                  label: statusLabel,
                  type: statusType,
                ),
                children: [
                  DetailRow(label: 'Toko', value: storeName, valueBold: true),
                  DetailRow(label: 'Shift', value: shiftName),
                  DetailRow(label: 'Tanggal', value: displayDate),
                  if (creatorName.isNotEmpty && creatorName != '-')
                    DetailRow(label: 'Kasir', value: creatorName),
                ],
              ),
              AppSpacing.gapVerticalMD,

              // Cash Info Section
              DetailSectionCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Aliran Kas Laci Kasir (Cash)',
                children: [
                  DetailRow(
                    label: 'Saldo Kas Awal',
                    value: currencyFormatter.format(_cashFromYesterday),
                    valueBold: true,
                  ),
                  Divider(
                    height: 16,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  if (_isEditable) ...[
                    ModernTextFormField(
                      controller: _cashForTomorrowController,
                      labelText: 'Kas Untuk Besok *',
                      prefixText: 'Rp ',
                      keyboardType: TextInputType.number,
                      inputFormatters: rupiahInputFormatters,
                      onChanged: (val) => setState(() {}),
                    ),
                    AppSpacing.gapVerticalSM,
                    ModernTextFormField(
                      controller: _totalCashTransferController,
                      labelText: 'Total Setoran Cash (Bank Transfer) *',
                      prefixText: 'Rp ',
                      keyboardType: TextInputType.number,
                      inputFormatters: rupiahInputFormatters,
                      onChanged: (val) => setState(() {}),
                    ),
                  ] else ...[
                    DetailRow(
                      label: 'Kas Untuk Besok',
                      value: currencyFormatter.format(_cashForTomorrow),
                      valueBold: true,
                    ),
                    DetailRow(
                      label: 'Total Setoran Cash',
                      value: currencyFormatter.format(_totalCashTransfer),
                      valueBold: true,
                    ),
                  ],
                ],
              ),
              AppSpacing.gapVerticalMD,

              // Cashless List Section
              if (_cashlessList.isNotEmpty) ...[
                DetailSectionCard(
                  icon: Icons.credit_card_outlined,
                  title: 'Laporan EDC / Cashless',
                  children: _cashlessList.map((c) {
                    final id = c['id'] as int;
                    final providerName = c['account_cashless']
                            ?['cashless_provider']?['name'] ??
                        'Provider';
                    final storeCashlessName =
                        c['account_cashless']?['store_cashless']?['name'] ?? '';
                    final label = storeCashlessName.isNotEmpty
                        ? '$providerName ($storeCashlessName)'
                        : providerName;
                    if (_isEditable) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ModernTextFormField(
                          controller: _cashlessControllers.putIfAbsent(
                            id,
                            () => TextEditingController(),
                          ),
                          labelText: label,
                          prefixText: 'Rp ',
                          keyboardType: TextInputType.number,
                          inputFormatters: rupiahInputFormatters,
                          onChanged: (val) => setState(() {}),
                        ),
                      );
                    } else {
                      final val =
                          parseAmount(_cashlessControllers[id]?.text ?? '') ??
                              0;
                      return DetailRow(
                        label: label,
                        value: currencyFormatter.format(val),
                        valueBold: true,
                      );
                    }
                  }).toList(),
                ),
                AppSpacing.gapVerticalMD,
              ],

              // Spending Lists
              DetailSectionCard(
                icon: Icons.local_gas_station_outlined,
                title: 'Pengeluaran Bensin & Servis (Cash)',
                trailing: _isEditable
                    ? FormAddButton(
                        label: 'Tambah',
                        onPressed: _showAddFuelServiceBottomSheet,
                      )
                    : null,
                child: _buildFuelServicesList(colorScheme),
              ),
              AppSpacing.gapVerticalMD,

              DetailSectionCard(
                icon: Icons.people_outline,
                title: 'Pengeluaran Gaji Harian (Cash)',
                child: _buildDailySalariesList(colorScheme),
              ),
              AppSpacing.gapVerticalMD,

              DetailSectionCard(
                icon: Icons.receipt_long_outlined,
                title: 'Pengeluaran Invoice & Bon (Cash)',
                child: _buildInvoicePurchasesList(colorScheme),
              ),
              AppSpacing.gapVerticalLG,

              // Financial Summary Card
              _buildFinancialSummaryCard(colorScheme, textTheme),
              AppSpacing.gapVerticalLG,

              // Notes Section
              DetailSectionCard(
                icon: Icons.notes_outlined,
                title: 'Catatan Closing',
                child: _isEditable
                    ? ModernTextFormField(
                        labelText: 'Tuliskan catatan closing...',
                        controller: _notesController,
                        maxLines: 3,
                      )
                    : Text(
                        _notesController.text.trim().isEmpty
                            ? 'Tidak ada catatan.'
                            : _notesController.text,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              AppSpacing.gapVerticalLG,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryCard(
      ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.borderRadiusSM,
                ),
                child: Icon(
                  Icons.calculate_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              AppSpacing.gapHorizontalSM,
              Text(
                'Ringkasan Finansial Shift',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Saldo Kas Awal',
            currencyFormatter.format(_cashFromYesterday),
            colorScheme,
          ),
          _buildSummaryRow(
            'Total Pengeluaran Laci (Cash)',
            currencyFormatter.format(_spendingTotalCash),
            colorScheme,
          ),
          _buildSummaryRow(
            'Total Setoran Kas (Transfer)',
            currencyFormatter.format(_totalCashTransfer),
            colorScheme,
          ),
          _buildSummaryRow(
            'Kas Untuk Besok',
            currencyFormatter.format(_cashForTomorrow),
            colorScheme,
          ),
          _buildSummaryRow(
            'Total Cashless / EDC',
            currencyFormatter.format(_totalCashless),
            colorScheme,
          ),
          _buildSummaryRow(
            'Total Cash Fisik Laci',
            currencyFormatter.format(_totalCash),
            colorScheme,
            isBold: true,
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            color: colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Total Omzet Toko Hari Ini',
            currencyFormatter.format(_totalOmzet),
            colorScheme,
            isBold: true,
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    ColorScheme colorScheme, {
    bool isBold = false,
    bool large = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                (large ? textTheme.titleSmall : textTheme.bodyMedium)?.copyWith(
              fontWeight:
                  (isBold || large) ? FontWeight.bold : FontWeight.normal,
              color: large ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: (large ? textTheme.titleMedium : textTheme.bodyMedium)
                ?.copyWith(
              fontWeight: (isBold || large) ? FontWeight.bold : FontWeight.w600,
              color: large ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableItemTile({
    required bool isChecked,
    required String title,
    required String subtitle,
    required String amountText,
    required VoidCallback? onTap,
    required IconData icon,
    required ColorScheme colorScheme,
    Color? iconColor,
    Color? iconBgColor,
    String? badgeText,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveIconColor = iconColor ??
        (isChecked ? colorScheme.primary : colorScheme.onSurfaceVariant);
    final effectiveIconBg = iconBgColor ??
        (isChecked
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isChecked
            ? colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.05)
            : colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isChecked
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: isChecked ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMD,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (onTap != null) ...[
                  Checkbox(
                    value: isChecked,
                    onChanged: (_) => onTap(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  AppSpacing.gapHorizontalSM,
                ],
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: effectiveIconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: effectiveIconColor,
                  ),
                ),
                AppSpacing.gapHorizontalSM,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? colorScheme.primary)
                                    .withValues(alpha: 0.15),
                                borderRadius: AppSpacing.borderRadiusXS,
                              ),
                              child: Text(
                                badgeText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: badgeColor ?? colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapHorizontalSM,
                Text(
                  amountText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String message, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          AppSpacing.gapHorizontalSM,
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelServicesList(ColorScheme colorScheme) {
    if (_availableFuelServices.isEmpty) {
      return _buildEmptyPlaceholder(
        'Tidak ada pengeluaran bensin/servis tunai',
        Icons.local_gas_station_outlined,
      );
    }
    return Column(
      children: _availableFuelServices.map((f) {
        final id = f['id'] as int;
        final isChecked = _selectedFuelServiceIds.contains(id);
        final date = f['date'] ?? '';
        final amount = double.tryParse(f['amount'].toString()) ?? 0;
        final isFuel = f['fuel_service'] == 1;
        final typeStr = isFuel ? 'BBM' : 'Servis';
        final vehicleNo = f['vehicle']?['no_register'] ?? '';
        final vehicleName = f['vehicle']?['name'] ?? '';
        final vehicleLabel = [vehicleNo, vehicleName]
            .where((s) => s.toString().isNotEmpty)
            .join(' - ');
        final title = vehicleLabel.isNotEmpty ? vehicleLabel : typeStr;

        final liter = double.tryParse(f['liter']?.toString() ?? '0') ?? 0;
        final subtitleParts = <String>[];
        if (date.toString().isNotEmpty) subtitleParts.add(date.toString());
        if (isFuel && liter > 0) {
          subtitleParts.add('${liter.toStringAsFixed(1)} Liter');
        }
        final subtitle = subtitleParts.isNotEmpty
            ? subtitleParts.join(' • ')
            : date.toString();

        return _buildSelectableItemTile(
          isChecked: isChecked,
          title: title,
          subtitle: subtitle,
          amountText: currencyFormatter.format(amount),
          icon: isFuel
              ? Icons.local_gas_station_rounded
              : Icons.build_circle_rounded,
          iconColor: isFuel ? AppColors.success : AppColors.warning,
          iconBgColor: (isFuel ? AppColors.success : AppColors.warning)
              .withValues(alpha: 0.12),
          badgeText: typeStr,
          badgeColor: isFuel ? AppColors.success : AppColors.warning,
          colorScheme: colorScheme,
          onTap: _isEditable
              ? () {
                  setState(() {
                    if (isChecked) {
                      _selectedFuelServiceIds.remove(id);
                    } else {
                      _selectedFuelServiceIds.add(id);
                    }
                  });
                }
              : null,
        );
      }).toList(),
    );
  }

  Widget _buildDailySalariesList(ColorScheme colorScheme) {
    if (_availableDailySalaries.isEmpty) {
      return _buildEmptyPlaceholder(
        'Tidak ada pengeluaran gaji harian tunai',
        Icons.people_outline,
      );
    }
    return Column(
      children: _availableDailySalaries.map((s) {
        final id = s['id'] as int;
        final isChecked = _selectedDailySalaryIds.contains(id);
        final date = s['date'] ?? '';
        final amount = double.tryParse(s['amount'].toString()) ?? 0;
        final employeeName = s['user']?['name'] ?? 'Pegawai';

        return _buildSelectableItemTile(
          isChecked: isChecked,
          title: employeeName,
          subtitle: date,
          amountText: currencyFormatter.format(amount),
          icon: Icons.person_outline,
          colorScheme: colorScheme,
          onTap: _isEditable
              ? () {
                  setState(() {
                    if (isChecked) {
                      _selectedDailySalaryIds.remove(id);
                    } else {
                      _selectedDailySalaryIds.add(id);
                    }
                  });
                }
              : null,
        );
      }).toList(),
    );
  }

  Widget _buildInvoicePurchasesList(ColorScheme colorScheme) {
    if (_availableInvoicePurchases.isEmpty) {
      return _buildEmptyPlaceholder(
        'Tidak ada pengeluaran invoice/bon tunai',
        Icons.receipt_long_outlined,
      );
    }
    return Column(
      children: _availableInvoicePurchases.map((i) {
        final id = i['id'] as int;
        final isChecked = _selectedInvoicePurchaseIds.contains(id);
        final date = i['date'] ?? '';
        final amount = double.tryParse(i['total_price'].toString()) ?? 0;
        final invoiceNo = i['no_invoice']?.toString() ?? '';
        final supplierName = i['supplier']?['name']?.toString() ?? '';
        final title = invoiceNo.isNotEmpty
            ? 'Invoice #$invoiceNo'
            : (supplierName.isNotEmpty ? supplierName : 'Invoice');

        return _buildSelectableItemTile(
          isChecked: isChecked,
          title: title,
          subtitle: date,
          amountText: currencyFormatter.format(amount),
          icon: Icons.receipt_long_outlined,
          colorScheme: colorScheme,
          onTap: _isEditable
              ? () {
                  setState(() {
                    if (isChecked) {
                      _selectedInvoicePurchaseIds.remove(id);
                    } else {
                      _selectedInvoicePurchaseIds.add(id);
                    }
                  });
                }
              : null,
        );
      }).toList(),
    );
  }
}
