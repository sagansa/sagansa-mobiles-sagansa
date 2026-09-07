import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/dashboard_scaffold.dart';
import 'closing_store_page.dart';
import 'fuel_service_page.dart';
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
            isSupervisor = userRoles.contains('supervisor');
            isSales = userRoles.contains('sales');
            isStaff = userRoles.contains('staff');
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      currentIndex: 3,
      title: 'Layanan Kasir & Penjualan',
      subtitle:
          'Kelola tutup shift laci kasir, pelacakan kurir, cetak stiker, dan invoice.',
      menuItems: [
        DashboardMenuItem(
          icon: Icons.point_of_sale_outlined,
          title: 'Penjualan',
          subtitle: 'Catat penjualan: online, employee, atau direct.',
          visible: isStorageStaff || isAdmin || isSales,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SalesPage()),
            );
          },
        ),
        DashboardMenuItem(
          icon: Icons.timeline_outlined,
          title: 'Pembelian',
          subtitle: 'Lacak & proses alur lengkap: Request → Invoice → Payment Receipt.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ProcurementWorkflowPage()),
            );
          },
        ),
        DashboardMenuItem(
          icon: Icons.storefront_outlined,
          title: 'Tutup Shift Toko',
          subtitle: 'Catat laci kasir, setoran EDC & closing toko.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ClosingStorePage()),
            );
          },
        ),
        DashboardMenuItem(
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
        DashboardMenuItem(
          icon: Icons.store_mall_directory_outlined,
          title: 'Supplier',
          subtitle: 'Kelola daftar supplier & rekening bank.',
          visible: isAdmin || isSupervisor || isStaff,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const SupplierListPage()),
            );
          },
        ),
      ],
    );
  }
}
