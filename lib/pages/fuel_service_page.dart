import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/procurement_model.dart';
import '../providers/fuel_service_payment_provider.dart';
import '../services/fuel_service_service.dart';
import '../services/image_service.dart';
import '../services/procurement_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/fuel_service_payment_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/ios_segmented_control.dart';
import '../widgets/list_thumbnail.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/payment_receipt_card.dart';
import 'fuel_service_form_page.dart';
import 'payment_receipt_detail_page.dart';

class FuelServicePage extends StatefulWidget {
  const FuelServicePage({super.key});

  @override
  State<FuelServicePage> createState() => _FuelServicePageState();
}

class _FuelServicePageState extends State<FuelServicePage> {
  int _activeTab = 0;

  final FuelServiceService _service = FuelServiceService();
  final ScrollController _scrollController = ScrollController();
  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;
  List<Map<String, dynamic>> _services = [];
  bool _isAdmin = false;
  bool _paymentMode = false;

  int _statusFilter = 0;
  int _fuelServiceFilter = 0;
  int _paymentTypeFilter = 0;
  int? _selectedUserId;
  List<Map<String, dynamic>> _userList = [];

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
    _loadAdminRole();
    _fetch();
    _scrollController.addListener(_onScroll);
    _receiptScrollController.addListener(_onReceiptScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _receiptScrollController.removeListener(_onReceiptScroll);
    _receiptScrollController.dispose();
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

  void _onReceiptScroll() {
    if (_receiptScrollController.position.pixels >=
            _receiptScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMoreReceipts &&
        _hasMoreReceipts) {
      _loadMoreReceipts();
    }
  }

  int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  Future<void> _loadAdminRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final userData = json.decode(userString);
      final roles = List<String>.from(userData['roles'] ?? []);
      final isAdmin = roles.any((r) => [
            'admin',
            'super_admin',
            'supervisor',
            'owner',
            'panel_user'
          ].contains(r));
      if (!mounted) return;
      // The TabController length is fixed at 2; admin role only changes the
      // *content* of tab 2 (real receipts vs. locked placeholder), so there
      // is no controller to dispose/recreate.
      _isAdmin = isAdmin;
      setState(() {});
      if (_isAdmin) {
        _loadUserList();
        _fetchReceipts();
      }
    }
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _services = [];
      _hasMore = true;
    });

    try {
      final result = await _service.getFuelServicesPaged(
        allStores: _isAdmin,
        page: _page,
        createdById: _selectedUserId,
        status: _statusFilter == 0 ? null : _statusFilter.toString(),
        fuelService:
            _fuelServiceFilter == 0 ? null : _fuelServiceFilter.toString(),
        paymentTypeId:
            _paymentTypeFilter == 0 ? null : _paymentTypeFilter.toString(),
      );
      if (!mounted) return;
      setState(() {
        _services = result['data'] as List<Map<String, dynamic>>;
        _hasMore = result['has_more'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getFuelServicesPaged(
        allStores: _isAdmin,
        page: _page + 1,
        createdById: _selectedUserId,
        status: _statusFilter == 0 ? null : _statusFilter.toString(),
        fuelService:
            _fuelServiceFilter == 0 ? null : _fuelServiceFilter.toString(),
        paymentTypeId:
            _paymentTypeFilter == 0 ? null : _paymentTypeFilter.toString(),
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _services.addAll(result['data'] as List<Map<String, dynamic>>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadUserList() async {
    if (!_isAdmin) return;
    try {
      final users = await _service.getUsersForFuelServicePayment();
      if (!mounted) return;
      setState(() {
        _userList = users.cast<Map<String, dynamic>>().toList();
      });
    } catch (_) {}
  }

  int get _activeFilterCount {
    int count = 0;
    if (_fuelServiceFilter != 0) count++;
    if (_statusFilter != 0) count++;
    if (_paymentTypeFilter != 0) count++;
    if (_selectedUserId != null) count++;
    return count;
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter',
      fields: [
        if (_isAdmin)
          DropdownFilterField<int?>(
            label: 'Pengemudi',
            value: _selectedUserId,
            options: [
              (null, 'Semua User'),
              ..._userList.map((u) => (
                    _toInt(u['id']) ?? 0,
                    u['name']?.toString() ?? 'User #${u['id']}',
                  )),
            ],
          ),
        DropdownFilterField<int>(
          label: 'Tipe',
          value: _fuelServiceFilter,
          options: const [
            (0, 'Semua'),
            (1, 'Fuel'),
            (2, 'Service'),
          ],
        ),
        DropdownFilterField<int>(
          label: 'Status',
          value: _statusFilter,
          options: const [
            (0, 'Semua'),
            (1, 'Pending'),
            (2, 'Lunas'),
          ],
        ),
        DropdownFilterField<int>(
          label: 'Pembayaran',
          value:
              _paymentTypeFilter == 0 ? 0 : (_paymentTypeFilter == 2 ? 2 : 1),
          options: const [
            (0, 'Semua'),
            (2, 'Tunai'),
            (1, 'Transfer'),
          ],
        ),
      ],
      onApply: (values) {
        setState(() {
          _selectedUserId = _isAdmin ? values['Pengemudi'] as int? : null;
          _fuelServiceFilter = values['Tipe'] as int? ?? 0;
          _statusFilter = values['Status'] as int? ?? 0;
          final paymentType = values['Pembayaran'] as int? ?? 0;
          _paymentTypeFilter = paymentType == 0 ? 0 : paymentType;
        });
        _fetch();
      },
      onReset: () {
        setState(() {
          _selectedUserId = null;
          _fuelServiceFilter = 0;
          _statusFilter = 0;
          _paymentTypeFilter = 0;
        });
        _fetch();
      },
    );
  }

  void _openFuelServiceForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FuelServiceFormPage()),
    );
    if (result == true) {
      _fetch();
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
      // payment_for=1 → hanya receipt FuelService. Backend GET /payment-receipts
      // default-nya mengembalikan receipt InvoicePurchase (3), jadi tanpa param
      // ini tab Pembayaran akan selalu kosong (filter client-side sebelumnya
      // menutupi masalah ini tapi tidak menangani pagination dengan benar).
      final result = await _procurementService.getPaymentReceipts(
        page: _receiptPage,
        paymentFor: '1',
      );
      if (!mounted) return;
      setState(() {
        _receipts = result.items;
        _hasMoreReceipts = result.hasMore;
        _isLoadingReceipts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingReceipts = false);
    }
  }

  Future<void> _loadMoreReceipts() async {
    if (_isLoadingMoreReceipts || !_hasMoreReceipts) return;
    setState(() => _isLoadingMoreReceipts = true);

    try {
      final result = await _procurementService.getPaymentReceipts(
        page: _receiptPage + 1,
        paymentFor: '1',
      );
      if (!mounted) return;
      setState(() {
        _receiptPage++;
        _receipts.addAll(result.items);
        _hasMoreReceipts = result.hasMore;
        _isLoadingMoreReceipts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMoreReceipts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: Text(
            _paymentMode ? 'Pilih untuk Bayar Transfer' : 'Bensin & Servis'),
        actions: [
          BarButtonCluster(actions: [
            if (_activeTab == 0 && !_paymentMode) ...[
              BarButtonSpec(
                icon: Icons.tune,
                tooltip: 'Filter',
                badgeCount: _activeFilterCount,
                onTap: _openFilterSheet,
              ),
              BarButtonSpec(
                icon: Icons.payment,
                tooltip: 'Bayar Transfer',
                onTap: () {
                  setState(() => _paymentMode = !_paymentMode);
                  if (!_paymentMode) {
                    context
                        .read<FuelServicePaymentProvider>()
                        .clearSelection();
                  }
                },
              ),
            ],
            if (_paymentMode)
              BarButtonSpec(
                icon: Icons.close,
                tooltip: 'Batal',
                onTap: () {
                  setState(() => _paymentMode = false);
                  context.read<FuelServicePaymentProvider>().clearSelection();
                },
              ),
            BarButtonSpec(
              icon: Icons.add_rounded,
              iconSize: 22,
              tooltip: 'Tambah Bensin & Servis',
              onTap: _openFuelServiceForm,
            ),
          ]),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: IosSegmentedControl<int>(
            segments: const {
              0: 'Bensin & Servis',
              1: 'Pembayaran',
            },
            groupValue: _activeTab,
            onValueChanged: (v) => setState(() {
              _activeTab = v;
              if (_paymentMode) {
                _paymentMode = false;
                context.read<FuelServicePaymentProvider>().clearSelection();
              }
            }),
          ),
        ),
      ),
      body: IndexedStack(
        index: _activeTab,
        children: [
          _buildFuelServiceTab(),
          _isAdmin ? _buildPaymentReceiptTab() : _buildAdminOnlyWidget(),
        ],
      ),
      bottomNavigationBar: _paymentMode &&
              context.watch<FuelServicePaymentProvider>().selectedCount > 0
          ? _buildPaymentActionBar()
          : ModernBottomNav(
              currentIndex: 3,
              onTap: (index) {
                if (index != 3) {
                  Navigator.pop(context);
                }
              },
            ),
    );
  }

  Widget _buildFuelServiceTab() {
    return _buildBodyContent();
  }

  Widget _buildBodyContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final topPadding = AppBarInsets.top(context, bottom: 52) + 8;
    final bottomPadding = ModernBottomNav.clearance(context) + 16;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: _errorMessage != null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Padding(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: colorScheme.error),
                      AppSpacing.gapVerticalMD,
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge,
                      ),
                      AppSpacing.gapVerticalLG,
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : _services.isEmpty
              ? ListView(
                  padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_gas_station_outlined,
                            size: 64, color: colorScheme.outline),
                        AppSpacing.gapVerticalMD,
                        Text('Belum ada riwayat bensin atau servis.',
                            style: textTheme.bodyLarge),
                        AppSpacing.gapVerticalSM,
                        Text(
                          'Tarik ke bawah untuk menyegarkan',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _services.length + (_hasMore ? 1 : 0),
                  padding: AppSpacing.paddingMD.copyWith(
                      top: topPadding,
                      bottom: bottomPadding),
                  itemBuilder: (context, index) {
                    if (index == _services.length) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final fs = _services[index];
                    final type = fs['fuel_service'] == 1 ? 'Fuel' : 'Service';
                    final isFuel = fs['fuel_service'] == 1;
                    final amount =
                        double.tryParse(fs['amount'].toString()) ?? 0;
                    final date = fs['date'] ?? '';
                    final vehicleNo =
                        fs['vehicle']?['no_register'] ?? 'Kendaraan';
                    final km = fs['km'] ?? 0;
                    final creatorName = fs['created_by']?['name'] ?? 'Staff';
                    final statusStr =
                        fs['status'] == 2 ? 'Lunas / Terhubung' : 'Pending';
                    final isPaid = fs['status'] == 2;
                    final paymentTypeId = fs['payment_type_id'];
                    final canPayTransfer =
                        _paymentMode && !isPaid && paymentTypeId == 1;
                    final imageUrl =
                        ImageService.buildUrl(fs['image']?.toString());

                    return Card(
                      margin:
                          const EdgeInsets.only(bottom: AppSpacing.sectionGap),
                      child: Padding(
                        padding: AppSpacing.paddingMD,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (canPayTransfer)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Checkbox(
                                  value: context
                                      .read<FuelServicePaymentProvider>()
                                      .isSelected(fs['id'] as int),
                                  onChanged: (v) {
                                    final amount = double.tryParse(
                                            fs['amount'].toString()) ??
                                        0;
                                    final supplier = fs['supplier'];
                                    final error = context
                                        .read<FuelServicePaymentProvider>()
                                        .toggleSelection(
                                          fs['id'] as int,
                                          amount: amount.round(),
                                          // 1 = bensin (reimbursement ke
                                          // rekening pembuat, supplier
                                          // bebas), 2 = servis (wajib satu
                                          // supplier sama).
                                          fuelServiceType: isFuel ? 1 : 2,
                                          supplierId: supplier != null
                                              ? (supplier['id'] as num?)?.toInt()
                                              : null,
                                          supplierName: supplier?['name']?.toString(),
                                          bankName: supplier?['bank']?['name']?.toString(),
                                          bankAccountNo: supplier?['bank_account_no']?.toString(),
                                          bankAccountName: supplier?['bank_account_name']?.toString(),
                                          qris: supplier?['qris']?.toString(),
                                        );
                                    if (error != null && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(error)),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ListThumbnail(
                              imageUrl: imageUrl,
                              placeholderIcon: Icons.local_gas_station_outlined,
                              onTap: imageUrl != null
                                  ? () => _showImageFullscreen(imageUrl)
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: AppSpacing.xs),
                                        decoration: BoxDecoration(
                                          color: (isFuel
                                                  ? AppColors.success
                                                  : AppColors.warning)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              AppSpacing.borderRadiusSM,
                                        ),
                                        child: Text(
                                          type,
                                          style:
                                              textTheme.labelMedium?.copyWith(
                                            color: isFuel
                                                ? AppColors.success
                                                : AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        currencyFormatter.format(amount),
                                        style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  AppSpacing.gapVerticalSM,
                                  Text(
                                    '$vehicleNo (KM: $km)',
                                    style: textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  AppSpacing.gapVerticalXS,
                                  Text(
                                    'Tanggal: $date | Oleh: $creatorName'
                                    '${fs['supplier']?['name'] != null ? ' | Supplier: ${fs['supplier']['name']}' : ''}',
                                    style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant),
                                  ),
                                  AppSpacing.gapVerticalSM,
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        statusStr,
                                        style: textTheme.labelMedium?.copyWith(
                                          color: isPaid
                                              ? AppColors.success
                                              : colorScheme.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (imageUrl != null)
                                        IconButton(
                                          icon:
                                              const Icon(Icons.share, size: 18),
                                          onPressed: () =>
                                              _shareImage(imageUrl, fs['id']),
                                          tooltip: 'Bagikan',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                  if (fs['notes'] != null) ...[
                                    AppSpacing.gapVerticalXS,
                                    (() {
                                      final stripped = _stripHtmlTags(
                                          fs['notes'].toString());
                                      if (stripped.isNotEmpty) {
                                        return Text(
                                          stripped,
                                          style: textTheme.bodySmall?.copyWith(
                                              fontStyle: FontStyle.italic),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    })(),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildAdminOnlyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline,
              size: 64, color: Theme.of(context).colorScheme.outline),
          AppSpacing.gapVerticalMD,
          const Text('Hanya dapat diakses oleh admin.'),
        ],
      ),
    );
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
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  AppSpacing.gapVerticalMD,
                  const Text('Belum ada pembayaran bensin & servis.'),
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
                  builder: (_) =>
                      PaymentReceiptDetailPage(receiptId: receipt.id),
                ),
              ).then((_) => _fetchReceipts());
            },
          );
        },
      ),
    );
  }

  void _showImageFullscreen(String url) {
    final colorScheme = Theme.of(context).colorScheme;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: GlassAppBar(
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.87),
            foregroundColor: colorScheme.surface,
            title: Text('Bukti Bensin & Servis',
                style: TextStyle(color: colorScheme.surface)),
          ),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image,
                    color: colorScheme.surface.withValues(alpha: 0.54),
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareImage(String url, dynamic id) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('download failed');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fuel_service_$id.jpg');
      await file.writeAsBytes(response.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Bukti Bensin & Servis'),
      );
    } catch (_) {
      if (mounted) {
        await SharePlus.instance.share(ShareParams(text: url));
      }
    }
  }

  Widget _buildPaymentActionBar() {
    final provider = context.read<FuelServicePaymentProvider>();
    return GlassContainer.bottomBar(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider.selectedCount} item terpilih',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  FormatUtils.formatCurrency(provider.totalAmount),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
            ElevatedButton.icon(
              onPressed: () async {
                final success = await FuelServicePaymentBottomSheet.show(context);
                if (success == true) {
                  setState(() => _paymentMode = false);
                  _fetch();
                  // Refresh tab Pembayaran agar receipt baru langsung muncul.
                  if (_isAdmin) _fetchReceipts();
                }
              },
            icon: const Icon(Icons.payment),
            label: const Text('Bayar'),
            style: AppButtonStyle.elevated(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

String _stripHtmlTags(String htmlText) {
  final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
  return htmlText.replaceAll(exp, '').trim();
}
