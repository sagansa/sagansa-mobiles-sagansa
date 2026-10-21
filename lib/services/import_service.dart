import '../models/enums/import_stage.dart';
import '../models/import_model.dart';
import 'api_client.dart';

/// 422 advance/finalize yang membawa daftar blocker spesifik dari server.
class ImportBlockedException implements Exception {
  final String message;
  final List<ImportBlocker> blockers;

  ImportBlockedException({required this.message, required this.blockers});

  /// Bypass hanya relevan bila SEMUA blocker berupa dokumen yang kurang.
  bool get canBypassDocuments =>
      blockers.isNotEmpty && blockers.every((b) => b.isDocument);

  @override
  String toString() => message;
}

/// Service modul impor barang (tahapan + dokumen + HPP per produk).
///
/// Endpoint: /import-purchases — tulis di-guard admin/super_admin di
/// backend; kegagalan 422 advance/finalize yang membawa daftar syarat
/// dilempar sebagai [ImportBlockedException] berisi blocker spesifik.
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
    // Backend lama mengirim stage_counts sebagai [] (array PHP kosong
    // diserialisasi menjadi list) — jangan cast langsung ke Map.
    final rawCounts = meta['stage_counts'];
    final stageCounts = rawCounts is Map<String, dynamic>
        ? rawCounts.map((k, v) => MapEntry(k, (v is num ? v.toInt() : 0)))
        : <String, int>{};
    final pagination = body['pagination'] as Map<String, dynamic>? ?? {};
    final hasMore = (pagination['current_page'] ?? 1) <
        (pagination['last_page'] ?? 1);

    return {
      'data': rows,
      'stage_counts': stageCounts,
      'has_more': hasMore,
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

  /// Maju satu tahap. Dengan [bypassDocuments], gerbang dokumen dilewati
  /// (syarat data/state tetap dicek server). Kegagalan gerbang dilempar
  /// sebagai [ImportBlockedException] berisi daftar syarat yang kurang.
  Future<void> advance(int importId, {bool bypassDocuments = false}) async {
    try {
      await _api.postRaw(
        'import-purchases/$importId/advance',
        body: bypassDocuments ? {'bypass_documents': true} : null,
      );
    } on ApiException catch (e) {
      _blockedOrRethrow(e);
    }
  }

  /// Finalisasi: hitung HPP final per produk & update products.hpp.
  /// Return ringkasan HPP untuk ditampilkan.
  Future<ImportHppResult> finalize(int importId) async {
    try {
      final body = await _api.postRaw('import-purchases/$importId/finalize');
      final hpp = body['hpp'] as Map<String, dynamic>?;
      if (hpp == null) {
        throw Exception('Response finalize tidak valid.');
      }
      return ImportHppResult.fromJson(hpp);
    } on ApiException catch (e) {
      _blockedOrRethrow(e);
    }
  }

  Future<void> cancel(int importId) async {
    await _api.post('import-purchases/$importId/cancel');
  }

  /// Hapus permanen proses impor (belum final) beserta item, biaya &
  /// dokumennya. Server menolak (422) bila sudah final.
  Future<void> deleteImport(int importId) async {
    await _api.delete('import-purchases/$importId');
  }

  /// Ubah ApiException 422 dengan `data.blockers` menjadi
  /// [ImportBlockedException]; selain itu dilempar ulang apa adanya.
  Never _blockedOrRethrow(ApiException e) {
    final data = e.body?['data'];
    final raw = data is Map<String, dynamic> ? data['blockers'] : null;
    if (e.statusCode == 422 && raw is List && raw.isNotEmpty) {
      throw ImportBlockedException(
        message: e.message,
        blockers: raw
            .whereType<Map<String, dynamic>>()
            .map(ImportBlocker.fromJson)
            .toList(growable: false),
      );
    }
    throw e;
  }
}
