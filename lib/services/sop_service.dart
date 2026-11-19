import '../models/sop_model.dart';
import 'api_client.dart';

/// Layanan konten SOP (read-only): kategori, daftar SOP, dan detail
/// beserta langkah-langkahnya.
class SopService {
  final ApiClient _api = ApiClient();

  static const _endpoint = 'sops';
  static const _categoriesEndpoint = 'sop-categories';

  /// Kategori aktif beserta jumlah SOP terbit di dalamnya.
  Future<List<SopCategoryModel>> getCategories() async {
    final data = await _api.get(_categoriesEndpoint);
    final list = data as List? ?? [];
    return list
        .map((e) => SopCategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Daftar SOP terbit (terpaginasi), opsional difilter kategori dan
  /// dicari pada judul.
  Future<Map<String, dynamic>> getSops({
    int? categoryId,
    String? query,
    int page = 1,
    int perPage = 15,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (categoryId != null) qp['category_id'] = categoryId.toString();
    if (query != null && query.trim().isNotEmpty) qp['q'] = query.trim();
    final json = await _api.getRaw(_endpoint, queryParams: qp);
    return _parsePaged(json);
  }

  /// Detail SOP beserta langkah terurut.
  Future<SopModel> getSopDetail(int id) async {
    final data = await _api.get('$_endpoint/$id');
    return SopModel.fromJson(data as Map<String, dynamic>);
  }

  Map<String, dynamic> _parsePaged(dynamic json) {
    final map = json as Map<String, dynamic>;
    final ok = map['success'] == true || map['status'] == 'success';
    if (!ok) {
      throw Exception(map['message'] ?? 'Gagal memuat panduan SOP.');
    }
    final list = (map['data'] as List? ?? [])
        .map((e) => SopModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = (map['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final currentPage = (meta['current_page'] ?? 1) as num;
    final lastPage = (meta['last_page'] ?? 1) as num;
    return {
      'data': list,
      'has_more': currentPage < lastPage,
    };
  }
}
