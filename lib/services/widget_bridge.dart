import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Jembatan app Flutter → widget iOS (SagansaWidget extension).
///
/// Widget membaca token & role dari App Group UserDefaults, lalu fetch
/// `/sales-dashboard` sendiri sesuai jadwal timeline WidgetKit — lihat
/// `mobiles/sagansa-widget-shared` (package Swift bersama dengan macOS).
///
/// Kunci `auth_token`/`is_admin` adalah kontrak lintas platform: sama dengan
/// yang dibaca `DashboardStore` di sisi Swift. Semua error ditelan karena
/// widget adalah fitur pelengkap — kegagalan sync tidak boleh mengganggu
/// jalannya app.
class WidgetBridge {
  WidgetBridge._();

  static const String appGroupId = 'group.id.sagansa.app';

  /// KIND widget WidgetKit (bukan nama target extension) — harus sama dengan
  /// `StaticConfiguration(kind:)` di SagansaDashboardWidget.swift.
  static const String _widgetKind = 'SagansaDashboard';

  static const String _keyToken = 'auth_token';
  static const String _keyIsAdmin = 'is_admin';

  /// Sinkronkan status auth terbaru ke widget + reload timeline-nya.
  ///
  /// [token] `null`/kosong berarti logout → widget menampilkan state
  /// "Belum Login". Dipanggil dari AuthProvider saat load awal, login,
  /// logout, dan updateToken.
  static Future<void> syncAuth({required String? token, required bool isAdmin}) async {
    final effectiveToken = (token == null || token.isEmpty) ? null : token;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.saveWidgetData<String>(_keyToken, effectiveToken);
      await HomeWidget.saveWidgetData<bool>(_keyIsAdmin, isAdmin);
      await HomeWidget.updateWidget(iOSName: _widgetKind);
    } catch (e) {
      debugPrint('WidgetBridge.syncAuth failed: $e');
    }
  }
}
