import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/pages/import_detail_page.dart';
import 'package:sagansa/widgets/modern_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alur: advance terblokir → dialog daftar dokumen kurang → tombol
/// "Lanjut Tanpa Dokumen" → advance terkirim ulang dengan flag bypass.
///
/// Catatan: pakai pump manual (bukan pumpAndSettle) karena tombol busy
/// memutar CircularProgressIndicator indeterminat — animasi tak pernah
/// berhenti selama `_busy` (menunggu dialog) sehingga pumpAndSettle hang.
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
            'unit_price_foreign': 0.78,
            'product': {
              'name': 'Mete Kernel BB2 (Carton 50 lb)',
              'unit': {'unit': 'kg'},
            },
          },
        ],
        'costs': [],
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

  /// Pump halaman. [mock] harus sudah aktif di zone pemanggil
  /// (http.runWithClient membungkus seluruh body test — termasuk interaksi
  /// tap; tanpa ini advance dari tap memakai HttpClient asli → 400).
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: ImportDetailPage(importId: 7),
    ));
    await pumpFrames(tester);
  }

  testWidgets('advance terblokir → dialog kurang dokumen → bypass terkirim',
      (tester) async {
    final advanceRequests = <http.Request>[];
    var advanceCalls = 0;
    final mock = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/advance') && request.method == 'POST') {
        advanceCalls++;
        advanceRequests.add(request);
        if (advanceCalls == 1) {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'Syarat tahap belum terpenuhi.',
              'data': {
                'blockers': [
                  {
                    'kind': 'document',
                    'message': 'Dokumen wajib belum diupload: Invoice',
                  },
                  {
                    'kind': 'document',
                    'message': 'Dokumen wajib belum diupload: Bukti Pembayaran',
                  },
                ],
              },
            }),
            422,
          );
        }
        return http.Response(
          jsonEncode({'success': true, 'message': 'Tahap menjadi: Pengiriman'}),
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
      await pumpPage(tester);

      await tester.tap(find.text('Lanjut: Pengiriman'));
      await pumpFrames(tester);

      // Dialog menampilkan dokumen yang kurang, bukan pesan generik.
      expect(
        find.textContaining('Dokumen wajib belum diupload: Invoice'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Dokumen wajib belum diupload: Bukti Pembayaran'),
        findsOneWidget,
      );
      expect(find.text('Lanjut Tanpa Dokumen'), findsOneWidget);

      await tester.tap(find.text('Lanjut Tanpa Dokumen'));
      await pumpFrames(tester);

      // Advance kedua membawa flag bypass.
      expect(advanceCalls, 2);
      expect(jsonDecode(advanceRequests[1].body)['bypass_documents'], isTrue);
    }, () => mock);
  });

  testWidgets('tombol Finalisasi aktif saat idle di tahap receiving (regresi)',
      (tester) async {
    final mock = MockClient(
      (request) async => http.Response(
        jsonEncode(detailJson('receiving')),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await http.runWithClient(() async {
      await pumpPage(tester);

      final button = tester.widget<ModernButton>(
        find.byWidgetPredicate(
          (w) => w is ModernButton && w.text == 'Finalisasi',
        ),
      );
      expect(button.onPressed, isNotNull);
    }, () => mock);
  });
}
