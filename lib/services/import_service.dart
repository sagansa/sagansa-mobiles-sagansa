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

/// Satu kurs resolved untuk satu tanggal — hasil backend terpusat
/// (`GET /currency-rates`). [source]: `manual` (input admin, menimpa),
/// `public` (referensi publik; [sourceDate] ≠ tanggal diminta berarti
/// kurs tanggal terdekat), `latest` (jatuh ke kurs terkini).
class CurrencyRateEntry {
  final double rate;
  final String source;
  final String sourceDate;

  const CurrencyRateEntry({
    required this.rate,
    required this.source,
    required this.sourceDate,
  });

  factory CurrencyRateEntry.fromJson(Map<String, dynamic> json) {
    return CurrencyRateEntry(
      rate: (json['rate'] as num).toDouble(),
      source: (json['source'] ?? 'public').toString(),
      sourceDate: (json['source_date'] ?? '').toString(),
    );
  }
}

/// Kurs pasangan USD → VND per tanggal + kurs terkini (tersimpan terpusat
/// di server; server pula yang mengambil/meng-cache referensi publik).
class CurrencyRatesResult {
  final double? latestRate;
  final String? latestDate;
  final Map<String, CurrencyRateEntry> rates;

  const CurrencyRatesResult({
    this.latestRate,
    this.latestDate,
    this.rates = const {},
  });

  factory CurrencyRatesResult.fromJson(Map<String, dynamic> json) {
    final raw = json['rates'];
    return CurrencyRatesResult(
      latestRate: json['latest'] == null
          ? null
          : ((json['latest'] as Map<String, dynamic>)['rate'] as num?)
              ?.toDouble(),
      latestDate: json['latest'] == null
          ? null
          : ((json['latest'] as Map<String, dynamic>)['date'] ?? '')
              .toString(),
      rates: raw is Map<String, dynamic>
          ? raw.map((k, v) => MapEntry(
              k, CurrencyRateEntry.fromJson(v as Map<String, dynamic>)))
          : const {},
    );
  }

  CurrencyRatesResult withEntry(String dayKey, CurrencyRateEntry? entry) {
    final next = Map<String, CurrencyRateEntry>.from(rates);
    if (entry == null) {
      next.remove(dayKey);
    } else {
      next[dayKey] = entry;
    }
    return CurrencyRatesResult(
      latestRate: latestRate,
      latestDate: latestDate,
      rates: next,
    );
  }
}

/// Service modul impor barang (tahapan + dokumen + HPP per produk).
///
/// Endpoint: /import-purchases — tulis di-guard admin/super_admin di
/// backend; kegagalan 422 advance/finalize yang membawa daftar syarat
/// dilempar sebagai [ImportBlockedException] berisi blocker spesifik.
class ImportService {
  final ApiClient _api = ApiClient();

  /* ------------------------------------------------------ KURS USD→VND */

  /// Kurs USD → VND resolved per tanggal + terkini (terpusat). [dates]
  /// = tanggal pembelian (yyyy-MM-dd) yang dibutuhkan analisa.
  Future<CurrencyRatesResult> getUsdVndRates([Set<String> dates = const {}]) async {
    final body = await _api.getRaw('currency-rates', queryParams: {
      'base': 'USD',
      'quote': 'VND',
      if (dates.isNotEmpty) 'dates': dates.toList().join(','),
    });
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat kurs USD → VND.');
    }
    return CurrencyRatesResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Simpan kurs manual satu tanggal (menimpa referensi publik).
  Future<CurrencyRateEntry> saveUsdVndRate(String date, double rate) async {
    final body = await _api.postRaw('currency-rates', body: {
      'base': 'USD',
      'quote': 'VND',
      'rate_date': date,
      'rate': rate,
    });
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal menyimpan kurs manual.');
    }
    return CurrencyRateEntry.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Hapus kurs manual satu tanggal — kembali ke referensi publik.
  /// Return resolved entry setelah hapus (bisa null bila tak tersedia).
  Future<CurrencyRateEntry?> deleteUsdVndRate(String date) async {
    final body = await _api.delete('currency-rates', queryParams: {
      'base': 'USD',
      'quote': 'VND',
      'date': date,
    }) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal menghapus kurs manual.');
    }
    final data = body['data'];
    return data is Map<String, dynamic>
        ? CurrencyRateEntry.fromJson(data)
        : null;
  }

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
    final hasMore =
        (pagination['current_page'] ?? 1) < (pagination['last_page'] ?? 1);

    return {
      'data': rows,
      'stage_counts': stageCounts,
      'has_more': hasMore,
    };
  }

  /// Impor terakhir (bukan cancelled) untuk template nominal realisasi
  /// biaya pada form create. Produk tidak dipakai; pemanggil hanya
  /// mengambil biaya non-pajak karena PPh/PPN bergantung pada nilai barang
  /// yang baru.
  Future<ImportPurchase?> getLatestForCostTemplate() async {
    final rows = (await getImports(page: 1, perPage: 10))['data']
        as List<ImportPurchase>;
    for (final row in rows) {
      if (row.stage.isCancelled) continue;
      try {
        return (await getDetail(row.id)).importPurchase;
      } catch (_) {
        // Lewati record yang gagal dimuat; coba kandidat berikutnya.
      }
    }
    return null;
  }

  /// Trend harga satuan seluruh produk dari semua proses impor yang
  /// tidak dibatalkan — tiap titik berisi harga valuta asli dan rupiah.
  Future<List<ImportProductPriceTrend>> getPriceTrends() async {
    final body = await _api.getRaw('import-purchases/price-trends');
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat trend harga.');
    }
    return (body['data'] as List<dynamic>? ?? [])
        .map((e) => ImportProductPriceTrend.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
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
  /// invoice_number?, purchase_date, items: [...], costs: [...]} — return
  /// id record baru.
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

  /// Simpan jumlah diterima, pembayaran per tranche, biaya lain, dan notul.
  /// Mengirim list kosong akan menghapus semua baris pada bagian tersebut.
  Future<void> receive(
    int importId, {
    List<Map<String, dynamic>> items = const [],
    List<Map<String, dynamic>>? costs,
    List<Map<String, dynamic>>? payments,
    List<Map<String, dynamic>>? notuls,
  }) async {
    await _api.post('import-purchases/$importId/receive', body: {
      'items': items,
      if (costs != null) 'costs': costs,
      if (payments != null) 'payments': payments,
      if (notuls != null) 'notuls': notuls,
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
