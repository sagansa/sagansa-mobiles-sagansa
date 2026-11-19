import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryStatusRepository {
  final SharedPreferencesAsync? prefsAsync;

  DeliveryStatusRepository({this.prefsAsync});

  Future<Set<int>> loadPrintedStickers() async {
    final prefs = await SharedPreferences.getInstance();
    final printedList = prefs.getStringList('printed_stickers') ?? [];
    return printedList.map((id) => int.tryParse(id) ?? 0).toSet();
  }

  Future<void> savePrintedSticker(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final printedList = prefs.getStringList('printed_stickers') ?? [];
    final updated = {...printedList.map((id) => int.tryParse(id) ?? 0), orderId};
    await prefs.setStringList(
      'printed_stickers',
      updated.map((id) => id.toString()).toList(),
    );
  }

  Future<bool> loadAdminRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString == null) return false;
    final userData = json.decode(userString);
    final roles = List<String>.from(userData['roles'] ?? []);
    return roles.contains('admin') ||
        roles.contains('super_admin') ||
        roles.contains('supervisor');
  }

  /// Boleh mengelola kaitan invoice↔penjualan (kartu di detail penjualan
  /// direct): admin/super_admin + storage-staff. Sengaja TERPISAH dari
  /// loadAdminRole() (yang juga menghitung supervisor) — guard backend
  /// sales_order_id tidak memasukkan supervisor.
  Future<bool> loadCanManageSalesLink() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString == null) return false;
    final userData = json.decode(userString);
    final roles = List<String>.from(userData['roles'] ?? []);
    return roles.contains('admin') ||
        roles.contains('super_admin') ||
        roles.contains('storage-staff');
  }

  /// Boleh mengganti foto bukti pengiriman (icon edit di kartu foto detail
  /// penjualan direct): admin/super_admin SAJA — tanpa supervisor dan tanpa
  /// storage-staff, mengikuti guard backend POST /sales-orders/{id}/
  /// delivery-photos. Tanpa syarat status order. Sengaja TERPISAH dari
  /// loadAdminRole() (yang juga menghitung supervisor).
  Future<bool> loadDeliveryPhotoEditRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString == null) return false;
    final userData = json.decode(userString);
    final roles = List<String>.from(userData['roles'] ?? []);
    return roles.contains('admin') || roles.contains('super_admin');
  }
}
