import '../models/production_model.dart';
import '../utils/constants.dart';
import 'api_client.dart';

/// Service operasional produksi: list/detail/create/update items + apply/revert
/// mutasi stok. Semua endpoint butuh role admin/super_admin (dicek di backend).
class ProductionService {
  final ApiClient _api = ApiClient();

  String _relative(String full) {
    final base = ApiConstants.baseUrl;
    return full.replaceFirst('$base/', '');
  }

  /// List produksi. Filter opsional: storeId, status ('1'..'4'), applied.
  Future<({List<Production> items, int? nextPage})> list({
    int page = 1,
    int perPage = 20,
    int? storeId,
    String? status,
    bool? applied,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      if (storeId != null) 'store_id': '$storeId',
      if (status != null) 'status': status,
      if (applied != null) 'applied': applied ? '1' : '0',
    };
    final body = await _api.getRaw(
      _relative(ApiConstants.productions),
      queryParams: params,
    );
    final data = (body['data'] as List? ?? const [])
        .map((e) => Production.fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = body['pagination'] as Map<String, dynamic>?;
    final next = pagination != null &&
            (pagination['current_page'] as num?)!.toInt() <
                (pagination['last_page'] as num?)!.toInt()
        ? page + 1
        : null;
    return (items: data, nextPage: next);
  }

  /// Detail produksi by id (sudah include items + relasi).
  Future<Production> show(int id) async {
    final data = await _api.get(
      '${_relative(ApiConstants.productions)}/$id',
    );
    return Production.fromJson(data as Map<String, dynamic>);
  }

  /// Daftar detail invoice yang masih tersedia (status '1') di sebuah toko
  /// untuk dijadikan bahan baku produksi. Definisi produksi: wajib dibuat
  /// berdasarkan invoice (sinkron dengan admin ProductionMainFroms).
  Future<List<ProductionDetailInvoice>> availableDetailInvoices(
      int storeId) async {
    final data = await _api.get(
      '${_relative(ApiConstants.productions)}/detail-invoices',
      queryParams: {'store_id': storeId.toString()},
    );
    final list = data as List? ?? const [];
    return list
        .map((e) =>
            ProductionDetailInvoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create produksi baru. Bila `recipeId` diisi, backend akan auto-prefill
  /// items dari resep.
  Future<Production> create({
    required int storeId,
    required DateTime date,
    int? recipeId,
    String? notes,
    String status = '1',
    List<ProductionItem> items = const [],
  }) async {
    final payload = <String, dynamic>{
      'store_id': storeId,
      'date': _dateStr(date),
      'status': status,
      if (recipeId != null) 'recipe_id': recipeId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (items.isNotEmpty) 'items': items.map((i) => i.toJson()).toList(),
    };

    final data = await _api.post(
      _relative(ApiConstants.productions),
      body: payload,
    );
    return Production.fromJson(data as Map<String, dynamic>);
  }

  /// Update header production (hanya bila belum applied).
  Future<Production> update(
    int id, {
    int? storeId,
    DateTime? date,
    int? recipeId,
    String? notes,
    String? status,
  }) async {
    final payload = <String, dynamic>{
      if (storeId != null) 'store_id': storeId,
      if (date != null) 'date': _dateStr(date),
      if (recipeId != null) 'recipe_id': recipeId,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
    };

    final data = await _api.put(
      '${_relative(ApiConstants.productions)}/$id',
      body: payload,
    );
    return Production.fromJson(data as Map<String, dynamic>);
  }

  /// Apply mutasi stok production. Idempoten (backend cek applied_at).
  Future<DateTime> apply(int id) async {
    final data = await _api.post(
      '${_relative(ApiConstants.productions)}/$id/apply',
    );
    final appliedAt = (data as Map<String, dynamic>?)?['applied_at'] as String?;
    return appliedAt == null
        ? DateTime.now()
        : (DateTime.tryParse(appliedAt) ?? DateTime.now());
  }

  /// Revert mutasi stok production. Idempoten.
  Future<void> revert(int id) async {
    await _api.post('${_relative(ApiConstants.productions)}/$id/revert');
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
