import '../models/last_order_user_detail_model.dart';
import '../models/last_order_user_model.dart';
import 'api_client.dart';

/// Daftar user + order direct terakhirnya (khusus admin).
class LastOrderUserService {
  final ApiClient _api = ApiClient();

  /// [sort]: 'last_order_desc' (default) | 'last_order_asc'.
  /// [hasPhone]: true = hanya user yang punya no telp.
  /// Mengembalikan (list, hasNext) — pola SalesOrderEmployeeService.
  Future<(List<LastOrderUserModel>, bool)> getList({
    int page = 1,
    int perPage = 20,
    String? search,
    String sort = 'last_order_desc',
    bool? hasPhone,
  }) async {
    final body = await _api.getRaw(
      'admin/last-orders',
      queryParams: {
        'page': '$page',
        'per_page': '$perPage',
        'sort': sort,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (hasPhone == true) 'has_phone': '1',
      },
    );
    final data = (body['data'] as List<dynamic>?) ?? [];
    final meta = (body['meta'] as Map<String, dynamic>?) ?? {};
    final list = data
        .map((e) => LastOrderUserModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final currentPage = (meta['current_page'] as num? ?? 1).toInt();
    final lastPage = (meta['last_page'] as num? ?? 1).toInt();
    return (list, currentPage < lastPage);
  }

  /// Detail satu user: info + summary produk all-time + riwayat follow-up.
  Future<LastOrderUserDetail> getDetail(int userId) async {
    final data = await _api.get('admin/last-orders/$userId');
    return LastOrderUserDetail.fromJson(
        (data as Map<String, dynamic>?) ?? {});
  }

  /// Tandai user "sudah dihubungi" (petugas = admin yang login).
  Future<void> markFollowedUp(int userId) async {
    await _api.post('admin/last-orders/$userId/follow-ups');
  }
}
