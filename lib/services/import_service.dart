import '../models/enums/import_stage.dart';
import '../models/import_model.dart';
import 'api_client.dart';

/// Service modul impor barang (tahapan + dokumen + HPP per produk).
///
/// Endpoint: /import-purchases — tulis di-guard admin/super_admin di
/// backend; kegagalan 422 (mis. gerbang dokumen belum lengkap) dilempar
/// sebagai Exception dengan pesan server.
class ImportService {
  final ApiClient _api = ApiClient();

  /// List + filter tahap. Return data, has_more, stage_counts.
  Future<Map<String, dynamic>> getImports({
    int page = 1,
    int perPage = 20,
    String? stage,
  }) async {
    final body = await _api.getRaw('import-purchases', queryParams: {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (stage != null && stage.isNotEmpty) 'stage': stage,
    });
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat data impor.');
    }
    final rows = (body['data'] as List<dynamic>? ?? [])
        .map((e) => ImportPurchase.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = body['meta'] as Map<String, dynamic>? ?? {};
    final stageCounts = (meta['stage_counts'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v is num ? v.toInt() : 0)));

    return {
      'data': rows,
      'stage_counts': stageCounts,
    };
  }

  Future<ImportPurchaseDetail> getDetail(int id) async {
    final body = await _api.getRaw('import-purchases/$id');
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat detail impor.');
    }

    final importPurchase =
        ImportPurchase.fromJson(body['data'] as Map<String, dynamic>);
    final hpp = ImportHppResult.fromJson(body['hpp'] as Map<String, dynamic>);
    final checklist = ((body['checklist'] as Map<String, dynamic>? ?? {})
            .entries
            .map((e) => ImportStageCheck.fromEntry(
                e.key, e.value as Map<String, dynamic>))
            .toList())
        .toList(growable: false);
    final next = body['next_stage']?.toString();

    return ImportPurchaseDetail(
      importPurchase: importPurchase,
      hpp: hpp,
      checklist: checklist,
      nextStage: next == null ? null : ImportStage.fromApi(next),
    );
  }

  /// Buat draft baru. [payload] = {supplier_id, currency, exchange_rate,
  /// notes?, items: [...], costs: [...]} — return id record baru.
  Future<int> createImport(Map<String, dynamic> payload) async {
    final body = await _api.postRaw('import-purchases', body: payload);
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response create impor tidak valid.');
    }
    return (data['id'] as num).toInt();
  }

  /// Update header/items/costs (full-replace item & costs bila dikirim).
  Future<void> updateImport(int id, Map<String, dynamic> payload) async {
    await _api.putRaw('import-purchases/$id', body: payload);
  }

  /// Lampirkan dokumen (path hasil upload ke img service).
  Future<void> attachDocument(
    int importId, {
    required String type,
    required String filePath,
    String? originalName,
    String? mimeType,
    int? sizeBytes,
  }) async {
    await _api.post('import-purchases/$importId/documents', body: {
      'type': type,
      'file_path': filePath,
      if (originalName != null) 'original_name': originalName,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
    });
  }

  Future<void> deleteDocument(int importId, int documentId) async {
    await _api.delete('import-purchases/$importId/documents/$documentId');
  }

  /// Simpan jumlah diterima per item + realisasi biaya per cost.
  Future<void> receive(
    int importId, {
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>>? costs,
  }) async {
    await _api.post('import-purchases/$importId/receive', body: {
      'items': items,
      if (costs != null) 'costs': costs,
    });
  }

  /// Maju satu tahap. Melempar Exception bermuat pesan server bila gerbang
  /// (dokumen/data) belum terpenuhi.
  Future<void> advance(int importId) async {
    await _api.post('import-purchases/$importId/advance');
  }

  /// Finalisasi: hitung HPP final per produk & update products.hpp.
  /// Return ringkasan HPP untuk ditampilkan.
  Future<ImportHppResult> finalize(int importId) async {
    final body = await _api.postRaw('import-purchases/$importId/finalize');
    final hpp = body['hpp'] as Map<String, dynamic>?;
    if (hpp == null) {
      throw Exception('Response finalize tidak valid.');
    }
    return ImportHppResult.fromJson(hpp);
  }

  Future<void> cancel(int importId) async {
    await _api.post('import-purchases/$importId/cancel');
  }
}
