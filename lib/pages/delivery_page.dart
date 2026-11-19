import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums/delivery_status.dart';
import '../models/enums/order_mode.dart';
import '../providers/delivery_provider.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/bar_search_field.dart';
import '../widgets/delivery/barcode_scanner_page.dart';
import '../widgets/delivery/direct_order_detail_view.dart';
import '../widgets/delivery/online_order_detail_view.dart';
import '../widgets/delivery/order_list_view.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/ios_bar_button.dart';
import '../widgets/modern_bottom_nav.dart';
import 'create_sales_order_online_page.dart';

class DeliveryPage extends StatelessWidget {
  final OrderMode orderMode;

  const DeliveryPage({super.key, this.orderMode = OrderMode.online});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeliveryProvider(orderMode: orderMode)..initialize(),
      child: _DeliveryScaffold(orderMode: orderMode),
    );
  }
}

class _DeliveryScaffold extends StatefulWidget {
  final OrderMode orderMode;

  const _DeliveryScaffold({required this.orderMode});

  @override
  State<_DeliveryScaffold> createState() => _DeliveryScaffoldState();
}

class _DeliveryScaffoldState extends State<_DeliveryScaffold> {
  bool _searchExpanded = false;

  OrderMode get orderMode => widget.orderMode;

  Future<void> _submitSearch(
    BuildContext context,
    DeliveryProvider provider,
  ) async {
    if (provider.listState.isLoadingSearch) return;
    try {
      await provider.searchOrder();
      if (context.mounted) {
        // Hasil pencarian membuka detail inline → tutup mode pencarian.
        setState(() => _searchExpanded = false);
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          background: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  void _collapseSearch(DeliveryProvider provider) {
    provider.clearSearch();
    setState(() => _searchExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<DeliveryProvider>();
    final formState = provider.formState;
    final listState = provider.listState;

    // Mode pencarian hanya relevan di daftar online; hasil pencarian yang
    // membuka detail inline otomatis menutup mode pencarian.
    final searchExpanded = _searchExpanded && !formState.hasSelection;

    final showSearchAction = orderMode.isOnline && !formState.hasSelection;
    final showAddAction = listState.isAdmin &&
        orderMode.isOnline &&
        !formState.hasSelection;

    final trailingSpecs = <BarButtonSpec>[
      if (showSearchAction)
        BarButtonSpec(
          icon: Icons.search,
          tooltip: 'Cari Nomor Resi',
          onTap: () => setState(() => _searchExpanded = true),
        ),
      if (showAddAction)
        BarButtonSpec(
          icon: Icons.add_rounded,
          iconSize: 22,
          tooltip: 'Tambah Pesanan',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateSalesOrderOnlinePage(),
              ),
            ).then((_) => provider.loadInitialOrders());
          },
        ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: searchExpanded
            ? BarSearchField(
                controller: provider.receiptController,
                hintText: 'Cari Nomor Resi...',
                isLoading: listState.isLoadingSearch,
                onSubmitted: (_) => _submitSearch(context, provider),
                onClear: provider.clearSearch,
                onScan: () => _scanBarcode(context, provider),
              )
            : Text(
                formState.hasSelection
                    ? orderMode.detailTitle
                    : orderMode.title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
        centerTitle: !searchExpanded,
        leading: searchExpanded
            ? _paddedBackButton(onTap: () => _collapseSearch(provider))
            : formState.hasSelection
                ? _paddedBackButton(
                    onTap: () {
                      provider.clearSelection();
                      setState(() => _searchExpanded = false);
                    },
                  )
                : null,
        actions: searchExpanded
            ? const [SizedBox(width: 14)]
            : trailingSpecs.isEmpty
                ? null
                : [BarButtonCluster(actions: trailingSpecs)],
      ),
      body: SafeArea(
        child: formState.hasSelection
            ? _buildDetailView(context, provider, formState, listState)
            : OrderListView(
          padding: EdgeInsets.only(top: AppBarInsets.top(context)),orderMode: orderMode),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index != 3) Navigator.pop(context);
        },
      ),
    );
  }

  /// Tombol kembali lingkaran glass dengan padding kiri 14 — seragam
  /// dengan tombol bar lainnya (lihat DashboardScaffold).
  static Widget _paddedBackButton({required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Center(child: IosBarButton.back(onTap: onTap)),
    );
  }

  Widget _buildDetailView(
    BuildContext context,
    DeliveryProvider provider,
    DeliveryFormState formState,
    DeliveryListState listState,
  ) {
    final order = formState.selectedOrder!;
    final status = DeliveryStatus.fromCode(order['delivery_status'] ?? 1);

    if (orderMode.isOnline) {
      return OnlineOrderDetailView(
        order: order,
        orderMode: orderMode,
        status: status,
      );
    }

    return DirectOrderDetailView(
      order: order,
      orderMode: orderMode,
      status: status,
    );
  }

  static Future<void> _scanBarcode(
    BuildContext context,
    DeliveryProvider provider,
  ) async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );
    if (scannedCode != null && scannedCode.isNotEmpty) {
      provider.receiptController.text = scannedCode;
      provider.searchOrder().catchError((e) {
        if (context.mounted) {
          showAppSnackBar(
            context,
            e.toString().replaceAll('Exception: ', ''),
            background: Theme.of(context).colorScheme.error,
          );
        }
      });
    }
  }
}
