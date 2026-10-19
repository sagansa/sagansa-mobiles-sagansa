import 'package:flutter/material.dart';

/// Tipe dokumen kelengkapan proses impor (import_documents.type).
enum ImportDocumentType {
  po,
  invoice,
  paymentProof,
  packingList,
  bl,
  coo,
  insurance,
  pib,
  taxProof,
  notul,
  deliveryOrder,
  unloadingReceipt,
  portReceipt,
  other;

  /// Decode dari string backend (snake_case); tak dikenal → [other].
  static ImportDocumentType fromApi(String? value) {
    return switch (value) {
      'po' => ImportDocumentType.po,
      'invoice' => ImportDocumentType.invoice,
      'payment_proof' => ImportDocumentType.paymentProof,
      'packing_list' => ImportDocumentType.packingList,
      'bl' => ImportDocumentType.bl,
      'coo' => ImportDocumentType.coo,
      'insurance' => ImportDocumentType.insurance,
      'pib' => ImportDocumentType.pib,
      'tax_proof' => ImportDocumentType.taxProof,
      'notul' => ImportDocumentType.notul,
      'delivery_order' => ImportDocumentType.deliveryOrder,
      'unloading_receipt' => ImportDocumentType.unloadingReceipt,
      'port_receipt' => ImportDocumentType.portReceipt,
      _ => ImportDocumentType.other,
    };
  }

  /// Encode ke snake_case untuk request body.
  String toApi() {
    const map = {
      ImportDocumentType.po: 'po',
      ImportDocumentType.invoice: 'invoice',
      ImportDocumentType.paymentProof: 'payment_proof',
      ImportDocumentType.packingList: 'packing_list',
      ImportDocumentType.bl: 'bl',
      ImportDocumentType.coo: 'coo',
      ImportDocumentType.insurance: 'insurance',
      ImportDocumentType.pib: 'pib',
      ImportDocumentType.taxProof: 'tax_proof',
      ImportDocumentType.notul: 'notul',
      ImportDocumentType.deliveryOrder: 'delivery_order',
      ImportDocumentType.unloadingReceipt: 'unloading_receipt',
      ImportDocumentType.portReceipt: 'port_receipt',
      ImportDocumentType.other: 'other',
    };
    return map[this]!;
  }

  String get displayLabel {
    return switch (this) {
      ImportDocumentType.po => 'Purchase Order',
      ImportDocumentType.invoice => 'Invoice',
      ImportDocumentType.paymentProof => 'Bukti Pembayaran',
      ImportDocumentType.packingList => 'Packing List',
      ImportDocumentType.bl => 'Bill of Lading / AWB',
      ImportDocumentType.coo => 'Certificate of Origin',
      ImportDocumentType.insurance => 'Asuransi Kargo',
      ImportDocumentType.pib => 'PIB / SPPB',
      ImportDocumentType.taxProof => 'Bukti Setor Pajak',
      ImportDocumentType.notul => 'NOTUL',
      ImportDocumentType.deliveryOrder => 'Delivery Order',
      ImportDocumentType.unloadingReceipt => 'Kuitansi Bongkar',
      ImportDocumentType.portReceipt => 'Kuitansi Pelabuhan',
      ImportDocumentType.other => 'Lainnya',
    };
  }

  IconData get icon {
    return switch (this) {
      ImportDocumentType.invoice || ImportDocumentType.po => Icons.receipt_long_outlined,
      ImportDocumentType.paymentProof || ImportDocumentType.taxProof => Icons.payments_outlined,
      ImportDocumentType.packingList => Icons.inventory_2_outlined,
      ImportDocumentType.bl => Icons.directions_boat_outlined,
      ImportDocumentType.coo => Icons.verified_outlined,
      ImportDocumentType.insurance => Icons.shield_outlined,
      ImportDocumentType.pib || ImportDocumentType.notul => Icons.gavel_outlined,
      ImportDocumentType.deliveryOrder => Icons.local_shipping_outlined,
      ImportDocumentType.unloadingReceipt || ImportDocumentType.portReceipt => Icons.anchor_outlined,
      ImportDocumentType.other => Icons.description_outlined,
    };
  }
}
