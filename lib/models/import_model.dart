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
      productName: (json['product']?['name'] ?? json['product_name'] ?? '')
          .toString(),
      unitName: (json['product']?['unit']?['unit'] ?? '').toString(),
    );
  }
}

/// Biaya proses impor selain nilai barang (import_costs) — estimate vs real.
class ImportCost {
  final int id;
  final String stage; // purchase|payment|shipment|customs|arrival
  final String name;
  final String category; // goods|bank|tax|logistics|other
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
      taxRate: _toDoubleNull(json['tax_rate']),
      isForeignCurrency: json['is_foreign_currency'] == true,
      amountForeign: _toDoubleNull(json['amount_foreign']),
      amountEstimate: _toDouble(json['amount_estimate']),
      amountReal: _toDoubleNull(json['amount_real']),
    );
  }

  String get categoryLabel {
    return switch (category) {
      'bank' => 'Bank',
      'tax' => 'Pajak',
      'logistics' => 'Logistik',
      'goods' => 'Barang',
      _ => 'Lainnya',
    };
  }
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
              label: (e.value as Map<String, dynamic>)['label']?.toString() ?? e.key,
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
  final ImportStage stage;
  final String? notes;
  final double totalEstimate;
  final double totalReal;
  final List<ImportItem> items;
  final List<ImportCost> costs;
  final List<ImportDocumentModel> documents;
  final int documentCount;

  ImportPurchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    this.storeId,
    required this.currency,
    required this.exchangeRate,
    required this.stage,
    this.notes,
    required this.totalEstimate,
    required this.totalReal,
    required this.items,
    required this.costs,
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
    final documents = (json['documents'] as List<dynamic>? ?? [])
        .map((e) => ImportDocumentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ImportPurchase(
      id: _toInt(json['id']),
      supplierId: _toInt(json['supplier_id']),
      supplierName: (json['supplier']?['name'] ?? json['supplier_name'] ?? '-')
          .toString(),
      storeId: json['store_id'] == null ? null : _toInt(json['store_id']),
      currency: (json['currency'] ?? 'USD').toString(),
      exchangeRate: _toDouble(json['exchange_rate']),
      stage: ImportStage.fromApi(json['stage']?.toString()),
      notes: json['notes']?.toString(),
      totalEstimate: _toDouble(json['total_estimate']),
      totalReal: _toDouble(json['total_real']),
      items: items,
      costs: costs,
      documents: documents,
      documentCount: _toInt(json['documents_count']),
    );
  }

  /// Tipe dokumen unik yang sudah ter-upload — untuk checklist cepat.
  Set<ImportDocumentType> get uploadedTypes =>
      documents.map((d) => d.type).toSet();
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
}
