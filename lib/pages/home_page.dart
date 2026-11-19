import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/home_dashboard_provider.dart';
import '../providers/notification_provider.dart';
import '../services/version_service.dart';
import '../theme/app_spacing.dart';
import '../utils/stale_refresh_policy.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/home/cards/home_anomaly_card.dart';
import '../widgets/home/cards/home_asset_card.dart';
import '../widgets/home/cards/home_asset_due_card.dart';
import '../widgets/home/cards/home_closing_store_card.dart';
import '../widgets/home/cards/home_delivery_card.dart';
import '../widgets/home/cards/home_invoice_unpaid_card.dart';
import '../widgets/home/cards/home_leave_card.dart';
import '../widgets/home/cards/home_loan_card.dart';
import '../widgets/home/cards/home_pending_approvals_card.dart';
import '../widgets/home/cards/home_presence_summary_card.dart';
import '../widgets/home/cards/home_salary_slip_card.dart';
import '../widgets/home/cards/home_shopping_card.dart';
import '../widgets/home/cards/home_specific_gravity_card.dart';
import '../widgets/home/cards/home_stock_report_card.dart';
import '../widgets/home/cards/home_stock_warehouse_card.dart';
import '../widgets/home/cards/home_yesterday_omzet_card.dart';
import '../widgets/home/home_drawer.dart';
import '../widgets/home/home_skeleton_loader.dart';
import '../widgets/home/sections/home_greeting_header.dart';
import '../widgets/home/sections/home_presence_section.dart';
import '../widgets/home/sections/home_staff_checklist_section.dart';
import '../widgets/home/sections/home_storage_stocks_section.dart';
import '../widgets/home/sections/today_presences_sheet.dart';
import '../widgets/ios_bar_button.dart';
import '../widgets/modern_bottom_nav.dart';
import 'hrd_dashboard_page.dart';
import 'notification_list_page.dart';
import 'presence_page.dart';
import 'stock_dashboard_page.dart';
import 'transaction_dashboard_page.dart';


class HomePage extends StatefulWidget {
  final bool? initialIsAdmin;
  const HomePage({super.key, this.initialIsAdmin});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool isLoading = false;
  final int _selectedIndex = 0;

  /// Waktu siklus fetch terakhir selesai (diisi _initData). Dipakai untuk
  /// memutuskan refresh saat app kembali ke foreground — resume tidak
  /// me-mount ulang widget, jadi tanpa ini tampilan memakai data lama.
  DateTime? _lastFullFetch;

  /// App-switch singkat (di bawah ambang) tidak memicu fetch ulang.
  static const _staleRefreshPolicy = StaleRefreshPolicy();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initData();
    _refreshUnreadCount();

    // Check for app updates. Data loading is started after authentication in
    // _initData; starting it here as well caused duplicate unauthenticated
    // requests during app startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionService().checkForUpdate(context);
    });
  }

  /// Ambil jumlah notifikasi belum dibaca untuk badge bell. Nilai di-render
  /// dari NotificationProvider (global), cukup refresh datanya di sini.
  Future<void> _refreshUnreadCount() async {
    await NotificationProvider.instance.refreshUnreadCount();
  }

  /// Buka halaman notifikasi, lalu refresh badge saat kembali.
  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationListPage()),
    );
    if (mounted) _refreshUnreadCount();
  }

  Future<void> _initData() async {
    // Ambil provider sekali di awal sebelum await apa pun untuk menghindari
    // penggunaan BuildContext secara asynchronous.
    final homeProvider = context.read<HomeDashboardProvider>();
    final authProvider = context.read<AuthProvider>();
    setState(() {
      isLoading = true;
    });

    try {
      // Load user info (userName/companyName) + roles via AuthProvider.
      await authProvider.loadUserInfo();
      if (!mounted) return;
      final isStorageStaffRole = authProvider.isStorageStaff;
      final hasAdminRole = widget.initialIsAdmin ?? authProvider.isAdmin;

      // Load dashboard data secara paralel sesuai role untuk meminimalkan waktu loading
      await Future.wait([
        homeProvider.loadAll(),
        homeProvider.loadPresence(),
        homeProvider.loadLeaveSalary(),
        if (!hasAdminRole) homeProvider.loadStaffChecklist(),
        if (isStorageStaffRole) homeProvider.loadOrders(),
        if (hasAdminRole || isStorageStaffRole) ...[
          homeProvider.loadAdminStock(),
          homeProvider.loadAdminPresence(),
        ],
      ]);
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('User data not found')) {
          _logout();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    } finally {
      _lastFullFetch = DateTime.now();
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Resume dari background: HomePage tidak di-mount ulang sehingga tanpa
  /// ini frame lama tetap tampil tanpa panggilan API baru. Refresh hanya
  /// bila data terakhir sudah melewati ambang staleness.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    if (!_staleRefreshPolicy.shouldRefresh(_lastFullFetch, DateTime.now())) {
      return;
    }
    _initData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await _initData();
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.logout();
    if (!mounted) return;
    if (success) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    } else {
      showAppSnackBar(
        context,
        authProvider.errorMessage.isNotEmpty
            ? authProvider.errorMessage
            : 'Gagal melakukan logout',
        background: Theme.of(context).colorScheme.error,
      );
    }
  }


  Future<void> _navigateToPresencePage() async {
    final homeProvider = context.read<HomeDashboardProvider>();
    // Langsung navigasi ke PresencePage
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PresencePage(
          isCheckIn: homeProvider.presence.todayPresence == null,
        ),
      ),
    );

    // Refresh data jika ada perubahan
    if (result == true) {
      await homeProvider.loadPresence();
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        // Sudah di home, tidak perlu navigasi
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HRDDashboardPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StockDashboardPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TransactionDashboardPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read user info & roles from AuthProvider (single source of truth).
    final userName =
        context.select<AuthProvider, String>((a) => a.userName);
    final companyName =
        context.select<AuthProvider, String>((a) => a.companyName);
    final isAdmin = widget.initialIsAdmin ??
        context.select<AuthProvider, bool>((a) => a.isAdmin);
    final isStorageStaff =
        context.select<AuthProvider, bool>((a) => a.isStorageStaff);
    final hasLoanData = context.select<HomeDashboardProvider, bool>(
        (p) => p.leaveSalary.hasLoanData);
    final isUserDataLoaded = context.select<HomeDashboardProvider, bool>(
        (p) => p.presence.isUserDataLoaded);
    // Jumlah notifikasi belum dibaca dari NotificationProvider (live saat
    // push masuk; badge di-refresh dari service di atas).
    final unreadCount =
        context.select<NotificationProvider, int>((p) => p.unreadCount);
    final topPadding = MediaQuery.of(context).padding.top + 44.0;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        centerTitle: false,
        showBottomBorder: false,
        toolbarHeight: 44.0,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Center(
              child: IosBarButton(
                onTap: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Menu Navigasi',
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: SvgPicture.asset(
                    'assets/images/logo.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: null,
        actions: [
          BarButtonCluster(
            actions: [
              BarButtonSpec(
                icon: Icons.notifications_outlined,
                badgeCount: unreadCount,
                tooltip: 'Notifikasi',
                onTap: _openNotifications,
              ),
            ],
          ),
        ],
      ),
      drawer: HomeDrawer(
        userName: userName,
        companyName: companyName,
        isAdmin: isAdmin,
        onLogout: _logout,
      ),
      body: RefreshIndicator(
        key: const Key('homeRefresh'),
        edgeOffset: topPadding,
        onRefresh: _onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                topPadding + 6,
                AppSpacing.md,
                ModernBottomNav.clearance(context),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      topPadding -
                      (ModernBottomNav.height + AppSpacing.sm),
                ),
                child: !isUserDataLoaded
                    ? const HomeSkeletonLoader()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HomeGreetingHeader(
                            userName: userName,
                            companyName: companyName,
                            isAdmin: isAdmin,
                            isStorageStaff: isStorageStaff,
                          ),
                          AppSpacing.gapVerticalSM,
                          if (isAdmin)
                            _buildAdminDashboard()
                          else ...[
                            HomePresenceSection(
                              onNavigateToPresence: _navigateToPresencePage,
                            ),
                            AppSpacing.gapVerticalSM,
                            const HomeStaffChecklistSection(),
                            AppSpacing.gapVerticalSM,
                            _buildDashboardGrid(
                              isStorageStaff: isStorageStaff,
                              hasLoanData: hasLoanData,
                            ),
                          ],
                        ],
                      ),
              ),
            );
          },
        ),
      ),

      bottomNavigationBar: ModernBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        presences: () {
          final p = context.read<HomeDashboardProvider>().presence;
          return [...p.previousPresences, if (p.todayPresence != null) p.todayPresence!];
        }(),
      ),
    );
  }

  Widget _buildDashboardGrid({
    required bool isStorageStaff,
    required bool hasLoanData,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isStorageStaff) ...[
          _buildMenuSectionHeader(
            icon: Icons.warehouse_outlined,
            title: 'Gudang & Logistik',
          ),
          AppSpacing.gapVerticalSM,
          GridView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              childAspectRatio: 1.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            children: const [
              HomeStockWarehouseCard(),
              HomeDeliveryCard(),
              HomeSpecificGravityCard(),
            ],
          ),
          AppSpacing.gapVerticalMD,
        ],
        _buildMenuSectionHeader(
          icon: Icons.storefront_outlined,
          title: 'Operasional Toko',
        ),
        AppSpacing.gapVerticalSM,
        GridView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 1.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          children: const [
            HomeClosingStoreCard(),
            HomeAssetCard(),
            HomeShoppingCard(),
          ],
        ),
        AppSpacing.gapVerticalMD,
        _buildMenuSectionHeader(
          icon: Icons.badge_outlined,
          title: 'Personalia & Finansial',
        ),
        AppSpacing.gapVerticalSM,
        GridView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 1.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          children: [
            const HomeSalarySlipCard(),
            const HomeLeaveCard(),
            if (hasLoanData) const HomeLoanCard(),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomePendingApprovalsCard(),
        _buildMenuSectionHeader(
          icon: Icons.dashboard_outlined,
          title: 'Ringkasan Dashboard Admin',
        ),
        AppSpacing.gapVerticalSM,
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.0,
          children: [
            // 1. Presensi (provider-driven)
            HomePresenceSummaryCard(
              onTap: () => showTodayPresencesSheet(context),
            ),
            // 2. Omzet Kemarin (provider-driven)
            const HomeYesterdayOmzetCard(),
            // 3. Selisih Stok (provider-driven)
            const HomeAnomalyCard(),
            // 4. Invoice Unpaid (provider-driven)
            const HomeInvoiceUnpaidCard(),
            // 5. Laporan Stok (provider-driven)
            const HomeStockReportCard(),
            // 6. Aset Jatuh Tempo (provider-driven)
            const HomeAssetDueCard(),
          ],
        ),
        AppSpacing.gapVerticalMD,
        const HomeStorageStocksSection(),
      ],
    );
  }

  Widget _buildMenuSectionHeader({
    required IconData icon,
    required String title,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        AppSpacing.gapHorizontalXS,
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
