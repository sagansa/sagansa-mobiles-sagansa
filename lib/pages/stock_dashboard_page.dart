import 'package:flutter/material.dart';

import '../services/asset_service.dart';
import '../services/storage_stock_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/dashboard_scaffold.dart';
import 'asset_dashboard_page.dart';
import 'employee_consumption_list_page.dart';
import 'production_list_page.dart';
import 'storage_stock_list_page.dart';
import 'store_consumption_list_page.dart';
import 'transfer_stock_list_page.dart';

class StockDashboardPage extends StatefulWidget {
  const StockDashboardPage({super.key});

  @override
  State<StockDashboardPage> createState() => _StockDashboardPageState();
}

class _StockDashboardPageState extends State<StockDashboardPage> {
  bool _hasReportedToday = false;
  int _reportedStores = 0;
  int _totalStores = 0;
  final StorageStockService _storageStockService = StorageStockService();
  final AssetService _assetService = AssetService();
  int _assetDueTodayCount = 0;
  bool _isLoadingAsset = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadAssetSummary();
  }

  Future<void> _checkStatus() async {
    final status = await _storageStockService.checkTodayStatus();
    if (mounted) {
      setState(() {
        _reportedStores = status['reported_stores'] ?? 0;
        _totalStores = status['total_stores'] ?? 0;
        _hasReportedToday = _reportedStores > 0;
      });
    }
  }

  /// Ringkasan aset jatuh tempo hari ini untuk badge menu Manajemen Aset.
  /// Ditampilkan untuk semua user (backend memfilter ke aset yang
  /// ditugaskan/aksesibel ke user login).
  Future<void> _loadAssetSummary() async {
    if (!mounted) return;
    setState(() => _isLoadingAsset = true);
    try {
      final summary = await _assetService.getDashboardSummary();
      if (mounted) {
        setState(() {
          _assetDueTodayCount = (summary['due_today'] ?? 0) as int;
          _isLoadingAsset = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAsset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DashboardScaffold(
      currentIndex: 2,
      title: 'Manajemen Inventaris & Stok',
      subtitle: 'Monitor stok produk, kelola gudang, dan lakukan stock opname.',
      menuItems: [
        DashboardMenuItem(
          icon: Icons.inventory_outlined,
          title: 'Stok Gudang',
          subtitle: 'Input sisa stok bahan baku saat ini di gudang.',
          trailing: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: _hasReportedToday
                  ? AppColors.success.withValues(alpha: 0.1)
                  : colorScheme.error.withValues(alpha: 0.1),
              borderRadius: AppSpacing.borderRadiusMD,
            ),
            child: Text(
              '$_reportedStores/$_totalStores',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _hasReportedToday
                    ? AppColors.success
                    : colorScheme.error,
              ),
            ),
          ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const StorageStockListPage()),
            );
            _checkStatus();
          },
        ),
        DashboardMenuItem(
          icon: Icons.inventory_2_outlined,
          title: 'Manajemen Aset',
          subtitle: 'Pemeriksaan aset berkala & issue tracking.',
          trailing: _isLoadingAsset
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : (_assetDueTodayCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: AppSpacing.borderRadiusMD,
                      ),
                      child: Text(
                        '$_assetDueTodayCount Jatuh Tempo',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.borderRadiusMD,
                      ),
                      child: Text(
                        'Aman',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    )),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AssetDashboardPage()),
            );
            _loadAssetSummary();
          },
        ),
        DashboardMenuItem(
          icon: Icons.warehouse_outlined,
          title: 'Transfer Stok Gudang',
          subtitle: 'Ajukan atau verifikasi mutasi stok antar-outlet.',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const TransferStockListPage()),
            );
          },
        ),
        DashboardMenuItem(
          icon: Icons.factory_outlined,
          title: 'Produksi',
          subtitle:
              'Buat produksi dari resep, terapkan mutasi stok bahan & hasil.',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ProductionListPage()),
            );
          },
        ),
        DashboardMenuItem(
          icon: Icons.point_of_sale_outlined,
          title: 'Konsumsi Toko',
          subtitle: 'Catat konsumsi bahan baku untuk operasional toko.',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const StoreConsumptionListPage()),
            );
          },
        ),
        DashboardMenuItem(
          icon: Icons.lunch_dining_outlined,
          title: 'Sisa Stok Karyawan',
          subtitle: 'Catat sisa stok yang belum terjual / dipakai karyawan.',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const EmployeeConsumptionListPage()),
            );
          },
        ),
      ],
    );
  }
}
