// ====================================================================
// Provider Notification Center — state global untuk badge bell & event
// notifikasi baru masuk.
//
// Mengikuti PRD_PROVIDER_STANDARD.md (Section 4.3A — Global Provider):
//   - Widget → Provider → Service → ApiClient.
//   - Instance singleton (didaftarkan di main.dart via .value) agar bisa
//     dipanggil dari kode non-widget (FCM foreground handler) untuk
//     refresh badge & memberi tahu halaman daftar bahwa ada notif baru.
//
// Kontrak:
//   - [unreadCount] = badge bell. Di-update oleh operasi lokal (hapus/clear/
//     read) maupun remote (push masuk).
//   - [revision] hanya naik saat ada notifikasi baru dari luar (push FCM).
//     Halaman daftar notifikasi me-watch ini untuk auto-reload halaman 1.
// ====================================================================

import 'package:flutter/foundation.dart';

import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider._();
  static final NotificationProvider instance = NotificationProvider._();

  final NotificationService _service = NotificationService.instance;

  /// Jumlah notifikasi belum dibaca (badge bell di HomePage).
  int _unreadCount = 0;

  /// Naik tiap kali ada notifikasi baru masuk dari push (bukan operasi lokal).
  int _revision = 0;

  int get unreadCount => _unreadCount;
  int get revision => _revision;

  /// Refresh jumlah unread dari server (best-effort). Dipanggil saat app
  /// start, setelah login, saat push masuk, dan setelah operasi hapus/read.
  Future<void> refreshUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      if (count != _unreadCount) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (_) {
      // Abaikan kegagalan (mis. token expired); badge cukup tidak tampil.
    }
  }

  /// Set langsung jumlah unread dari hasil operasi lokal (delete/clear/read).
  void setUnreadCount(int count) {
    if (count != _unreadCount) {
      _unreadCount = count;
      notifyListeners();
    }
  }

  /// Dipanggil FCM foreground handler saat notifikasi baru masuk:
  /// menaikkan revision (halaman daftar reload) lalu refresh count (badge).
  Future<void> onNotificationReceived() async {
    _revision++;
    notifyListeners();
    await refreshUnreadCount();
  }
}
