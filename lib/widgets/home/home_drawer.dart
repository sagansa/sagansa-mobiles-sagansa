import 'package:flutter/material.dart';
import '../app_drawer.dart';

/// Drawer aplikasi di Home dengan desain autentik iOS Glassmorphism.
///
/// Meneruskan tampilan dan logika ke [AppDrawer] terpadu agar konsisten
/// di seluruh aplikasi (Beranda maupun seluruh modul dashboard operasional).
class HomeDrawer extends StatelessWidget {
  final String userName;
  final String companyName;
  final bool isAdmin;

  /// Dipanggil saat user mengkonfirmasi logout.
  final Future<void> Function() onLogout;

  const HomeDrawer({
    super.key,
    required this.userName,
    required this.companyName,
    required this.isAdmin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AppDrawer(
      userName: userName,
      companyName: companyName,
      isAdmin: isAdmin,
      showAppVersion: true,
      onLogout: (_) => onLogout(),
    );
  }
}
