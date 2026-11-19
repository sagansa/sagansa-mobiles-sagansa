import '../utils/supplier_name.dart';
import 'enums/import_document_type.dart';
import 'enums/import_stage.dart';

/// Parse nilai numerik yang bisa datang sebagai `int`, `double`, maupun
/// `String` dari API (tergantung driver DB/MySQL) — pola procurement_model.
double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

double? _toDoubleNull(dynamic value) {
  if (value == null) return null;
  return double.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

/// Barang yang diimpor per proses (import_items).
class ImportItem {
  final int id;
  final int productId;
  final double quantity;
  final double unitPriceForeign;
  final double? quantityReceived;
  final double? hppEstimate;
  final double? hppReal;

  /// HPP satuan hasil hitung server (endpoint list) — bisa lebih baru dari
  /// snapshot [hppEstimate]/[hppReal] yang baru tersimpan saat finalisasi.
  final double? hppEstimateUnit;
  final double? hppRealUnit;
  final double? unitPriceIdr;
  final bool priceIsRealized;
  final String productName;
  final String unitName;

  ImportItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unitPriceForeign,
    this.quantityReceived,
    this.hppEstimate,
    this.hppReal,
    this.hppEstimateUnit,
    this.hppRealUnit,
    this.unitPriceIdr,
    this.priceIsRealized = false,
    required this.productName,
    required this.unitName,
  });

  factory ImportItem.fromJson(Map<String, dynamic> json) {
    return ImportItem(
      id: _toInt(json['id']),
      productId: _toInt(json['product_id']),
      quantity: _toDouble(json['quantity']),
      unitPriceForeign: _toDouble(json['unit_price_foreign']),
      quantityReceived: _toDoubleNull(json['quantity_received']),
      hppEstimate: _toDoubleNull(json['hpp_estimate']),
      hppReal: _toDoubleNull(json['hpp_real']),
      hppEstimateUnit: _toDoubleNull(json['hpp_estimate_unit']),
      hppRealUnit: _toDoubleNull(json['hpp_real_unit']),
      unitPriceIdr: _toDoubleNull(json['unit_price_idr']),
      priceIsRealized: json['price_is_realized'] == true,
      productName:
          (json['product']?['name'] ?? json['product_name'] ?? '').toString(),
      unitName: (json['product']?['unit']?['unit'] ?? '').toString(),
    );
  }

  /// Harga satuan rupiah yang ditampilkan: realisasi bila sudah ada,
  /// fallback estimasi, lalu snapshot HPP lama.
  double? get displayUnitPriceIdr {
    if ((unitPriceIdr ?? 0) > 0) return unitPriceIdr;
    if (priceIsRealized && (hppReal ?? 0) > 0) return hppReal;
    if ((hppEstimateUnit ?? 0) > 0) return hppEstimateUnit;
    if ((hppRealUnit ?? 0) > 0) return hppRealUnit;
    if ((hppEstimate ?? 0) > 0) return hppEstimate;
    return hppReal;
  }
}

/// Biaya proses impor selain nilai barang (import_costs) — estimate vs real.
class ImportCost {
  final int id;
  final String stage; // purchase|payment|shipment|customs|arrival
  final String name;
  final String category; // goods|bank|tax|logistics|other|discount
  final String? source; // payment|notul (baris turunan, read-only)
  final double? taxRate;
  final bool isForeignCurrency;
  final double? amountForeign;
  final double amountEstimate;
  final double? amountReal;

  ImportCost({
    required this.id,
    required this.stage,
    required this.name,
    required this.category,
    this.source,
    this.taxRate,
    required this.isForeignCurrency,
    this.amountForeign,
    required this.amountEstimate,
    this.amountReal,
  });

  factory ImportCost.fromJson(Map<String, dynamic> json) {
    return ImportCost(
      id: _toInt(json['id']),
      stage: (json['stage'] ?? 'other').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? 'other').toString(),
      source: json['source']?.toString(),
      taxRate: _toDoubleNull(json['tax_rate']),
      isForeignCurrency: json['is_foreign_currency'] == true,
      amountForeign: _toDoubleNull(json['amount_foreign']),
      amountEstimate: _toDouble(json['amount_estimate']),
      amountReal: _toDoubleNull(json['amount_real']),
    );
  }

  bool get isDerived => source != null;

  String get categoryLabel {
    return switch (category) {
      'bank' => 'Bank',
      'tax' => 'Pajak',
      'logistics' => 'Logistik',
      'goods' => 'Barang',
      'discount' => 'Diskon',
      _ => 'Lainnya',
    };
  }
}

/// Pembayaran bank per tranche (import_payments) — satu angka debit bank
/// yang mencakup nilai barang + biaya bank − diskon.
class ImportPayment {
  final int id;
  final double amount;
  final DateTime? paidAt;
  final String? note;
  final String? proofPath;
  final String? proofOriginalName;
  final String? proofMimeType;
  final int? proofSizeBytes;

  ImportPayment({
    required this.id,
    required this.amount,
    this.paidAt,
    this.note,
    this.proofPath,
    this.proofOriginalName,
    this.proofMimeType,
    this.proofSizeBytes,
  });

  factory ImportPayment.fromJson(Map<String, dynamic> json) {
    return ImportPayment(
      id: _toInt(json['id']),
      amount: _toDouble(json['amount']),
      paidAt: DateTime.tryParse((json['paid_at'] ?? '').toString()),
      note: json['note']?.toString(),
      proofPath: json['proof_path']?.toString(),
      proofOriginalName: json['proof_original_name']?.toString(),
      proofMimeType: json['proof_mime_type']?.toString(),
      proofSizeBytes: json['proof_size_bytes'] == null
          ? null
          : _toInt(json['proof_size_bytes']),
    );
  }

  bool get hasProof => (proofPath ?? '').isNotEmpty;
}

/// Notul pabean (import_notuls). PPh/PPN notul terbaru menjadi angka final.
class ImportNotul {
  final int id;
  final String? number;
  final DateTime? date;
  final double pphAmount;
  final double ppnAmount;
  final double penaltyAmount;
  final double otherAmount;
  final String? otherDescription;
  final String? note;
  final String? documentPath;
  final String? documentOriginalName;
  final String? documentMimeType;
  final int? documentSizeBytes;

  ImportNotul({
    required this.id,
    this.number,
    this.date,
    required this.pphAmount,
    required this.ppnAmount,
    required this.penaltyAmount,
    required this.otherAmount,
    this.otherDescription,
    this.note,
    this.documentPath,
    this.documentOriginalName,
    this.documentMimeType,
    this.documentSizeBytes,
  });

  factory ImportNotul.fromJson(Map<String, dynamic> json) {
    return ImportNotul(
      id: _toInt(json['id']),
      number: json['notul_number']?.toString(),
      date: DateTime.tryParse((json['notul_date'] ?? '').toString()),
      pphAmount: _toDouble(json['pph_amount']),
      ppnAmount: _toDouble(json['ppn_amount']),
      penaltyAmount: _toDouble(json['penalty_amount']),
      otherAmount: _toDouble(json['other_amount']),
      otherDescription: json['other_description']?.toString(),
      note: json['note']?.toString(),
      documentPath: json['document_path']?.toString(),
      documentOriginalName: json['document_original_name']?.toString(),
      documentMimeType: json['document_mime_type']?.toString(),
      documentSizeBytes: json['document_size_bytes'] == null
          ? null
          : _toInt(json['document_size_bytes']),
    );
  }

  bool get hasDocument => (documentPath ?? '').isNotEmpty;

  double get taxTotal => pphAmount + ppnAmount;
}

/// Dokumen kelengkapan proses impor (import_documents).
class ImportDocumentModel {
  final int id;
  final ImportDocumentType type;
  final String filePath;
  final String? fileUrl;
  final String? originalName;
  final String? mimeType;

  ImportDocumentModel({
    required this.id,
    required this.type,
    required this.filePath,
    this.fileUrl,
    this.originalName,
    this.mimeType,
  });

  factory ImportDocumentModel.fromJson(Map<String, dynamic> json) {
    return ImportDocumentModel(
      id: _toInt(json['id']),
      type: ImportDocumentType.fromApi(json['type']?.toString()),
      filePath: (json['file_path'] ?? '').toString(),
      fileUrl: json['file_url']?.toString(),
      originalName: json['original_name']?.toString(),
      mimeType: json['mime_type']?.toString(),
    );
  }

  bool get isPdf =>
      mimeType?.contains('pdf') == true ||
      filePath.toLowerCase().endsWith('.pdf');
}

/// Hasil perhitungan HPP satu item dari endpoint detail/finalize.
class ImportHppItemRow {
  final int id;
  final double goodsValue;
  final double? quantityReceived;
  final double allocatedEstimate;
  final double allocatedReal;
  final double hppEstimateUnit;
  final double hppRealUnit;

  ImportHppItemRow({
    required this.id,
    required this.goodsValue,
    this.quantityReceived,
    required this.allocatedEstimate,
    required this.allocatedReal,
    required this.hppEstimateUnit,
    required this.hppRealUnit,
  });

  factory ImportHppItemRow.fromJson(Map<String, dynamic> json) {
    return ImportHppItemRow(
      id: _toInt(json['id']),
      goodsValue: _toDouble(json['goods_value']),
      quantityReceived: _toDoubleNull(json['quantity_received']),
      allocatedEstimate: _toDouble(json['allocated_estimate']),
      allocatedReal: _toDouble(json['allocated_real']),
      hppEstimateUnit: _toDouble(json['hpp_estimate_unit']),
      hppRealUnit: _toDouble(json['hpp_real_unit']),
    );
  }
}

/// Ringkasan perhitungan HPP (response key `hpp`).
class ImportHppResult {
  final double goodsTotal;
  final double totalEstimate;
  final double totalReal;
  final double variance;
  final double? variancePercent;
  final double hppPajak;
  final double taxTotalEstimate;
  final double bankTotalEstimate;
  final List<ImportHppItemRow> items;

  ImportHppResult({
    required this.goodsTotal,
    required this.totalEstimate,
    required this.totalReal,
    required this.variance,
    this.variancePercent,
    required this.hppPajak,
    required this.taxTotalEstimate,
    required this.bankTotalEstimate,
    required this.items,
  });

  factory ImportHppResult.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => ImportHppItemRow.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    return ImportHppResult(
      goodsTotal: _toDouble(json['goods_total']),
      totalEstimate: _toDouble(json['total_estimate']),
      totalReal: _toDouble(json['total_real']),
      variance: _toDouble(json['variance']),
      variancePercent: _toDoubleNull(json['variance_percent']),
      hppPajak: _toDouble(json['hpp_pajak']),
      taxTotalEstimate: _toDouble(json['tax_total_estimate']),
      bankTotalEstimate: _toDouble(json['bank_total_estimate']),
      items: items,
    );
  }
}

/// Status kelengkapan satu tipe dokumen pada checklist tahap.
class ImportStageDocCheck {
  final String type;
  final String label;
  final bool required;
  final bool present;

  ImportStageDocCheck({
    required this.type,
    required this.label,
    required this.required,
    required this.present,
  });

  ImportDocumentType get typeEnum => ImportDocumentType.fromApi(type);
}

/// Satu syarat tahap yang belum terpenuhi (dari response 422
/// advance/finalize): kind = document | data | state.
class ImportBlocker {
  final String kind;
  final String message;

  const ImportBlocker({required this.kind, required this.message});

  factory ImportBlocker.fromJson(Map<String, dynamic> json) => ImportBlocker(
        kind: json['kind']?.toString() ?? 'state',
        message: json['message']?.toString() ?? '',
      );

  bool get isDocument => kind == 'document';
}

/// Checklist satu tahap: label, state (done/current/upcoming), dokumen.
class ImportStageCheck {
  final ImportStage stage;
  final String label;
  final String state; // done | current | upcoming
  final List<ImportStageDocCheck> documents;

  ImportStageCheck({
    required this.stage,
    required this.label,
    required this.state,
    required this.documents,
  });

  factory ImportStageCheck.fromEntry(String stageKey, Map<String, dynamic> v) {
    // Backend lama mengirim array PHP kosong sebagai [] (list) — bukan Map.
    final docsRaw = v['documents'];
    final docs = (docsRaw is Map<String, dynamic> ? docsRaw : const {})
        .entries
        .map((e) => ImportStageDocCheck(
              type: e.key,
              label: (e.value as Map<String, dynamic>)['label']?.toString() ??
                  e.key,
              required: (e.value as Map<String, dynamic>)['required'] == true,
              present: (e.value as Map<String, dynamic>)['present'] == true,
            ))
        .toList(growable: false);

    return ImportStageCheck(
      stage: ImportStage.fromApi(stageKey),
      label: v['label']?.toString() ?? stageKey,
      state: v['state']?.toString() ?? 'upcoming',
      documents: docs,
    );
  }

  bool get isCurrent => state == 'current';
  bool get isDone => state == 'done';
}

/// Header proses impor.
class ImportPurchase {
  final int id;
  final int supplierId;
  final String supplierName;
  final int? storeId;
  final String currency;
  final double exchangeRate;

  /// Kurs 1 USD = x VND saat transaksi (embedded, untuk analisa trend
  /// lintas valuta); null untuk transaksi lama.
  final double? usdVndRate;
  final String? invoiceNumber;
  final DateTime? purchaseDate;
  final ImportStage stage;
  final String? notes;
  final double totalEstimate;
  final double totalReal;
  final List<ImportItem> items;
  final List<ImportCost> costs;
  final List<ImportPayment> payments;
  final List<ImportNotul> notuls;
  final List<ImportDocumentModel> documents;
  final int documentCount;

  ImportPurchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    this.storeId,
    required this.currency,
    required this.exchangeRate,
    this.usdVndRate,
    this.invoiceNumber,
    this.purchaseDate,
    required this.stage,
    this.notes,
    required this.totalEstimate,
    required this.totalReal,
    required this.items,
    required this.costs,
    this.payments = const [],
    this.notuls = const [],
    required this.documents,
    this.documentCount = 0,
  });

  factory ImportPurchase.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => ImportItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final costs = (json['costs'] as List<dynamic>? ?? [])
        .map((e) => ImportCost.fromJson(e as Map<String, dynamic>))
        .toList();
    final payments = (json['payments'] as List<dynamic>? ?? [])
        .map((e) => ImportPayment.fromJson(e as Map<String, dynamic>))
        .toList();
    final notuls = (json['notuls'] as List<dynamic>? ?? [])
        .map((e) => ImportNotul.fromJson(e as Map<String, dynamic>))
        .toList();
    final documents = (json['documents'] as List<dynamic>? ?? [])
        .map((e) => ImportDocumentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ImportPurchase(
      id: _toInt(json['id']),
      supplierId: _toInt(json['supplier_id']),
      supplierName: formatSupplierName(
        (json['supplier']?['name'] ?? json['supplier_name'] ?? '-').toString(),
      ),
      storeId: json['store_id'] == null ? null : _toInt(json['store_id']),
      currency: (json['currency'] ?? 'USD').toString(),
      exchangeRate: _toDouble(json['exchange_rate']),
      usdVndRate: json['usd_vnd_rate'] == null
          ? null
          : _toDouble(json['usd_vnd_rate']),
      invoiceNumber: json['invoice_number']?.toString(),
      purchaseDate: DateTime.tryParse(
        (json['purchase_date'] ?? '').toString(),
      ),
      stage: ImportStage.fromApi(json['stage']?.toString()),
      notes: json['notes']?.toString(),
      totalEstimate: _toDouble(json['total_estimate']),
      totalReal: _toDouble(json['total_real']),
      items: items,
      costs: costs,
      payments: payments,
      notuls: notuls,
      documents: documents,
      documentCount: _toInt(json['documents_count']),
    );
  }

  /// Tipe dokumen unik yang sudah ter-upload — untuk checklist cepat.
  Set<ImportDocumentType> get uploadedTypes =>
      documents.map((d) => d.type).toSet();

  double get paymentsTotal => payments.fold(0, (sum, p) => sum + p.amount);

  /// Biaya manual yang tampil di bagian "Biaya Lain" — baris turunan
  /// pembayaran/notul tidak boleh diedit.
  List<ImportCost> get manualCosts =>
      costs.where((c) => !c.isDerived).toList(growable: false);
}

/// Response lengkap GET /import-purchases/{id}.
class ImportPurchaseDetail {
  final ImportPurchase importPurchase;
  final ImportHppResult hpp;
  final List<ImportStageCheck> checklist;
  final ImportStage? nextStage;

  ImportPurchaseDetail({
    required this.importPurchase,
    required this.hpp,
    required this.checklist,
    this.nextStage,
  });

  /// Dokumen wajib tahap BERIKUTNYA yang belum diupload — dasar merender
  /// keadaan tombol "Lanjut" (syarat belum lengkap → gaya peringatan).
  /// Gerbang sebenarnya tetap di server; ini hanya pratinjau state.
  List<ImportStageDocCheck> get missingRequiredForNextStage {
    final next = importPurchase.stage.next;
    if (next == null) return const [];
    return checklist
        .where((c) => c.stage == next)
        .expand((c) => c.documents)
        .where((d) => d.required && !d.present)
        .toList(growable: false);
  }
}

/// Satu titik harga satuan produk dari sebuah proses impor.
class ImportPriceTrendPoint {
  final int importId;
  final DateTime? date;
  final String supplierName;
  final String currency;
  final double exchangeRate;

  /// Kurs 1 USD = x VND yang melekat pada transaksi impor ini — menang
  /// atas referensi per tanggal saat konversi trend.
  final double? usdVndRate;
  final double quantity;
  final double? quantityReceived;
  final double unitPriceForeign;
  final double unitPriceIdr;
  final double unitPriceIdrEstimate;
  final double unitPriceIdrReal;
  final bool isRealized;

  ImportPriceTrendPoint({
    required this.importId,
    this.date,
    required this.supplierName,
    required this.currency,
    required this.exchangeRate,
    this.usdVndRate,
    required this.quantity,
    this.quantityReceived,
    required this.unitPriceForeign,
    required this.unitPriceIdr,
    required this.unitPriceIdrEstimate,
    required this.unitPriceIdrReal,
    required this.isRealized,
  });

  factory ImportPriceTrendPoint.fromJson(Map<String, dynamic> json) {
    return ImportPriceTrendPoint(
      importId: _toInt(json['import_id']),
      date: DateTime.tryParse((json['date'] ?? '').toString()),
      supplierName: formatSupplierName(
        (json['supplier_name'] ?? '-').toString(),
      ),
      currency: (json['currency'] ?? 'USD').toString(),
      exchangeRate: _toDouble(json['exchange_rate']),
      usdVndRate: json['usd_vnd_rate'] == null
          ? null
          : _toDouble(json['usd_vnd_rate']),
      quantity: _toDouble(json['quantity']),
      quantityReceived: _toDoubleNull(json['quantity_received']),
      unitPriceForeign: _toDouble(json['unit_price_foreign']),
      unitPriceIdr: _toDouble(json['unit_price_idr']),
      unitPriceIdrEstimate: _toDouble(json['unit_price_idr_estimate']),
      unitPriceIdrReal: _toDouble(json['unit_price_idr_real']),
      isRealized: json['is_realized'] == true,
    );
  }
}

/// Deret harga satuan satu produk lintas seluruh proses impor.
class ImportProductPriceTrend {
  final int productId;
  final String productName;
  final String unitName;
  final String currency;
  final List<ImportPriceTrendPoint> points;

  ImportProductPriceTrend({
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.currency,
    required this.points,
  });

  factory ImportProductPriceTrend.fromJson(Map<String, dynamic> json) {
    return ImportProductPriceTrend(
      productId: _toInt(json['product_id']),
      productName: (json['product_name'] ?? '').toString(),
      unitName: (json['unit_name'] ?? '').toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      points: (json['points'] as List<dynamic>? ?? [])
          .map((e) => ImportPriceTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  ImportPriceTrendPoint? get latest => points.isEmpty ? null : points.last;

  ImportPriceTrendPoint? get previous =>
      points.length < 2 ? null : points[points.length - 2];
}
