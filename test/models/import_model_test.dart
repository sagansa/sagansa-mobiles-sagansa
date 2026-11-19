import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/enums/import_document_type.dart';
import 'package:sagansa/models/enums/import_stage.dart';
import 'package:sagansa/models/import_model.dart';

void main() {
  group('ImportStage', () {
    test('fromApi memetakan nilai backend', () {
      expect(ImportStage.fromApi('draft'), ImportStage.draft);
      expect(ImportStage.fromApi('finalized'), ImportStage.finalized);
      expect(ImportStage.fromApi('cancelled'), ImportStage.cancelled);
      expect(ImportStage.fromApi(null), ImportStage.unknown);
      expect(ImportStage.fromApi('nonsense'), ImportStage.unknown);
    });

    test('alur & next', () {
      expect(ImportStage.draft.flowIndex, 0);
      expect(ImportStage.draft.next, ImportStage.payment);
      expect(ImportStage.receiving.next, ImportStage.finalized);
      expect(ImportStage.finalized.next, isNull);
      expect(ImportStage.cancelled.flowIndex, -1);
      expect(ImportStage.arrival.canReceive, isTrue);
      expect(ImportStage.receiving.canReceive, isTrue);
      expect(ImportStage.draft.canReceive, isFalse);
    });
  });

  group('ImportDocumentType', () {
    test('round-trip ke API snake_case', () {
      for (final t in ImportDocumentType.values) {
        expect(ImportDocumentType.fromApi(t.toApi()), t);
      }
    });

    test('nilai tak dikenal → other', () {
      expect(
          ImportDocumentType.fromApi('surat_jalan'), ImportDocumentType.other);
    });
  });

  group('ImportPurchase.fromJson', () {
    final json = {
      'id': '7',
      'supplier_id': 3,
      'supplier': {'name': 'Mete India Co'},
      'currency': 'USD',
      'exchange_rate': '17545',
      'stage': 'payment',
      'total_estimate': '324164616',
      'total_real': '357525590',
      'items': [
        {
          'id': 1,
          'product_id': 9,
          'quantity': '19500',
          'unit_price_foreign': '0.7800',
          'quantity_received': null,
          'product': {
            'name': 'Mete BB2',
            'unit': {'unit': 'kg'},
          },
        },
      ],
      'costs': [
        {
          'id': 2,
          'stage': 'payment',
          'name': 'Transfer Bank',
          'category': 'bank',
          'is_foreign_currency': true,
          'amount_foreign': '25',
          'amount_estimate': '0',
        },
      ],
      'documents': [
        {
          'id': 3,
          'type': 'invoice',
          'file_path': 'documents/ImportPurchase/x.pdf',
          'file_url':
              'https://img.sagansa.id/storage/documents/ImportPurchase/x.pdf',
          'mime_type': 'application/pdf',
        },
      ],
    };

    test('menoleransi angka string dari MySQL', () {
      final parsed = ImportPurchase.fromJson(json);

      expect(parsed.id, 7);
      expect(parsed.exchangeRate, 17545);
      expect(parsed.stage, ImportStage.payment);
      expect(parsed.supplierName, 'Mete India Co');

      final item = parsed.items.single;
      expect(item.quantity, 19500);
      expect(item.unitPriceForeign, 0.78);
      expect(item.productName, 'Mete BB2');
      expect(item.unitName, 'kg');

      final cost = parsed.costs.single;
      expect(cost.isForeignCurrency, isTrue);
      expect(cost.amountForeign, 25);

      final doc = parsed.documents.single;
      expect(doc.type, ImportDocumentType.invoice);
      expect(doc.isPdf, isTrue);
      expect(parsed.uploadedTypes, {ImportDocumentType.invoice});
    });
  });

  group('ImportItem harga satuan', () {
    Map<String, dynamic> json({
      bool realized = false,
      double? unitPriceIdr,
      double? estimate,
      double? real,
    }) =>
        {
          'id': 1,
          'product_id': 9,
          'quantity': 19500,
          'unit_price_foreign': 0.78,
          'product': {
            'name': 'Mete BB2',
            'unit': {'unit': 'kg'},
          },
          if (unitPriceIdr != null) 'unit_price_idr': unitPriceIdr,
          if (estimate != null) 'hpp_estimate_unit': estimate,
          if (real != null) 'hpp_real_unit': real,
          'price_is_realized': realized,
        };

    test('memakai realisasi bila sudah ada', () {
      final item = ImportItem.fromJson(json(
        realized: true,
        unitPriceIdr: 18709,
        estimate: 16624,
        real: 18709,
      ));

      expect(item.priceIsRealized, isTrue);
      expect(item.displayUnitPriceIdr, 18709);
    });

    test('fallback estimasi bila realisasi belum ada', () {
      final item = ImportItem.fromJson(json(
        unitPriceIdr: 16624,
        estimate: 16624,
        real: 0,
      ));

      expect(item.priceIsRealized, isFalse);
      expect(item.displayUnitPriceIdr, 16624);
    });

    test('fallback snapshot HPP saat field hitung list tidak ada', () {
      final item = ImportItem.fromJson({
        'id': 1,
        'product_id': 9,
        'quantity': 19500,
        'unit_price_foreign': 0.78,
        'hpp_estimate': 15000,
        'product': {
          'name': 'Mete BB2',
          'unit': {'unit': 'kg'},
        },
      });

      expect(item.displayUnitPriceIdr, 15000);
    });
  });

  group('ImportProductPriceTrend.fromJson', () {
    test('memetakan titik USD/IDR dan realisasi', () {
      final trend = ImportProductPriceTrend.fromJson({
        'product_id': 9,
        'product_name': 'Mete BB2',
        'unit_name': 'kg',
        'currency': 'USD',
        'points': [
          {
            'import_id': 1,
            'date': '2026-09-01',
            'supplier_name': 'Supplier A',
            'currency': 'USD',
            'exchange_rate': 17000,
            'quantity': 19500,
            'unit_price_foreign': '0.75',
            'unit_price_idr': 15000,
            'unit_price_idr_estimate': 15000,
            'unit_price_idr_real': 16000,
            'is_realized': false,
          },
          {
            'import_id': 2,
            'date': '2026-10-01',
            'supplier_name': 'Supplier B',
            'currency': 'USD',
            'exchange_rate': 17545,
            'quantity': 19500,
            'quantity_received': 11700,
            'unit_price_foreign': '0.82',
            'unit_price_idr': 17000,
            'unit_price_idr_estimate': 16500,
            'unit_price_idr_real': 17000,
            'is_realized': true,
          },
        ],
      });

      expect(trend.points, hasLength(2));
      expect(trend.latest?.importId, 2);
      expect(trend.previous?.importId, 1);
      expect(trend.latest?.unitPriceForeign, 0.82);
      expect(trend.latest?.unitPriceIdr, 17000);
      expect(trend.latest?.isRealized, isTrue);
    });
  });

  group('ImportStageCheck.fromEntry', () {
    test('menoleransi documents berupa list (array PHP kosong → JSON [])', () {
      final check = ImportStageCheck.fromEntry('draft', {
        'label': 'Draft',
        'state': 'current',
        'documents': <dynamic>[],
      });

      expect(check.stage, ImportStage.draft);
      expect(check.state, 'current');
      expect(check.documents, isEmpty);
    });

    test('memetakan dokumen per tahap', () {
      final check = ImportStageCheck.fromEntry('payment', {
        'label': 'Pembayaran',
        'state': 'upcoming',
        'documents': {
          'invoice': {
            'label': 'Invoice',
            'required': true,
            'present': false,
          },
        },
      });

      final doc = check.documents.single;
      expect(doc.type, 'invoice');
      expect(doc.label, 'Invoice');
      expect(doc.required, isTrue);
      expect(doc.present, isFalse);
    });
  });

  group('ImportBlocker', () {
    test('fromJson & isDocument', () {
      final doc = ImportBlocker.fromJson({
        'kind': 'document',
        'message': 'Dokumen wajib belum diupload: Invoice',
      });
      expect(doc.kind, 'document');
      expect(doc.isDocument, isTrue);
      expect(doc.message, contains('Invoice'));

      final data = ImportBlocker.fromJson({
        'kind': 'data',
        'message': 'Kurs (exchange_rate) harus lebih dari 0.',
      });
      expect(data.isDocument, isFalse);
    });
  });

  group('ImportHppResult.fromJson', () {
    test('memetakan ringkasan & baris item', () {
      final result = ImportHppResult.fromJson({
        'goods_total': '266859450',
        'total_estimate': '324164616',
        'total_real': '357525590',
        'variance': '33360974',
        'variance_percent': '10.29',
        'hpp_pajak': '317019505',
        'tax_total_estimate': '36026026',
        'bank_total_estimate': '473625',
        'items': [
          {
            'id': 1,
            'goods_value': '266859450',
            'quantity_received': '11700',
            'allocated_estimate': '324164616',
            'allocated_real': '357525590',
            'hpp_estimate_unit': '16623.83',
            'hpp_real_unit': '30557.5',
          },
        ],
      });

      expect(result.totalEstimate, 324164616);
      expect(result.variancePercent, closeTo(10.29, 0.001));
      expect(result.hppPajak, 317019505);
      expect(result.items.single.hppRealUnit, closeTo(30557.5, 0.001));
    });
  });
}
