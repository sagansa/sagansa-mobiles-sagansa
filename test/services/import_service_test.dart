import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/services/import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// advance/finalize 422 dengan data.blockers → ImportBlockedException
/// berisi blocker ter-parse + flag canBypassDocuments.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  http.Client blockedClient(List<Map<String, dynamic>> blockers) {
    return MockClient(
      (request) async => http.Response(
        jsonEncode({
          'success': false,
          'message': 'Syarat tahap belum terpenuhi.',
          'data': {'blockers': blockers},
        }),
        422,
      ),
    );
  }

  test('advance: semua blocker dokumen → canBypassDocuments true', () async {
    final mock = blockedClient([
      {
        'kind': 'document',
        'message': 'Dokumen wajib belum diupload: Invoice',
      },
      {
        'kind': 'document',
        'message': 'Dokumen wajib belum diupload: Bukti Pembayaran',
      },
    ]);

    await http.runWithClient(() async {
      await expectLater(
        ImportService().advance(7),
        throwsA(
          isA<ImportBlockedException>()
              .having((e) => e.blockers.length, 'blockers', 2)
              .having((e) => e.canBypassDocuments, 'canBypass', isTrue),
        ),
      );
    }, () => mock);
  });

  test('advance: ada blocker data → canBypassDocuments false', () async {
    final mock = blockedClient([
      {
        'kind': 'document',
        'message': 'Dokumen wajib belum diupload: Invoice',
      },
      {
        'kind': 'data',
        'message': 'Kurs (exchange_rate) harus lebih dari 0.',
      },
    ]);

    await http.runWithClient(() async {
      await expectLater(
        ImportService().advance(7),
        throwsA(
          isA<ImportBlockedException>()
              .having((e) => e.canBypassDocuments, 'canBypass', isFalse),
        ),
      );
    }, () => mock);
  });

  test('advance bypass mengirim flag bypass_documents', () async {
    final requests = <http.Request>[];
    final mock = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({'success': true, 'message': 'Tahap menjadi: Pengiriman'}),
        200,
      );
    });

    await http.runWithClient(() async {
      await ImportService().advance(7, bypassDocuments: true);
    }, () => mock);

    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single.body)['bypass_documents'], isTrue);
  });
}
