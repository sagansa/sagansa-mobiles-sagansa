import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// postRaw harus melempar ApiException berstatus & body ter-parse agar
/// pemanggil (mis. advance impor) bisa membaca data.blockers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  test('postRaw 422 → ApiException berstatusCode & body', () async {
    final body = {
      'success': false,
      'message': 'Syarat tahap belum terpenuhi.',
      'data': {
        'blockers': [
          {
            'kind': 'document',
            'message': 'Dokumen wajib belum diupload: Invoice',
          },
        ],
      },
    };
    final mock = MockClient(
      (request) async => http.Response(jsonEncode(body), 422),
    );

    await http.runWithClient(() async {
      await expectLater(
        ApiClient().postRaw('import-purchases/7/advance'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.message,
                'message',
                'Syarat tahap belum terpenuhi.',
              )
              .having((e) => e.body?['data'], 'body.data', isNotNull),
        ),
      );
    }, () => mock);
  });
}
