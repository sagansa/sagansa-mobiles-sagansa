import '../../widgets/status_badge.dart';

/// Tahapan proses impor barang (import_purchases.stage).
///
/// Alur fixed: draft → payment → shipment → customs → arrival → receiving →
/// finalized. `cancelled` keadaan terminal khusus.
enum ImportStage {
  draft,
  payment,
  shipment,
  customs,
  arrival,
  receiving,
  finalized,
  cancelled,
  unknown;

  static const List<ImportStage> flow = [
    draft,
    payment,
    shipment,
    customs,
    arrival,
    receiving,
    finalized,
  ];

  /// Decode dari string backend; nilai tak dikenal → [unknown].
  static ImportStage fromApi(String? value) {
    return ImportStage.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ImportStage.unknown,
    );
  }

  /// Urutan dalam alur (index). `cancelled`/`unknown` → -1.
  int get flowIndex {
    final i = flow.indexOf(this);
    return i;
  }

  /// Tahap berikutnya dalam alur; null bila terminal/tak dikenal.
  ImportStage? get next {
    final i = flowIndex;
    if (i < 0 || i >= flow.length - 1) return null;
    return flow[i + 1];
  }

  String get displayLabel {
    return switch (this) {
      ImportStage.draft => 'Draft',
      ImportStage.payment => 'Pembayaran',
      ImportStage.shipment => 'Pengiriman',
      ImportStage.customs => 'Kepabeanan',
      ImportStage.arrival => 'Kedatangan',
      ImportStage.receiving => 'Penerimaan',
      ImportStage.finalized => 'Final',
      ImportStage.cancelled => 'Dibatalkan',
      ImportStage.unknown => 'Tidak diketahui',
    };
  }

  StatusType get badgeType {
    return switch (this) {
      ImportStage.draft => StatusType.neutral,
      ImportStage.payment => StatusType.info,
      ImportStage.shipment => StatusType.info,
      ImportStage.customs => StatusType.warning,
      ImportStage.arrival => StatusType.info,
      ImportStage.receiving => StatusType.warning,
      ImportStage.finalized => StatusType.success,
      ImportStage.cancelled => StatusType.error,
      ImportStage.unknown => StatusType.neutral,
    };
  }

  bool get isTerminal => this == finalized || this == cancelled;
  bool get isCancelled => this == cancelled;
  bool get canReceive => this == arrival || this == receiving;
}
