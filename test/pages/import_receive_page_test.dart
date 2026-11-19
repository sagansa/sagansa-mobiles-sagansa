import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/pages/import_receive_page.dart';
import 'package:sagansa/services/import_service.dart';
import 'package:sagansa/widgets/forms/amount_field.dart';
import 'package:sagansa/widgets/forms/form_add_button.dart';
import 'package:sagansa/widgets/modern_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Realisasi bertahap: semua bagian (pembayaran, jumlah diterima, biaya,
/// notul) boleh diisi pada tahap non-terminal; bukti pembayaran opsional.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  Map<String, dynamic> detailData(String stage) => {
        'id': 7,
        'supplier_id': 3,
        'supplier': {'name': 'Olam Vietnam Ltd'},
        'currency': 'USD',
        'exchange_rate': 17545,
        'stage': stage,
        'notes': null,
        'total_estimate': 324164616,
        'total_real': 0,
        'items': [
          {
            'id': 11,
            'product_id': 21,
            'quantity': 19500,
            'quantity_received': null,
            'unit_price_foreign': 0.78,
            'product': {
              'name': 'Mete Kernel BB2 (Carton 50 lb)',
              'unit': {'unit': 'kg'},
            },
          },
        ],
        'costs': [
          {
            'id': 31,
            'stage': 'purchase',
            'name': 'Discounts',
            'category': 'goods',
            'tax_rate': null,
            'is_foreign_currency': false,
            'amount_foreign': null,
            'amount_estimate': 2500000,
            'amount_real': null,
          },
          {
            'id': 32,
            'stage': 'payment',
            'name': 'Transfer Bank',
            'category': 'bank',
            'tax_rate': null,
            'is_foreign_currency': true,
            'amount_foreign': 25,
            'amount_estimate': 438625,
            'amount_real': null,
          },
          {
            'id': 33,
            'stage': 'customs',
            'name': 'PPN Impor',
            'category': 'tax',
            'tax_rate': 11,
            'is_foreign_currency': false,
            'amount_foreign': null,
            'amount_estimate': 29354539,
            'amount_real': null,
          },
        ],
        'payments': [],
        'notuls': [],
        'documents': [],
        'documents_count': 0,
      };

  Map<String, dynamic> detailJson(String stage) => {
        'success': true,
        'data': detailData(stage),
        'hpp': {
          'goods_total': 266859450,
          'total_estimate': 324164616,
          'total_real': 0,
          'variance': 0,
          'variance_percent': null,
          'hpp_pajak': 0,
          'tax_total_estimate': 0,
          'bank_total_estimate': 0,
          'items': [
            {
              'id': 11,
              'goods_value': 266859450,
              'allocated_estimate': 0,
              'hpp_estimate_unit': 16624,
              'hpp_real_unit': 0,
            },
          ],
        },
        'checklist': const {},
        'next_stage': null,
      };

  Future<void> pumpFrames(WidgetTester tester, {int frames = 30}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
      'tahap payment: semua seksi realisasi tampil; simpan parsial hanya '
      'baris terisi + biaya baru tanpa id', (tester) async {
    Map<String, dynamic>? receiveBody;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/receive') && request.method == 'POST') {
        receiveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
          200,
        );
      }
      return http.Response(
        jsonEncode(detailJson('payment')),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      final detail = await ImportService().getDetail(7);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ImportReceivePage(detail: detail)),
      );
      await pumpFrames(tester);

      // Bypass tahap: seksi realisasi tersedia sejak pembayaran.
      expect(find.text('Produk Diterima'), findsOneWidget);
      // Belum ada isian real → ringkasan menampilkan estimasi (fallback).
      expect(find.text('Total Estimasi'), findsOneWidget);
      expect(find.text('Pembayaran'), findsOneWidget);

      final transferField = find.byWidgetPredicate(
        (w) => w is AmountField && w.semanticLabel == 'Realisasi Transfer Bank',
      );
      await tester.scrollUntilVisible(
        transferField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(transferField, '438.625');

      // Tambah biaya baru di seksi Biaya Lain.
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Biaya Lain'),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      // Header bisa tepat di bawah app bar; geser turun agar bisa diketuk.
      await tester.drag(scrollable, const Offset(0, 120));
      await pumpFrames(tester);
      await tester.tap(find.text('Biaya').last);
      await pumpFrames(tester);
      await tester.enterText(
          find.byType(ModernTextField).last, 'Denda Penyimpanan');
      final newCostField = find.byWidgetPredicate(
        (w) =>
            w is AmountField &&
            w.semanticLabel == 'Nominal realisasi biaya baru',
      );
      await tester.scrollUntilVisible(
        newCostField,
        200,
        scrollable: scrollable,
      );
      await tester.enterText(newCostField, '1.500.000');

      // Notul juga tersedia sejak tahap pembayaran (di bawah Biaya Lain).
      final addNotul = find.widgetWithText(FormAddButton, 'Notul');
      await tester.scrollUntilVisible(
        addNotul,
        200,
        scrollable: scrollable,
      );
      expect(addNotul, findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Biaya Lain'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await expectLater(
        find.byType(ImportReceivePage),
        matchesGoldenFile('goldens/import_receive_payment.png'),
      );

      await tester.tap(find.text('Simpan Realisasi'));
      await pumpFrames(tester);

      expect(receiveBody, isNotNull);
      expect(receiveBody!['items'] as List, isEmpty);
      final costs = receiveBody!['costs'] as List;
      expect(costs.length, 2);
      expect(costs[0], {'id': 32, 'amount_real': 438625});
      expect(costs[1], containsPair('name', 'Denda Penyimpanan'));
      expect(costs[1], containsPair('stage', 'payment'));
      expect(costs[1], containsPair('category', 'other'));
      expect(costs[1], containsPair('amount_real', 1500000));
      expect(costs[1], isNot(containsPair('id', anything)));
    }, () => mock);
  });

  testWidgets(
      'input nominal biaya: pemisah ribuan otomatis saat mengetik',
      (tester) async {
    Map<String, dynamic>? receiveBody;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/receive') && request.method == 'POST') {
        receiveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
          200,
        );
      }
      return http.Response(
        jsonEncode(detailJson('payment')),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      final detail = await ImportService().getDetail(7);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ImportReceivePage(detail: detail)),
      );
      await pumpFrames(tester);

      final transferField = find.byWidgetPredicate(
        (w) => w is AmountField && w.semanticLabel == 'Realisasi Transfer Bank',
      );
      await tester.scrollUntilVisible(
        transferField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Ketik tanpa pemisah — formatter wajib merapikan live ("230000"
      // → "230.000"), bukan menunggu submit.
      await tester.enterText(transferField, '230000');
      final field = tester.widget<AmountField>(transferField);
      expect(field.controller.text, '230.000');

      await tester.tap(find.text('Simpan Realisasi'));
      await pumpFrames(tester);
      // Tersimpan sebagai angka utuh, bukan teks berpemisah.
      final costs = receiveBody!['costs'] as List;
      expect(costs, [
        {'id': 32, 'amount_real': 230000}
      ]);
    }, () => mock);
  });

  testWidgets(
      'isi cepat: biaya kosong diisi estimasi, isian manual tidak ditimpa',
      (tester) async {
    Map<String, dynamic>? receiveBody;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/receive') && request.method == 'POST') {
        receiveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
          200,
        );
      }
      return http.Response(
        jsonEncode(detailJson('payment')),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      final detail = await ImportService().getDetail(7);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ImportReceivePage(detail: detail)),
      );
      await pumpFrames(tester);

      final transferField = find.byWidgetPredicate(
        (w) => w is AmountField && w.semanticLabel == 'Realisasi Transfer Bank',
      );
      await tester.scrollUntilVisible(
        transferField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(transferField, '400.000');
      await tester.scrollUntilVisible(
        find.text('Isi estimasi'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // Ringkasan menyusut sejak hanya satu tile — chip bisa berakhir
      // tepat di bawah app bar kaca; geser turun agar bisa diketuk.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, 120),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('Isi estimasi'));
      await pumpFrames(tester);

      await tester.tap(find.text('Simpan Realisasi'));
      await pumpFrames(tester);

      final costs = receiveBody!['costs'] as List;
      expect(costs, [
        {'id': 31, 'amount_real': 2500000},
        {'id': 32, 'amount_real': 400000},
        {'id': 33, 'amount_real': 29354539},
      ]);
    }, () => mock);
  });

  testWidgets(
      'isi cepat: PPH berestimasi nol dihitung dari tarif × nilai barang',
      (tester) async {
    Map<String, dynamic>? receiveBody;
    final body = detailJson('payment');
    final data = body['data'] as Map<String, dynamic>;
    (data['costs'] as List).add({
      'id': 34,
      'stage': 'customs',
      'name': 'PPH 1.6',
      'category': 'tax',
      'tax_rate': 2.5,
      'is_foreign_currency': false,
      'amount_foreign': null,
      'amount_estimate': 0,
      'amount_real': null,
    });

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/receive') && request.method == 'POST') {
        receiveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
          200,
        );
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      final detail = await ImportService().getDetail(7);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ImportReceivePage(detail: detail)),
      );
      await pumpFrames(tester);

      await tester.tap(find.text('Isi estimasi'));
      await pumpFrames(tester);
      await tester.tap(find.text('Simpan Realisasi'));
      await pumpFrames(tester);

      final costs = receiveBody!['costs'] as List;
      final pph = costs.firstWhere((c) => (c as Map)['id'] == 34) as Map;
      // 2,5% × 266.859.450 = 6.671.486,25 → dibulatkan saat diisi.
      expect(pph['amount_real'], 6671486);
    }, () => mock);
  });

  testWidgets('layar sempit 320dp: input nominal turun ke bawah tanpa overflow',
      (tester) async {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode(detailJson('payment')),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      final detail = await ImportService().getDetail(7);
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ImportReceivePage(detail: detail)),
      );
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Biaya Lain'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AmountField), findsWidgets);
    }, () => mock);
  });

  testWidgets('tranche pembayaran: tranche baru ikut terkirim', (tester) async {
    Map<String, dynamic>? receiveBody;
    final body = detailJson('payment');
    final data = body['data'] as Map<String, dynamic>;
    data['payments'] = [
      {
        'id': 51,
        'amount': 280000000,
        'paid_at': '2026-10-18',
        'note': null,
        'proof_path': 'documents/ImportPurchase/bayar-1.webp',
        'proof_original_name': 'bayar-1.webp',
        'proof_mime_type': 'image/webp',
        'proof_size_bytes': 1024,
      },
    ];
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/receive') && request.method == 'POST') {
        receiveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
          200,
        );
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      final detail = await ImportService().getDetail(7);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ImportReceivePage(detail: detail)),
      );
      await pumpFrames(tester);

      expect(find.text('Tranche 1'), findsOneWidget);
      await tester.tap(find.widgetWithText(FormAddButton, 'Tranche'));
      await pumpFrames(tester);

      // Field 0 = tranche lama, field 1 = tranche baru, lalu biaya manual.
      await tester.enterText(find.byType(AmountField).at(1), '20.000.000');
      await tester.tap(find.text('Simpan Realisasi'));
      await pumpFrames(tester);

      final payments = receiveBody!['payments'] as List;
      expect(payments.length, 2);
      expect((payments[0] as Map)['id'], 51);
      expect((payments[0] as Map)['proof_path'],
          'documents/ImportPurchase/bayar-1.webp');
      expect((payments[1] as Map)['amount'], 20000000);
      expect((payments[1] as Map)['id'], isNull);
    }, () => mock);
  });

  testWidgets('tranche tanpa bukti pembayaran tetap bisa disimpan',
      (tester) async {
    Map<String, dynamic>? receiveBody;
    final body = detailJson('draft');
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/receive') && request.method == 'POST') {
        receiveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
          200,
        );
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      final detail = await ImportService().getDetail(7);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ImportReceivePage(detail: detail)),
      );
      await pumpFrames(tester);

      await tester.tap(find.widgetWithText(FormAddButton, 'Tranche'));
      await pumpFrames(tester);
      final amount = find.byWidgetPredicate(
        (w) =>
            w is AmountField &&
            w.semanticLabel == 'Nominal pembayaran tranche 1',
      );
      await tester.enterText(amount, '25.000.000');
      await tester.tap(find.text('Simpan Realisasi'));
      await pumpFrames(tester);

      final payments = receiveBody!['payments'] as List;
      expect(payments.length, 1);
      expect((payments.single as Map)['amount'], 25000000);
      expect((payments.single as Map).containsKey('proof_path'), isFalse);
    }, () => mock);
  });

  testWidgets('notul: PPh/PPN tersimpan sebagai notul baru', (tester) async {
    Map<String, dynamic>? receiveBody;
    final body = detailJson('customs');
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/receive') && request.method == 'POST') {
        receiveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
          200,
        );
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      final detail = await ImportService().getDetail(7);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ImportReceivePage(detail: detail)),
      );
      await pumpFrames(tester);

      final addNotul = find.widgetWithText(FormAddButton, 'Notul');
      await tester.scrollUntilVisible(
        addNotul,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(addNotul);
      await tester.pumpAndSettle();
      await tester.tap(addNotul);
      await pumpFrames(tester);

      // Cari field berdasarkan label semantik agar tidak bergantung pada
      // urutan field yang ter-build di viewport.
      final pphField = find.byWidgetPredicate(
        (w) => w is AmountField && w.semanticLabel == 'PPh Impor',
      );
      final ppnField = find.byWidgetPredicate(
        (w) => w is AmountField && w.semanticLabel == 'PPN Impor',
      );
      await tester.scrollUntilVisible(
        pphField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(pphField, '12.000.000');
      await tester.enterText(ppnField, '30.000.000');
      await tester.tap(find.text('Simpan Realisasi'));
      await pumpFrames(tester);

      final notuls = receiveBody!['notuls'] as List;
      expect(notuls.length, 1);
      final notul = notuls.first as Map;
      expect(notul['id'], isNull);
      expect(notul['pph_amount'], 12000000);
      expect(notul['ppn_amount'], 30000000);
      expect(notul['notul_date'], isNotEmpty);
    }, () => mock);
  });

  testWidgets('tahap kedatangan: seksi diterima tampil & ikut tersimpan',
      (tester) async {
    Map<String, dynamic>? receiveBody;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/receive') && request.method == 'POST') {
        receiveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
          200,
        );
      }
      return http.Response(
        jsonEncode(detailJson('arrival')),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      final detail = await ImportService().getDetail(7);
      await tester.pumpWidget(
        MaterialApp(home: ImportReceivePage(detail: detail)),
      );
      await pumpFrames(tester);

      expect(find.text('Produk Diterima'), findsOneWidget);

      // Field pertama = diterima produk; isi parsial tanpa biaya.
      await tester.enterText(find.byType(AmountField).at(0), '19.110');
      await tester.tap(find.text('Simpan Realisasi'));
      await pumpFrames(tester);

      expect(receiveBody!['items'], [
        {'id': 11, 'quantity_received': 19110}
      ]);
      expect(receiveBody!['costs'] as List, isEmpty);
    }, () => mock);
  });
}
