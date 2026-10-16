import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../models/enums/order_mode.dart';
import '../models/sales_order_employee_model.dart';
import '../providers/delivery_provider.dart';
import '../providers/printer_provider.dart';
import '../services/sales_order_employee_service.dart';
import '../utils/error_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/bar_search_field.dart';
import '../widgets/delivery/barcode_scanner_page.dart';
import '../widgets/delivery/order_detail_page.dart';
import '../widgets/delivery/order_list_view.dart';
import '../widgets/employee_order_list_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/ios_bar_button.dart';
import '../widgets/ios_segmented_control.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/paged_body_view.dart';
import 'create_sales_order_online_page.dart';
import 'sales_order_employee_detail_page.dart';
import 'sales_order_employee_form_page.dart';

/// Halaman Penjualan terpadu — tab Online, Employee, Direct.
///
/// Menggantikan dialog pilih tipe penjualan di TransactionDashboardPage
/// — user cukup tap tab untuk ganti tipe, tanpa bolak-balik ke menu utama.
/// Tab Employee hanya untuk sales (termasuk `sales + former-employee`)
/// dan admin; role lain (mis. storage-staff) hanya melihat Online/Direct.
class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  int _index = 0;
  bool _loaded = false;
  bool _showEmployeeTab = false;
  bool _isAdmin = false;
  bool _canSell = false;
  bool _searchExpanded = false;

  late DeliveryProvider _onlineProvider;

  final GlobalKey<_OnlineTabContentState> _onlineKey = GlobalKey();
  final GlobalKey<_EmployeeTabContentState> _employeeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Provider online diangkat ke level halaman agar AppBar (pencarian)
    // dan tab memakai instance yang sama.
    _onlineProvider =
        DeliveryProvider(orderMode: OrderMode.online)..initialize();
    _loadTabs();
  }

  Future<void> _loadTabs() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    var roles = const <String>[];
    if (userString != null) {
      try {
        roles = List<String>.from(json.decode(userString)['roles'] ?? []);
      } catch (_) {}
    }
    final canSell = roles.contains('sales');
    final isAdmin =
        roles.contains('admin') ||
        roles.contains('super_admin') ||
        roles.contains('supervisor');
    if (!mounted) return;
    setState(() {
      _canSell = canSell;
      _isAdmin = isAdmin;
      _showEmployeeTab = canSell || isAdmin;
      _loaded = true;
      _index = 0;
    });
  }

  /// Id tab aktif: 'online' | 'employee' | 'direct'.
  String get _activeTab {
    final tabs = ['online', if (_showEmployeeTab) 'employee', 'direct'];
    return tabs[_index.clamp(0, tabs.length - 1)];
  }

  /// Posisi [IndexedStack] untuk key segmen [_index].
  int get _stackPosition {
    if (_index == 2) return _showEmployeeTab ? 2 : 1;
    if (_index == 1 && _showEmployeeTab) return 1;
    return 0;
  }

  @override
  void dispose() {
    _onlineProvider.dispose();
    super.dispose();
  }

  List<Widget> _buildBarActions() {
    if (!_loaded) return const [];

    // Mode pencarian expanded → beri inset kanan agar field tidak mepet edge.
    if (_searchExpanded && _activeTab == 'online') {
      return const [SizedBox(width: 14)];
    }

    // Tab Online: search selalu aktif untuk semua user (termasuk storage-staff).
    // Tombol create pesanan hanya untuk admin.
    if (_activeTab == 'online') {
      final specs = <BarButtonSpec>[
        BarButtonSpec(
          icon: Icons.search,
          tooltip: 'Cari Nomor Resi',
          onTap: () => setState(() => _searchExpanded = true),
        ),
        if (_isAdmin)
          BarButtonSpec(
            icon: Icons.add_rounded,
            iconSize: 22,
            tooltip: 'Tambah Order Online',
            onTap: () => _onlineKey.currentState?.openCreateOrder(),
          ),
      ];
      return [BarButtonCluster(actions: specs)];
    }
    // Tab Employee (jika tab aktif & user role sales)
    if (_activeTab == 'employee') {
      if (!_canSell) return const [];
      return [
        BarButtonCluster(
          actions: [
            BarButtonSpec(
              icon: Icons.add_rounded,
              iconSize: 22,
              tooltip: 'Tambah Order Employee',
              onTap: () => _employeeKey.currentState?.openCreate(),
            ),
          ],
        ),
      ];
    }
    return const [];
  }

  /// Cari resi dari AppBar. Sukses → tutup pencarian & buka detail order.
  Future<void> _submitOnlineSearch() async {
    if (_onlineProvider.listState.isLoadingSearch) return;
    try {
      await _onlineProvider.searchOrder();
      if (!mounted) return;
      final order = _onlineProvider.formState.selectedOrder;
      setState(() => _searchExpanded = false);
      if (order != null) _onlineKey.currentState?.openDetail(order);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          background: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _scanOnlineBarcode() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (scannedCode != null && scannedCode.isNotEmpty) {
      _onlineProvider.receiptController.text = scannedCode;
      await _submitOnlineSearch();
    }
  }

  void _collapseOnlineSearch() {
    _onlineProvider.clearSearch();
    setState(() => _searchExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final segments = {
      0: 'Online',
      if (_showEmployeeTab) 1: 'Employee',
      2: 'Direct',
    };

    final searchExpanded = _searchExpanded && _activeTab == 'online';

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: searchExpanded
            ? AnimatedBuilder(
                animation: _onlineProvider,
                builder: (context, _) => BarSearchField(
                  controller: _onlineProvider.receiptController,
                  hintText: 'Cari Nomor Resi...',
                  isLoading:
                      _onlineProvider.listState.isLoadingSearch,
                  onSubmitted: (_) => _submitOnlineSearch(),
                  onClear: _onlineProvider.clearSearch,
                  onScan: _scanOnlineBarcode,
                ),
              )
            : const Text('Penjualan'),
        centerTitle: !searchExpanded,
        leading: searchExpanded
            ? Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Center(
                  child: IosBarButton.back(onTap: _collapseOnlineSearch),
                ),
              )
            : null,
        actions: _buildBarActions(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: IosSegmentedControl<int>(
            segments: segments,
            groupValue: segments.containsKey(_index) ? _index : 0,
            onValueChanged: (v) => setState(() {
              _index = v;
              // Pindah tab selalu menutup mode pencarian online.
              _searchExpanded = false;
            }),
          ),
        ),
      ),
      body: IndexedStack(
        index: _stackPosition,
        children: [
          _OnlineTabContent(key: _onlineKey, provider: _onlineProvider),
          if (_showEmployeeTab) _EmployeeTabContent(key: _employeeKey),
          const _DirectTabContent(),
        ],
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index != 3) Navigator.pop(context);
        },
      ),
    );
  }
}

/// Tab Online — delivery list scoped to online orders.
/// Provider dimiliki [SalesPage] agar AppBar (pencarian) memakai instance
/// yang sama dengan daftar.
class _OnlineTabContent extends StatefulWidget {
  final DeliveryProvider provider;

  const _OnlineTabContent({super.key, required this.provider});

  @override
  State<_OnlineTabContent> createState() => _OnlineTabContentState();
}

class _OnlineTabContentState extends State<_OnlineTabContent> {
  DeliveryProvider get _provider => widget.provider;

  void openCreateOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateSalesOrderOnlinePage(),
      ),
    ).then((_) => _provider.loadInitialOrders());
  }

  /// Buka halaman detail baru untuk sebuah order online.
  /// Setelah kembali (pop), refresh list agar status terbaru terlihat.
  void openDetail(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(
          order: order,
          orderMode: OrderMode.online,
          provider: _provider,
        ),
      ),
    ).then((_) {
      if (mounted) _provider.loadInitialOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = AppBarInsets.top(context);
    final bottomPadding = ModernBottomNav.clearance(context) + 16;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: ChangeNotifierProvider(
        create: (_) => PrinterProvider(),
        child: OrderListView(
          orderMode: OrderMode.online,
          onOpenDetail: openDetail,
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: bottomPadding,
          ),
        ),
      ),
    );
  }
}

/// Tab Direct — delivery list scoped to direct orders.
class _DirectTabContent extends StatefulWidget {
  const _DirectTabContent();

  @override
  State<_DirectTabContent> createState() => _DirectTabContentState();
}

class _DirectTabContentState extends State<_DirectTabContent> {
  late DeliveryProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = DeliveryProvider(orderMode: OrderMode.direct)..initialize();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  /// Buka halaman detail baru untuk sebuah order direct.
  /// Setelah kembali (pop), refresh list agar status terbaru terlihat.
  void _openDetail(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(
          order: order,
          orderMode: OrderMode.direct,
          provider: _provider,
        ),
      ),
    ).then((_) {
      if (mounted) _provider.loadInitialOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = AppBarInsets.top(context);
    final bottomPadding = ModernBottomNav.clearance(context) + 16;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: ChangeNotifierProvider(
        create: (_) => PrinterProvider(),
        child: OrderListView(
          orderMode: OrderMode.direct,
          onOpenDetail: _openDetail,
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: bottomPadding,
          ),
        ),
      ),
    );
  }
}

/// Tab Employee — daftar penjualan employee (tanpa Scaffold sendiri).
class _EmployeeTabContent extends StatefulWidget {
  const _EmployeeTabContent({super.key});

  @override
  State<_EmployeeTabContent> createState() => _EmployeeTabContentState();
}

class _EmployeeTabContentState extends State<_EmployeeTabContent> {
  final SalesOrderEmployeeService _service = SalesOrderEmployeeService();
  final ScrollController _scrollController = ScrollController();

  List<SalesOrderEmployeeModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasNext = false;
  int _page = 1;
  String? _error;

  bool _isSales = false;

  int? _selectedSalesId;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final roles = List<String>.from(json.decode(userString)['roles'] ?? []);
      if (mounted) {
        setState(() {
          _isSales = roles.contains('sales');
        });
      }
    }
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final (list, hasNext) = await _service.getList(
        salesId: _selectedSalesId,
        page: _page,
      );
      if (!mounted) return;

      setState(() {
        _items = reset ? list : [..._items, ...list];
        _hasNext = hasNext;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorUtils.sanitize(e);
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasNext || _isLoadingMore) return;
    _page += 1;
    await _load(reset: false);
  }

  void openCreate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SalesOrderEmployeeFormPage()),
    );
    if (result == true) _load();
  }

  void _openDetail(SalesOrderEmployeeModel order) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SalesOrderEmployeeDetailPage(
          orderId: order.id,
          canEdit: _isSales,
        ),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = AppBarInsets.top(context);
    final bottomPadding = ModernBottomNav.clearance(context) + 16;

    return PagedBodyView<SalesOrderEmployeeModel>(
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: bottomPadding,
      ),
      isLoading: _isLoading,
      error: _error,
      items: _items,
      hasMore: _hasNext,
      onRefresh: () => _load(),
      onLoadMore: _loadMore,
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'Belum ada penjualan employee.',
      emptySubtitle: _isSales ? 'Tap + untuk membuat pesanan baru.' : null,
      itemBuilder: (context, index) {
        final o = _items[index];
        return EmployeeOrderListCard(
          order: o,
          onTap: () => _openDetail(o),
        );
      },
    );
  }
}
