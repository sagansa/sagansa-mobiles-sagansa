import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/procurement_model.dart';
import '../providers/auth_provider.dart';
import '../services/procurement_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/payment_receipt_card.dart';
import 'invoice_selection_page.dart';
import 'payment_receipt_detail_page.dart';

class PaymentReceiptDashboardPage extends StatefulWidget {
  const PaymentReceiptDashboardPage({super.key});

  @override
  State<PaymentReceiptDashboardPage> createState() =>
      _PaymentReceiptDashboardPageState();
}

class _PaymentReceiptDashboardPageState
    extends State<PaymentReceiptDashboardPage> {
  final ProcurementService _procurementService = ProcurementService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<PaymentReceipt> _receipts = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _errorMessage;

  // Filter states: '0' = All, '1' = Fuel Service, '2' = Gaji Harian, '3' = Invoice Supplier
  String _selectedPaymentFor = '0';
  String _searchQuery = '';

  // Search toggle
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchReceipts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetchReceipts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _receipts = [];
      _hasMore = true;
    });

    try {
      final result = await _procurementService.getPaymentReceipts(page: 1);
      if (!mounted) return;
      setState(() {
        _receipts = result.items;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat payment receipt: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final result =
          await _procurementService.getPaymentReceipts(page: _currentPage + 1);
      if (!mounted) return;
      setState(() {
        _receipts.addAll(result.items);
        _hasMore = result.hasMore;
        _currentPage++;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  int get _activeFilterCount => _selectedPaymentFor != '0' ? 1 : 0;

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter',
      fields: [
        DropdownFilterField<String>(
          label: 'Tipe Pembayaran',
          value: _selectedPaymentFor,
          options: const [
            ('0', 'Semua'),
            ('3', 'Invoice'),
            ('2', 'Gaji Harian'),
            ('1', 'Fuel Service'),
          ],
        ),
      ],
      onApply: (values) {
        setState(() {
          _selectedPaymentFor = values['Tipe Pembayaran'] as String? ?? '0';
        });
      },
      onReset: () => setState(() => _selectedPaymentFor = '0'),
    );
  }

  List<PaymentReceipt> get _filteredReceipts {
    return _receipts.where((receipt) {
      // Type Filter
      if (_selectedPaymentFor != '0' && receipt.paymentFor != _selectedPaymentFor) {
        return false;
      }
      // Search Filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchId = receipt.id.toString().contains(query);
        final matchSupplier =
            (receipt.supplierName ?? '').toLowerCase().contains(query);
        final matchNotes = (receipt.notes ?? '').toLowerCase().contains(query);
        return matchId || matchSupplier || matchNotes;
      }
      return true;
    }).toList();
  }

  int get _totalFilteredAmount {
    return _filteredReceipts.fold(0, (sum, item) => sum + item.transferAmount);
  }

  Widget _buildSummaryCard(ThemeData theme, bool isDark) {
    final totalAmountFormatted = FormatUtils.formatCurrency(_totalFilteredAmount);
    final count = _filteredReceipts.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.darkSecondaryContainer, AppColors.darkBackground]
              : [AppColors.primary, AppColors.darkSurfaceVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.borderRadiusLG,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL BUKTI TRANSFER',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: isDark ? AppColors.gold : AppColors.gold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: AppSpacing.borderRadiusMD,
                ),
                child: Text(
                  '$count Receipt',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalSM,
          Text(
            totalAmountFormatted,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          AppSpacing.gapVerticalXS,
          Text(
            'Ringkasan pengeluaran bukti pembayaran terdata',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final filters = [
      {'id': '0', 'label': 'Semua'},
      {'id': '3', 'label': 'Invoice'},
      {'id': '2', 'label': 'Gaji Harian'},
      {'id': '1', 'label': 'Fuel Service'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedPaymentFor == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedPaymentFor = f['id']!);
                }
              },
              selectedColor: AppColors.gold,
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black : theme.colorScheme.onSurface,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final filtered = _filteredReceipts;
    final canCreate = !context
        .watch<AuthProvider>()
        .hasAnyRole(['staff', 'storage-staff']);

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('Payment Receipt'),
        elevation: 0,
        actions: [
          BarButtonCluster(actions: [
            BarButtonSpec(
              icon: _searchExpanded ? Icons.search_off : Icons.search,
              tooltip: _searchExpanded ? 'Tutup Pencarian' : 'Cari',
              onTap: () => setState(() => _searchExpanded = !_searchExpanded),
            ),
            BarButtonSpec(
              icon: Icons.tune,
              tooltip: 'Filter',
              badgeCount: _activeFilterCount,
              onTap: _openFilterSheet,
            ),
            if (canCreate)
              BarButtonSpec(
                icon: Icons.add_rounded,
                iconSize: 22,
                tooltip: 'Tambah Payment Receipt',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvoiceSelectionPage(),
                    ),
                  ).then((_) => _fetchReceipts());
                },
              ),
          ]),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Togglable Search Bar
          if (_searchExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Cari supplier, nomor receipt, catatan...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Bersihkan pencarian',
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  filled: true,
                  fillColor: isDark
                      ? theme.cardColor
                      : AppColors.surfaceVariant.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.borderRadiusMD,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          // Filter chips (1 slot inline — ≤1 filter rule)
          _buildFilterChips(theme),

          // Main List View (summary card moved inside)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: AppSpacing.paddingLG,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage!,
                                style: TextStyle(color: colorScheme.error),
                                textAlign: TextAlign.center,
                              ),
                              AppSpacing.gapVerticalMD,
                              ElevatedButton(
                                onPressed: _fetchReceipts,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 56,
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                ),
                                AppSpacing.gapVerticalMD,
                                Text(
                                  _searchQuery.isNotEmpty || _selectedPaymentFor != '0'
                                      ? 'Tidak ada receipt yang sesuai filter.'
                                      : 'Belum ada payment receipt.',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchReceipts,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(AppSpacing.md).copyWith(
                                  bottom:
                                      ModernBottomNav.clearance(context)),
                              itemCount: filtered.length + (_loadingMore ? 1 : 1), // +1 for summary
                              itemBuilder: (context, idx) {
                                if (idx == 0) {
                                  return _buildSummaryCard(theme, isDark);
                                }
                                final listIdx = idx - 1;
                                if (listIdx == filtered.length && _loadingMore) {
                                  return const Padding(
                                    padding: AppSpacing.paddingMD,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                }
                                if (listIdx >= filtered.length) return const SizedBox.shrink();
                                final receipt = filtered[listIdx];
                                return PaymentReceiptCard(
                                  receipt: receipt,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PaymentReceiptDetailPage(
                                          receiptId: receipt.id,
                                        ),
                                      ),
                                    ).then((_) => _fetchReceipts());
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
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
}
