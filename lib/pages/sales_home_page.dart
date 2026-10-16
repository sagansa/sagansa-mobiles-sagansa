import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/ios_segmented_control.dart';
import 'delivery_address_list_page.dart';
import 'sales_order_employee_list_page.dart';

/// Home khusus user sales-only.
///
/// Tanpa bottom navbar, tanpa drawer, tanpa section presence/clock-in.
/// Tab "Penjualan" ([SalesOrderEmployeeListPage]) untuk semua user sales,
/// termasuk `sales + former-employee` (sales eksternal), bersama tab
/// "Konsumen" ([DeliveryAddressListPage]).
class SalesHomePage extends StatefulWidget {
  const SalesHomePage({super.key});

  @override
  State<SalesHomePage> createState() => _SalesHomePageState();
}

class _SalesHomePageState extends State<SalesHomePage> {
  int _index = 0;
  bool _canSell = false;
  bool _loaded = false;

  /// Kunci ke tab Penjualan untuk memicu create dari AppBar induk —
  /// list di-embed tanpa AppBar sendiri (`showAppBar: false`).
  final GlobalKey<SalesOrderEmployeeListPageState> _employeeKey =
      GlobalKey<SalesOrderEmployeeListPageState>();

  /// Kunci ke tab Konsumen — tombol "+" AppBar induk juga harus bisa
  /// membuat konsumen saat tab Konsumen aktif.
  final GlobalKey<DeliveryAddressListPageState> _customerKey =
      GlobalKey<DeliveryAddressListPageState>();

  @override
  void initState() {
    super.initState();
    _loadCanSell();
    context.read<AuthProvider>().loadUserInfo();
  }

  Future<void> _loadCanSell() async {
    final canSell = await AuthService.canSell();
    if (!mounted) return;
    setState(() {
      _canSell = canSell;
      _loaded = true;
      _index = 0;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.logout();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userName = context.select<AuthProvider, String>((a) => a.userName);

    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName.isEmpty ? 'Sales' : userName,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              'Mode Penjualan',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          BarButtonCluster(
            actions: [
              // Tombol create selalu ada: tab Penjualan aktif → order
              // employee; tab Konsumen aktif → konsumen. List-list di-embed
              // tanpa AppBar sendiri (`showAppBar: false`), jadi create
              // harus dipicu dari sini — pola SalesPage.
              if (_canSell && _index == 0)
                BarButtonSpec(
                  icon: Icons.add_rounded,
                  iconSize: 22,
                  tooltip: 'Tambah Order Employee',
                  onTap: () => _employeeKey.currentState?.openCreate(),
                )
              else
                BarButtonSpec(
                  icon: Icons.add_rounded,
                  iconSize: 22,
                  tooltip: 'Tambah Konsumen',
                  onTap: () => _customerKey.currentState?.openCreate(),
                ),
              BarButtonSpec(
                icon: Icons.logout,
                tooltip: 'Logout',
                onTap: _logout,
              ),
            ],
          ),
        ],
        bottom: _canSell
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: IosSegmentedControl<int>(
                  segments: const {0: 'Penjualan', 1: 'Konsumen'},
                  groupValue: _index,
                  onValueChanged: (v) => setState(() => _index = v),
                ),
              )
            : null,
      ),
      body: IndexedStack(
        index: _index,
        children: _canSell
            ? [
                SalesOrderEmployeeListPage(key: _employeeKey, showAppBar: false),
                DeliveryAddressListPage(key: _customerKey, showAppBar: false),
              ]
            : [
                DeliveryAddressListPage(key: _customerKey, showAppBar: false),
              ],
      ),
    );
  }
}
