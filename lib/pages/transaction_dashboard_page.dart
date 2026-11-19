import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_spacing.dart';
import '../widgets/dashboard_scaffold.dart';
import 'admin_last_order_user_list_page.dart';
import 'closing_store_page.dart';
import 'fuel_service_page.dart';
import 'import_list_page.dart';
import 'import_selling_price_page.dart';
import 'procurement_product_info_page.dart';
import 'procurement_workflow_page.dart';
import 'sales_page.dart';
import 'supplier_list_page.dart';

class TransactionDashboardPage extends StatefulWidget {
  const TransactionDashboardPage({super.key});

  @override
  State<TransactionDashboardPage> createState() =>
      _TransactionDashboardPageState();
}

class _TransactionDashboardPageState extends State<TransactionDashboardPage> {
  bool isStorageStaff = false;
  bool isAdmin = false;

  /// Menu Impor Barang: strictly role 'admin' saja — berbeda dari [isAdmin]
  /// yang juga memuat super_admin (permintaan bisnis: fitur impor hanya
  /// boleh muncul untuk admin).
  bool canSeeImportMenu = false;
  bool isSupervisor = false;
  bool isSales = false;
  bool isStaff = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final userData = json.decode(userString);
        final userRoles = List<String>.from(userData['roles'] ?? []);
        if (mounted) {
          setState(() {
            isStorageStaff = userRoles.contains('storage-staff');
            isAdmin = userRoles.contains('admin') ||
                userRoles.contains('super_admin');
            canSeeImportMenu = userRoles.contains('admin');
            isSupervisor = userRoles.contains('supervisor');
            isSales = userRoles.contains('sales');
            isStaff = userRoles.contains('staff');
          });
        }
      }
    } catch (_) {}
  }

  Widget _buildMenuSectionHeader(
    BuildContext context, {
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

  @override
  Widget build(BuildContext context) {
    final showSales = isStorageStaff || isAdmin || isSales;
    final showSupplier = isAdmin || isSupervisor || isStaff;

    return DashboardScaffold(
      currentIndex: 3,
      title: 'Layanan Kasir & Penjualan',
      subtitle:
          'Kelola penjualan, tutup shift toko, pengadaan, dan operasional kendaraan.',
      customBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMenuSectionHeader(
            context,
            icon: Icons.point_of_sale_outlined,
            title: 'Penjualan & Kasir',
          ),
          AppSpacing.gapVerticalSM,
          if (showSales)
            _TransactionMenuListCard(
              icon: Icons.point_of_sale_outlined,
              title: 'Penjualan',
              subtitle: 'Catat penjualan: online, employee, atau direct.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SalesPage()),
                );
              },
            ),
          // Info harga jual terakhir per produk (admin) — turunan konfigurasi
          // mete atas HPP impor; fase informasi.
          if (canSeeImportMenu)
            _TransactionMenuListCard(
              icon: Icons.sell_outlined,
              title: 'Harga Jual',
              subtitle:
                  'Info harga jual terakhir per produk dari konfigurasi mete.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ImportSellingPricePage()),
                );
              },
            ),
          if (isAdmin)
            _TransactionMenuListCard(
              icon: Icons.chat_outlined,
              title: 'Order Terakhir User',
              subtitle: 'Kapan terakhir customer order & hubungi via WhatsApp.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminLastOrderUserListPage()),
                );
              },
            ),
          _TransactionMenuListCard(
            icon: Icons.storefront_outlined,
            title: 'Tutup Shift Toko',
            subtitle: 'Catat laci kasir, setoran EDC & closing toko.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ClosingStorePage()),
              );
            },
          ),
          AppSpacing.gapVerticalMD,
          _buildMenuSectionHeader(
            context,
            icon: Icons.receipt_long_outlined,
            title: 'Pengadaan & Operasional',
          ),
          AppSpacing.gapVerticalSM,
          _TransactionMenuListCard(
            icon: Icons.timeline_outlined,
            title: 'Pembelian',
            subtitle:
                'Lacak & proses alur lengkap: Request → Invoice → Bayar.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProcurementWorkflowPage()),
              );
            },
          ),
          // Info beli bahan baku (admin): tanggal beli terakhir per toko,
          // harga satuan terakhir, dan yang sedang dalam invoice belum lunas.
          if (isAdmin)
            _TransactionMenuListCard(
              icon: Icons.inventory_2_outlined,
              title: 'Info Beli Bahan Baku',
              subtitle:
                  'Kapan terakhir tiap bahan baku dibeli per toko & harga satuan terakhirnya.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const ProcurementProductInfoPage()),
                );
              },
            ),
          if (canSeeImportMenu)
            _TransactionMenuListCard(
              icon: Icons.public_outlined,
              title: 'Impor Barang',
              subtitle:
                  'Tahapan impor + kelengkapan dokumen → HPP per produk.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ImportListPage()),
                );
              },
            ),
          _TransactionMenuListCard(
            icon: Icons.local_gas_station_outlined,
            title: 'Bensin & Servis',
            subtitle: 'Catat pengeluaran bensin dan servis kendaraan.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FuelServicePage()),
              );
            },
          ),
          if (showSupplier) ...[
            AppSpacing.gapVerticalMD,
            _buildMenuSectionHeader(
              context,
              icon: Icons.business_outlined,
              title: 'Data Master',
            ),
            AppSpacing.gapVerticalSM,
            _TransactionMenuListCard(
              icon: Icons.store_mall_directory_outlined,
              title: 'Supplier',
              subtitle: 'Kelola daftar supplier & nomor rekening bank.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SupplierListPage()),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionMenuListCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _TransactionMenuListCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : trailing = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLG,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: AppSpacing.borderRadiusMD,
                ),
                child: Icon(icon, color: effectiveColor, size: 24),
              ),
              AppSpacing.gapHorizontalMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
