import 'package:flutter/material.dart';

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
import 'create_invoice_form_page.dart';
import 'invoice_detail_page.dart';

class InvoiceDashboardPage extends StatefulWidget {
  const InvoiceDashboardPage({super.key});

  @override
  State<InvoiceDashboardPage> createState() => _InvoiceDashboardPageState();
}

class _InvoiceDashboardPageState extends State<InvoiceDashboardPage>
    with SingleTickerProviderStateMixin {
  final ProcurementService _procurementService = ProcurementService();
  final StoreService _storeService = StoreService();
  final List<ScrollController> _scrollControllers =
      List.generate(5, (_) => ScrollController());

  List<InvoicePurchase> _invoices = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _errorMessage;
  late TabController _tabController;
  int? _selectedStoreId;
  List<StoreModel> _stores = [];

  bool get _hasActiveFilter => _selectedStoreId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadFilterData();
    for (final c in _scrollControllers) {
      c.addListener(_onScroll);
    }
    _fetchInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    final controller = _scrollControllers[_tabController.index];
    if (controller.hasClients &&
        controller.position.pixels >=
            controller.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetchInvoices() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _invoices = [];
      _hasMore = true;
    });

    try {
      final result =
          await _procurementService.getInvoices(page: 1, storeId: _selectedStoreId);
      if (!mounted) return;
      setState(() {
        _invoices = result.items;
        _hasMore = result.hasMore;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat invoice: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final result = await _procurementService.getInvoices(
          page: _currentPage + 1, storeId: _selectedStoreId);
      if (!mounted) return;
      setState(() {
        _invoices.addAll(result.items);
        _hasMore = result.hasMore;
        _currentPage++;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
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
      title: 'Filter Invoice',
      fields: [
        DropdownFilterField<int>(
          label: 'Toko',
          value: _selectedStoreId,
          options: _stores.map((s) => (s.id, s.nickname)).toList(),
        ),
      ],
      onApply: (values) {
        setState(() => _selectedStoreId = values['Toko'] as int?);
        _fetchInvoices();
      },
      onReset: () {
        setState(() => _selectedStoreId = null);
        _fetchInvoices();
      },
    );
  }

  void _clearFilters() {
    setState(() => _selectedStoreId = null);
    _fetchInvoices();
  }

  List<InvoicePurchase> _getFilteredInvoices(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _invoices.where((inv) => inv.paymentStatus == '1').toList();
      case 2:
        return _invoices.where((inv) => inv.paymentStatus == '2').toList();
      case 3:
        return _invoices.where((inv) => inv.orderStatus == '1').toList();
      case 4:
        return _invoices
            .where((inv) => inv.orderStatus == '2' && inv.paymentStatus == '2')
            .toList();
      default:
        return _invoices;
    }
  }

  Color _paymentStatusColor(String status) {
    switch (status) {
      case '1':
        return AppColors.warning;
      case '2':
        return AppColors.success;
      case '3':
        return AppColors.error;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  Color _orderStatusColor(String status) {
    switch (status) {
      case '1':
        return AppColors.warning;
      case '2':
        return AppColors.success;
      case '3':
        return AppColors.error;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  void _showInvoiceImage(BuildContext context, String url) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image,
                            color: Colors.grey, size: 36),
                        AppSpacing.gapVerticalSM,
                        Text(
                          'Gagal memuat gambar',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: 'Tutup',
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('Invoice Purchase'),
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
              tooltip: 'Tambah Invoice',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateInvoiceFormPage(),
                  ),
                );
                if (result == true) {
                  _fetchInvoices();
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
            Tab(text: 'Belum Dibayar'),
            Tab(text: 'Sudah Dibayar'),
            Tab(text: 'Belum Diterima'),
            Tab(text: 'Selesai'),
          ],
        ),
      ),
      body: _isLoading
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
                          onPressed: _fetchInvoices,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(5, (index) {
                    final invoices = _getFilteredInvoices(index);
                    if (invoices.isEmpty && !_hasMore) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 48,
                              color: AppColors.info.withValues(alpha: 0.5),
                            ),
                            AppSpacing.gapVerticalMD,
                            Text(
                              'Tidak ada data invoice.',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _fetchInvoices,
                      child: ListView.builder(
                        controller: _scrollControllers[index],
                        padding: AppSpacing.paddingMD.copyWith(
              top: AppBarInsets.top(context),
              bottom: ModernBottomNav.clearance(context)),
                        itemCount: invoices.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, idx) {
                          if (idx == invoices.length) {
                            return const Padding(
                              padding: AppSpacing.paddingMD,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final invoice = invoices[idx];
                          return Card(
                            margin: const EdgeInsets.only(
                                bottom: AppSpacing.sectionGap),
                            child: InkWell(
                              borderRadius: AppSpacing.borderRadiusLG,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => InvoiceDetailPage(
                                        invoiceId: invoice.id),
                                  ),
                                ).then((result) {
                                  if (result == true) _fetchInvoices();
                                });
                              },
                              child: Padding(
                                padding: AppSpacing.paddingMD,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            invoice.storeName,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Rp ${invoice.totalPrice != 0 ? invoice.totalPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match.group(1)}.') : '0'}',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    AppSpacing.gapVerticalSM,
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Tanggal: ${invoice.date}',
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                              if (invoice.supplierName !=
                                                  null) ...[
                                                AppSpacing.gapVerticalXS,
                                                Text(
                                                  'Supplier: ${invoice.supplierName}',
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(alpha: 0.8),
                                                  ),
                                                ),
                                              ],
                                              AppSpacing.gapVerticalXS,
                                              Text(
                                                '${invoice.detailInvoices.length} item • ${invoice.paymentTypeText}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant
                                                      .withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (invoice.imageUrl != null &&
                                            invoice.imageUrl!.isNotEmpty) ...[
                                          AppSpacing.gapHorizontalMD,
                                          GestureDetector(
                                            onTap: () => _showInvoiceImage(
                                                context, invoice.imageUrl!),
                                            child: ClipRRect(
                                              borderRadius:
                                                  AppSpacing.borderRadiusSM,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Image.network(
                                                    invoice.imageUrl!,
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            Container(
                                                      width: 60,
                                                      height: 60,
                                                      color: colorScheme
                                                          .surfaceContainerHighest
                                                          .withValues(
                                                              alpha: 0.3),
                                                      child: const Icon(
                                                          Icons.broken_image,
                                                          size: 20),
                                                    ),
                                                  ),
                                                  Container(
                                                    width: 60,
                                                    height: 60,
                                                    color: Colors.black26,
                                                    child: const Icon(
                                                        Icons.zoom_in,
                                                        color: Colors.white,
                                                        size: 20),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _paymentStatusColor(
                                                    invoice.paymentStatus)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                AppSpacing.borderRadiusXL,
                                          ),
                                          child: Text(
                                            invoice.paymentStatusText,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: _paymentStatusColor(
                                                  invoice.paymentStatus),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        AppSpacing.gapHorizontalSM,
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _orderStatusColor(
                                                    invoice.orderStatus)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                AppSpacing.borderRadiusXL,
                                          ),
                                          child: Text(
                                            invoice.orderStatusText,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: _orderStatusColor(
                                                  invoice.orderStatus),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (invoice.isCash &&
                                            invoice.closingStores
                                                .isNotEmpty) ...[
                                          AppSpacing.gapHorizontalSM,
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.teal
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  AppSpacing.borderRadiusXL,
                                            ),
                                            child: Text(
                                              invoice.closingStores.length == 1
                                                  ? 'Closing #${invoice.closingStores.first.id}'
                                                  : 'Closing #${invoice.closingStores.first.id} +${invoice.closingStores.length - 1}',
                                              style: theme
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                color: Colors.teal,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
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
                  }),
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
