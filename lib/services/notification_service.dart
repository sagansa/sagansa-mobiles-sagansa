// ====================================================================
// Service Notification Center — mengambil & mengelola notifikasi dari
// endpoint /notifications (persist di tabel `notifications` backend).
// Pola mirip service lainnya (ApiClient singleton).
// ====================================================================

import '../models/notification_model.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final ApiClient _api = ApiClient();

  /// List notifikasi (paginasi sederhana). ?unread=1 memfilter yang belum
  /// dibaca. Mengembalikan list + flag has_more.
  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (unreadOnly) 'unread': '1',
    };
    final body = await _api.getRaw('notifications', queryParams: query);
    final List<dynamic> data = body['data'] is List ? body['data'] : [];
    final meta = body['pagination'] is Map ? body['pagination'] : <String, dynamic>{};
    final hasMore = (meta['current_page'] ?? 1) < (meta['last_page'] ?? 1);
    return {
      'data': data
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      'has_more': hasMore,
    };
  }

  /// Jumlah notifikasi belum dibaca (untuk badge bell).
  Future<int> getUnreadCount() async {
    final body = await _api.getRaw('notifications/unread-count');
    final data = body['data'] is Map ? body['data'] : <String, dynamic>{};
    return (data['count'] as int?) ?? 0;
  }

  /// Tandai satu notifikasi sudah dibaca.
  Future<void> markRead(int id) async {
    await _api.post('notifications/$id/read');
  }

  /// Tandai semua notifikasi user sudah dibaca.
  Future<void> markAllRead() async {
    await _api.post('notifications/read-all');
  }

  /// Hapus satu notifikasi (dari swipe-to-delete).
  Future<void> deleteNotification(int id) async {
    await _api.delete('notifications/$id');
  }

  /// Hapus semua notifikasi milik user. Mengembalikan jumlah terhapus.
  Future<int> clearAll() async {
    final data = await _api.delete('notifications/clear');
    return data is Map ? (data['deleted'] as int? ?? 0) : 0;
  }
}
